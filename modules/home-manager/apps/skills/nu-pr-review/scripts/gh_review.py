#!/usr/bin/env python3
"""Post and manage GitHub PR reviews under the user's account: one thread per finding plus an overview that links them.

Shared by the nu-pr-review and nu-pr-recheck skills. Needs `gh` logged in; stdlib only.

usage:
  gh_review.py threads --pr N [--repo R] [--full] [--since SHA] [--json]
                                                      commits, reviews, review threads (with replies), issue
                                                      comments; --full prints whole comment bodies, --since
                                                      marks the commits after SHA (or says it was force-pushed)
  gh_review.py check   FINDINGS.json                  validate a findings file against the PR head, diff and threads
  gh_review.py preview FINDINGS.json --out FILE.html
                                                      render what would be posted, GitHub-style, sending nothing
  gh_review.py post    FINDINGS.json [--dry-run DIR]  post one COMMENT review, PUT the linked overview body,
                                                      unresolve every thread that got a reply finding, and
                                                      resolve the file's `resolve` list. --dry-run runs `check`,
                                                      writes the payloads and preview.html, sends nothing, and
                                                      exits 1 when `check` finds problems
  gh_review.py link    FINDINGS.json --review ID      redo the link + PUT step for a review that is already posted
  gh_review.py resolve --pr N ID... [--unresolve] [--dry-run]   ID = thread node id (PRRT_...) or first-comment id

The findings file format is in ../references/findings.md.
"""
import argparse
import functools
import html
import json
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

SEVS = ("high", "medium", "low")
ICON = "https://github.githubassets.com/static/images/icons/copilot-code-review"
CSS = Path(__file__).resolve().parent.parent / "assets" / "github-markdown.css"


def badge(sev):
    """No badge. Severity is carried by the wording of the thread, and in the overview by a counts
    line and the word leading each finding.

    Copilot's severity icons are not used, so a review under the user's name never reads as Copilot's.
    `sev_of` below still reads them, to recognise other reviewers' threads."""
    return ""


def die(msg):
    sys.exit(f"error: {msg}")


def gh(args, payload=None):
    cmd = ["gh", "api", *args] + (["--input", "-"] if payload is not None else [])
    p = subprocess.run(cmd, input=json.dumps(payload) if payload is not None else None,
                       capture_output=True, text=True, stdin=None if payload is not None else subprocess.DEVNULL)
    if p.returncode:
        die(f"gh api {' '.join(args)} failed:\n{p.stderr}{p.stdout}")
    return json.loads(p.stdout) if p.stdout.strip() else None


def gql(query, **variables):
    r = gh(["graphql"], {"query": query, "variables": variables})
    if r.get("errors"):
        die(f"graphql: {json.dumps(r['errors'], indent=1)}")
    return r["data"]


def paged(path):
    out, page = [], 1
    sep = "&" if "?" in path else "?"
    while True:
        chunk = gh([f"{path}{sep}per_page=100&page={page}"])
        out += chunk
        if len(chunk) < 100:
            return out
        page += 1


def title_of(body):
    """The bold title after a badge, else the first line, with markup dropped."""
    text = re.sub(r"<picture>.*?</picture>", "", body or "", flags=re.S).strip()
    m = re.match(r"\*\*(.+?)\*\*", text)
    return m.group(1) if m else text.splitlines()[0][:100] if text else ""


def sev_of(body):
    m = re.search(r"copilot-code-review/(high|medium|low)-v2", body or "")
    return m.group(1) if m else "-"


def snippet(body, n=240):
    text = re.sub(r"<picture>.*?</picture>", "[badge]", body or "", flags=re.S)
    text = " ".join(text.split())
    return text if len(text) <= n else text[: n - 1] + "…"


# ---------------------------------------------------------------- threads

THREADS_Q = """
query($owner:String!, $name:String!, $pr:Int!, $after:String) {
  repository(owner:$owner, name:$name) { pullRequest(number:$pr) {
    headRefOid title
    reviewThreads(first:100, after:$after) {
      pageInfo { hasNextPage endCursor }
      nodes { id isResolved isOutdated path line originalLine subjectType resolvedBy { login }
        comments(first:50) { nodes {
          databaseId author { login } createdAt body
          pullRequestReview { databaseId } originalCommit { oid } } } } } } } }
"""


def fetch_threads(repo, pr):
    owner, name = repo.split("/")
    nodes, after = [], None
    while True:
        d = gql(THREADS_Q, owner=owner, name=name, pr=pr, after=after)["repository"]["pullRequest"]
        nodes += d["reviewThreads"]["nodes"]
        if not d["reviewThreads"]["pageInfo"]["hasNextPage"]:
            return d, nodes
        after = d["reviewThreads"]["pageInfo"]["endCursor"]


@functools.lru_cache(maxsize=None)
def pr_data(repo, pr):
    """(meta, threads, files) fetched once per run, for check and preview. Posting fetches threads fresh."""
    meta, threads = fetch_threads(repo, pr)
    files = {f["filename"]: f for f in paged(f"repos/{repo}/pulls/{pr}/files")}
    return meta, threads, files


def by_first_comment(threads):
    return {t["comments"]["nodes"][0]["databaseId"]: t for t in threads if t["comments"]["nodes"]}


def thread_for(ref, threads):
    """A thread by node id (PRRT_...) or by its first comment's id."""
    if isinstance(ref, str) and not ref.isdigit():
        return next((t for t in threads if t["id"] == ref), None)
    return by_first_comment(threads).get(int(ref)) if ref is not None else None


def cmd_threads(a):
    pr, threads = fetch_threads(a.repo, a.pr)
    reviews = paged(f"repos/{a.repo}/pulls/{a.pr}/reviews")
    issue = paged(f"repos/{a.repo}/issues/{a.pr}/comments")
    commits = paged(f"repos/{a.repo}/pulls/{a.pr}/commits")
    if a.json:
        print(json.dumps(dict(head=pr["headRefOid"], commits=commits, reviews=reviews, threads=threads,
                              issue_comments=issue), indent=1))
        return
    text = (lambda b: "\n      " + (b or "").strip().replace("\n", "\n      ")) if a.full else snippet
    print(f"head {pr['headRefOid']}  ({len(commits)} commits)")
    if not a.since:
        # Default: the head the user's latest review was posted on.
        me = viewer()
        mine = [r for r in reviews if r["user"]["login"] == me and r.get("commit_id")]
        a.since = mine[-1]["commit_id"][:9] if mine else None
        if a.since:
            print(f"{me}'s latest review was on {a.since}")
    shas = [c["sha"] for c in commits]
    since = next((i for i, s in enumerate(shas) if a.since and s.startswith(a.since)), None)
    if a.since and since is None:
        print(f"{a.since} isn't one of the PR's commits: the branch was force-pushed, so the whole diff is new")
    elif a.since:
        print(f"{len(shas) - since - 1} commits after {a.since}")
    for i, c in enumerate(commits):
        new = " NEW" if since is not None and i > since else ""
        print(f"- {c['sha'][:9]} {c['commit']['committer']['date']}{new}: {c['commit']['message'].splitlines()[0]}")
    print(f"\n## reviews ({len(reviews)})")
    for r in reviews:
        print(f"- {r['id']} {r['user']['login']} {r['state']} on {(r.get('commit_id') or '')[:9]} "
              f"{r.get('submitted_at') or ''}: {snippet(r.get('body'), 120)}")
    print(f"\n## review threads ({len(threads)}; {sum(not t['isResolved'] for t in threads)} unresolved)")
    for t in threads:
        cs = t["comments"]["nodes"]
        first = cs[0] if cs else {}
        state = f"RESOLVED by {(t.get('resolvedBy') or {}).get('login')}" if t["isResolved"] else "open"
        if t["isOutdated"]:
            state += ",outdated"
        loc = f"{t['path']}:{t['line'] or t['originalLine'] or 'file'}"
        print(f"- {t['id']} [{state}] {loc} first={first.get('databaseId')} "
              f"by {(first.get('author') or {}).get('login')} review={(first.get('pullRequestReview') or {}).get('databaseId')} "
              f"sev={sev_of(first.get('body'))}: {title_of(first.get('body'))}")
        if a.full and first:
            print(f"    {text(first['body'])}")
        for c in cs[1:]:
            print(f"    ↳ {c['databaseId']} {(c.get('author') or {}).get('login')} {c['createdAt']}: {text(c['body'])}")
    print(f"\n## issue comments ({len(issue)})")
    for c in issue:
        print(f"- {c['id']} {c['user']['login']} {c['created_at']}: {text(c['body'])}")


# ---------------------------------------------------------------- check

def load(path):
    try:
        F = json.loads(Path(path).read_text())
    except (OSError, json.JSONDecodeError) as e:
        die(f"{path}: {e}")
    for k in ("findings", "resolve", "keep"):
        F.setdefault(k, [])
    for k in ("repo", "pr", "sha") + (("summary", "footer") if F["findings"] else ()):
        if k not in F:
            die(f"{path}: missing key {k!r}")
    F.setdefault("heading", "Changes recommended")
    return F


def kind(f):
    return "reply" if f.get("reply_to") else "file" if f.get("subject") == "file" else "line"


def commentable_lines(patch):
    """RIGHT-side line numbers that appear in the patch's hunks (added or context lines)."""
    lines, right = set(), 0
    for raw in (patch or "").splitlines():
        m = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", raw)
        if m:
            right = int(m.group(1))
            continue
        if raw.startswith(("+", " ")):
            lines.add(right)
            right += 1
        # '-' lines and '\ No newline' markers don't advance the right side
    return lines


def ranges(nums):
    out = []
    for n in sorted(nums):
        if out and n == out[-1][1] + 1:
            out[-1][1] = n
        else:
            out.append([n, n])
    return ", ".join(f"{a}-{b}" if a != b else f"{a}" for a, b in out)


def problems(F):
    errs = []
    titles = [f.get("title") for f in F["findings"]]
    for t in {t for t in titles if titles.count(t) > 1}:
        errs.append(f"title used twice (links are matched on title): {t!r}")
    if len(F["sha"]) != 40:
        errs.append(f"sha must be the full 40-char head sha, got {F['sha']!r}")
    for i, f in enumerate(F["findings"], 1):
        for k in ("sev", "title", "text") + (() if kind(f) == "reply" else ("path",)):
            if not f.get(k):
                errs.append(f"finding {i}: missing {k!r}")
        if f.get("sev") not in SEVS:
            errs.append(f"finding {i}: sev must be one of {SEVS}, got {f.get('sev')!r}")
        if kind(f) == "line" and not isinstance(f.get("line"), int):
            errs.append(f"finding {i}: a line finding needs an int 'line' (or 'reply_to', or \"subject\": \"file\")")
    if errs:
        return errs
    meta, all_threads, files = pr_data(F["repo"], F["pr"])
    head = meta["headRefOid"]
    if head != F["sha"]:
        # The files endpoint only serves the current head's diff, so line checks would be against the wrong tree.
        return [f"PR head is {head[:9]}, findings are for {F['sha'][:9]}: recheck the findings on the new head"]
    threads = by_first_comment(all_threads)
    for label in ("resolve", "keep"):
        for r in F[label]:
            if not thread_for(r.get("thread"), all_threads):
                errs.append(f"{label} {r.get('thread')!r}: no review thread with that first-comment id or node id")
            if not r.get("why"):
                errs.append(f"{label} {r.get('thread')!r}: give the reason in 'why'")
            if any(f.get("reply_to") == r.get("thread") for f in F["findings"]):
                errs.append(f"{label} {r.get('thread')!r}: the same thread also gets a reply finding")
    for i, f in enumerate(F["findings"], 1):
        if kind(f) == "reply":
            if f["reply_to"] not in threads:
                errs.append(f"finding {i} ({f['title']!r}): reply_to {f['reply_to']} isn't the first comment of a "
                            f"review thread on this PR (see `gh_review.py threads`)")
            continue
        if f["path"] not in files:
            errs.append(f"finding {i} ({f['title']!r}): {f['path']} isn't changed in this PR; anchor it on a "
                        f"changed line it is about (e.g. the `use` line that brings the API in)")
            continue
        if kind(f) == "file":
            continue
        ok = commentable_lines(files[f["path"]].get("patch"))
        want = [n for n in (f.get("start_line"), f["line"]) if n is not None]
        if not all(n in ok for n in want):
            errs.append(f"finding {i} ({f['title']!r}): {f['path']}:{f['line']} is outside the diff hunks "
                        f"(commentable: {ranges(ok) or 'none'}); pick a changed line the finding is about, "
                        f"or set \"subject\": \"file\"")
    return errs


def report_check(F, errs):
    """Print `check`'s verdict: the problems, or the `ok:` counts line."""
    if errs:
        print("\n".join(f"- {e}" for e in errs))
        return
    n = {s: sum(f["sev"] == s for f in F["findings"]) for s in SEVS}
    k = {x: sum(kind(f) == x for f in F["findings"]) for x in ("line", "file", "reply")}
    print(f"ok: {len(F['findings'])} findings ({n['high']}H/{n['medium']}M/{n['low']}L; "
          f"{k['line']} line, {k['file']} file-level, {k['reply']} replies), {len(F['resolve'])} to resolve, "
          f"{len(F['keep'])} kept as they are, on {F['sha'][:9]}")


def cmd_check(a):
    F = load(a.findings)
    errs = problems(F)
    report_check(F, errs)
    if errs:
        sys.exit(1)


# ---------------------------------------------------------------- bodies

def comment_body(f, F):
    body = f"**{f['title']}**\n\n{f['text'].strip()}"
    if kind(f) == "file" and f.get("line"):
        start = f.get("start_line") or f["line"]
        anchor = f"#L{start}-L{f['line']}" if start != f["line"] else f"#L{start}"
        body += f"\n\nhttps://github.com/{F['repo']}/blob/{F['sha']}/{f['path']}{anchor}"
    return body


def overview(F, links):
    """The 'Review overview' body: summary, a counts line, one linked line per finding led by its severity, High→Low.

    The counts and the leading word are plain text, so how much is high, medium and low shows at a
    glance without Copilot's icons (see `badge`)."""
    items = sorted(F["findings"], key=lambda f: SEVS.index(f["sev"]))
    counts = " · ".join(f"{sum(f['sev'] == s for f in items)} {s}" for s in SEVS)
    lines = "\n".join(f"- {f['sev'].capitalize()}: [{f['title']}](#discussion_r{links[f['title']]})" for f in items)
    return (f"## Review overview\n\n### {F['heading']}\n\n{F['summary'].strip()}\n\n"
            f"**Findings:** {counts}\n\n{lines}\n\n{F['footer'].strip()}")


def placeholder(F):
    return f"I used Claude to check this on {F['sha'][:9]}. (Overview with links follows.)"


def payloads(F):
    line_comments, file_threads, replies = [], [], []
    for f in F["findings"]:
        body = comment_body(f, F)
        if kind(f) == "reply":
            replies.append(dict(reply_to=f["reply_to"], body=body))
        elif kind(f) == "file":
            file_threads.append(dict(path=f["path"], subjectType="FILE", body=body))
        else:
            c = dict(path=f["path"], line=f["line"], side="RIGHT", body=body)
            if f.get("start_line") and f["start_line"] != f["line"]:
                c.update(start_line=f["start_line"], start_side="RIGHT")
            line_comments.append(c)
    return line_comments, file_threads, replies


# ---------------------------------------------------------------- preview

PAGE_CSS = """
:root { --bg:#ffffff; --fg:#1f2328; --muted:#59636e; --border:#d1d9e0; --soft:#f6f8fa; --new:#dafbe1; --newfg:#1a7f37;
  --del:#ffebe9; --delfg:#cf222e; --hunk:#ddf4ff; --pill-r:#8250df; --pill-u:#9a6700; --pill-n:#0969da; }
@media (prefers-color-scheme: dark) { :root { --bg:#0d1117; --fg:#f0f6fc; --muted:#9198a1; --border:#3d444d; --soft:#151b23;
  --new:#12261e; --newfg:#3fb950; --del:#25171c; --delfg:#f85149; --hunk:#121d2f; --pill-r:#ab7df8; --pill-u:#d29922; --pill-n:#4493f8; } }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--fg); font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI","Noto Sans",Helvetica,Arial,sans-serif; }
main { max-width: 900px; margin: 0 auto; padding: 24px 16px 64px; }
h1 { font-size: 24px; font-weight: 400; margin: 0 0 4px; } h1 .num { color: var(--muted); }
.sub { color: var(--muted); margin-bottom: 8px; }
.banner { border:1px solid var(--pill-u); border-radius:6px; padding:8px 12px; margin:16px 0 24px; color:var(--pill-u); }
h2.sec { font-size: 16px; margin: 32px 0 12px; padding-bottom: 6px; border-bottom: 1px solid var(--border); }
.box { border:1px solid var(--border); border-radius:6px; margin: 0 0 16px; overflow:hidden; background:var(--bg); }
.boxhead { background:var(--soft); border-bottom:1px solid var(--border); padding:8px 12px; color:var(--muted); font-size:13px;
  display:flex; gap:8px; align-items:center; flex-wrap:wrap; }
.boxhead b { color: var(--fg); } .boxhead code { font-size:12px; color:var(--fg); }
.comment { padding: 12px 16px; border-top: 1px solid var(--border); } .comment:first-of-type { border-top: 0; }
.comment.new { box-shadow: inset 3px 0 0 var(--newfg); }
.who { font-size:13px; color:var(--muted); margin-bottom:6px; } .who b { color:var(--fg); }
.markdown-body { background: transparent !important; font-size: 14px; }
.why { padding: 10px 16px; border-bottom: 1px solid var(--border); background: var(--soft); }
.why > b { font-size: 13px; }
.pill { font-size:12px; font-weight:600; border:1px solid currentColor; border-radius:2em; padding:0 8px; }
.pill.resolve { color:var(--pill-r); } .pill.unresolve { color:var(--pill-u); } .pill.new { color:var(--newfg); } .pill.open { color:var(--pill-n); }
table.diff { width:100%; border-collapse:collapse; font:12px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace; }
table.diff td { padding:0 8px; white-space:pre-wrap; word-break:break-all; vertical-align:top; }
table.diff td.ln { width:1%; min-width:40px; color:var(--muted); text-align:right; user-select:none; }
tr.add td { background:var(--new); } tr.rem td { background:var(--del); } tr.hunk td { background:var(--hunk); color:var(--muted); }
tr.target td { outline: 1px solid var(--pill-u); }
details.old > summary { cursor:pointer; padding:8px 16px; color:var(--muted); font-size:13px; }
.empty { color: var(--muted); font-style: italic; }
"""


MD = {}


def gfm(repo, text):
    """GitHub's own GFM renderer, so badges, suggestions and links look the way they will once posted."""
    p = subprocess.run(["gh", "api", "markdown", "--input", "-"], capture_output=True, text=True,
                       input=json.dumps(dict(text=text, mode="gfm", context=repo)))
    if p.returncode:
        die(f"gh api markdown failed:\n{p.stderr}")
    return p.stdout


def prerender(repo, texts):
    """Render every body the page shows up front, in parallel: each render is one GitHub round trip.

    If a long recheck ever hits GitHub's secondary rate limit (a 403 from `gh api markdown`), drop to 4 workers."""
    todo = [t for t in dict.fromkeys(texts) if t and t not in MD]
    with ThreadPoolExecutor(8) as pool:
        MD.update(zip(todo, pool.map(lambda t: gfm(repo, t), todo)))


def render_md(repo, text):
    if text not in MD:
        MD[text] = gfm(repo, text)
    return f'<div class="markdown-body">{MD[text]}</div>'


def diff_excerpt(patch, start, end, context=4):
    """The hunk lines GitHub shows above an inline comment: a few lines before the commented range, then the range."""
    rows, left, right, hunk = [], 0, 0, None
    for raw in (patch or "").splitlines():
        m = re.match(r"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@", raw)
        if m:
            left, right, hunk = int(m.group(1)), int(m.group(2)), raw
            continue
        if raw.startswith("-"):
            rows.append(("rem", left, "", raw, hunk)); left += 1
        elif raw.startswith(("+", " ")):
            rows.append(("add" if raw[0] == "+" else "ctx", left if raw[0] == " " else "", right, raw, hunk))
            left += raw[0] == " "; right += 1
    idx = [i for i, r in enumerate(rows) if r[2] != "" and start <= r[2] <= end]
    if not idx:
        return '<p class="comment empty">(line not in the diff)</p>'
    lo = max(0, idx[0] - context)
    while lo < idx[0] and rows[lo][4] != rows[idx[0]][4]:
        lo += 1
    out = [f'<tr class="hunk"><td class="ln"></td><td class="ln"></td><td>{html.escape(rows[idx[0]][4] or "")}</td></tr>']
    for cls, l, r, raw, _ in rows[lo: idx[-1] + 1]:
        tgt = " target" if r != "" and start <= r <= end else ""
        out.append(f'<tr class="{cls}{tgt}"><td class="ln">{l}</td><td class="ln">{r}</td><td>{html.escape(raw)}</td></tr>')
    return f'<table class="diff">{"".join(out)}</table>'


def comment_html(repo, author, body, when="", new=False):
    tag = ' <span class="pill new">new</span>' if new else ""
    return (f'<div class="comment{" new" if new else ""}"><div class="who"><b>{html.escape(author or "?")}</b> '
            f'{html.escape(when)}{tag}</div>{render_md(repo, body)}</div>')


def thread_html(repo, t, pill, extra="", why="", why_label="Why it is addressed"):
    """An existing thread as GitHub shows it, with the action this run takes on it and (for a resolve) why."""
    cs = t["comments"]["nodes"]
    loc = f"{t['path']}:{t['line'] or t['originalLine'] or 'file'}"
    state = "resolved" if t["isResolved"] else "open"
    old = "".join(comment_html(repo, (c.get("author") or {}).get("login"), c["body"], c["createdAt"][:16].replace("T", " "))
                  for c in cs)
    reason = f'<div class="why"><b>{why_label}:</b>{render_md(repo, why)}</div>' if why else ""
    return (f'<div class="box"><div class="boxhead"><code>{html.escape(loc)}</code> · now {state} · '
            f'started by {html.escape((cs[0].get("author") or {}).get("login", "?") if cs else "?")} '
            f'{pill}<b>{html.escape(title_of(cs[0]["body"]) if cs else "")}</b></div>{reason}'
            f'<details class="old" open><summary>{len(cs)} earlier comment(s)</summary>{old}</details>'
            f'{extra}</div>')


def render_preview(repo, pr, sha, findings, resolve, unresolve, overview_md, user, out, keep=()):
    """Write a self-contained GitHub-style page of everything a post/resolve run would send.

    resolve/unresolve/keep: [{"thread": first-comment id or node id, "why": markdown}]."""
    meta, threads, files = pr_data(repo, pr)
    first = by_first_comment(threads)
    shown = [first.get(f["reply_to"]) for f in findings if f.get("kind") == "reply"]
    shown += [thread_for(r["thread"], threads) for r in (*resolve, *unresolve, *keep)]
    prerender(repo, [overview_md, *(f["body"] for f in findings), *(r.get("why") for r in (*resolve, *unresolve, *keep)),
                     *(c["body"] for t in shown if t for c in t["comments"]["nodes"])])
    css = CSS.read_text() if CSS.exists() else ""
    parts = [f'<h1>{html.escape(meta["title"])} <span class="num">#{pr}</span></h1>',
             f'<div class="sub">{html.escape(repo)} · head <code>{sha[:9]}</code></div>',
             '<div class="banner">Preview: nothing here has been sent to GitHub.</div>']
    replies = [f for f in findings if f.get("kind") == "reply"]
    fresh = [f for f in findings if f.get("kind") != "reply"]
    parts.append('<h2 class="sec">Review body</h2>')
    if overview_md:
        parts.append(f'<div class="box"><div class="boxhead"><b>{html.escape(user)}</b> reviewed · Comment</div>'
                     f'{comment_html(repo, user, overview_md, new=True)}</div>')
    else:
        parts.append('<p class="empty">No review would be posted.</p>')
    parts.append(f'<h2 class="sec">New threads ({len(fresh)})</h2>')
    for f in fresh:
        path, line = f["path"], f.get("line")
        if f.get("kind") == "file" or not line:
            excerpt = '<p class="comment empty">File-level comment</p>'
        else:
            excerpt = diff_excerpt(files.get(path, {}).get("patch"), f.get("start_line") or line, line)
        parts.append(f'<div class="box"><div class="boxhead"><code>{html.escape(path)}{":" + str(line) if line else ""}</code>'
                     f'<span class="pill new">new thread</span></div>{excerpt}{comment_html(repo, user, f["body"], new=True)}</div>')
    if not fresh:
        parts.append('<p class="empty">None.</p>')
    parts.append(f'<h2 class="sec">Replies on existing threads ({len(replies)})</h2>')
    for f in replies:
        t = first.get(f["reply_to"])
        if not t:
            parts.append(f'<p class="empty">reply_to {f["reply_to"]}: no such thread</p>')
            continue
        pill = '<span class="pill unresolve">will unresolve</span>' if t["isResolved"] else '<span class="pill open">stays open</span>'
        parts.append(thread_html(repo, t, pill, comment_html(repo, user, f["body"], new=True)))
    if not replies:
        parts.append('<p class="empty">None.</p>')
    for label, rows, cls in (("Threads to resolve", resolve, "resolve"), ("Threads to unresolve", unresolve, "unresolve"),
                             ("Threads left as they are", keep, "keep")):
        parts.append(f'<h2 class="sec">{label} ({len(rows)})</h2>')
        for r in rows:
            t = thread_for(r["thread"], threads)
            pill = '<span class="pill open">unchanged</span>' if cls == "keep" else f'<span class="pill {cls}">will {cls}</span>'
            parts.append(thread_html(repo, t, pill, why=r.get("why", ""), why_label="Why it stays as it is" if cls == "keep" else "Why it is addressed") if t
                         else f'<p class="empty">{html.escape(str(r["thread"]))}: no such thread</p>')
        if not rows:
            parts.append('<p class="empty">None.</p>')
    Path(out).write_text(f'<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" '
                         f'content="width=device-width, initial-scale=1"><title>Review preview #{pr}</title>'
                         f'<style>{css}\n{PAGE_CSS}</style></head><body><main>{"".join(parts)}</main></body></html>')
    print(f"preview: {out}")


def preview_from_findings(F, out, user):
    items = [dict(kind=kind(f), path=f.get("path"), line=f.get("line"), start_line=f.get("start_line"),
                  reply_to=f.get("reply_to"), body=comment_body(f, F)) for f in F["findings"]]
    links = {f["title"]: f"PENDING{i}" for i, f in enumerate(F["findings"], 1)}
    render_preview(F["repo"], F["pr"], F["sha"], items, F["resolve"], [], overview(F, links) if items else None, user, out,
                   keep=F["keep"])


def viewer():
    return gh(["user"])["login"]


def cmd_preview(a):
    preview_from_findings(load(a.findings), a.out, viewer())


# ---------------------------------------------------------------- post

def cmd_post(a):
    F = load(a.findings)
    errs = problems(F)
    report_check(F, errs)
    if errs and not a.dry_run:
        sys.exit(1)
    line_comments, file_threads, replies = payloads(F)
    if a.dry_run:
        out = Path(a.dry_run)
        out.mkdir(parents=True, exist_ok=True)
        review = dict(commit_id=F["sha"], body=placeholder(F), comments=line_comments)
        if not (file_threads or replies):
            review["event"] = "COMMENT"
        (out / "review.json").write_text(json.dumps(review, indent=1))
        for name, rows in (("file_threads.json", file_threads), ("replies.json", replies)):
            if rows:
                (out / name).write_text(json.dumps(rows, indent=1))
        links = {f["title"]: f"PENDING{i}" for i, f in enumerate(F["findings"], 1)}
        if F["findings"]:
            (out / "body.md").write_text(overview(F, links))
        (out / "resolve.json").write_text(json.dumps(F["resolve"], indent=1))
        preview_from_findings(F, out / "preview.html", viewer())
        print(f"dry run: {len(line_comments)} line comments, {len(file_threads)} file threads, {len(replies)} replies, "
              f"{len(F['resolve'])} resolves, {len(F['keep'])} kept; wrote {', '.join(sorted(p.name for p in out.iterdir()))} "
              f"to {out}; nothing sent")
        if errs:
            sys.exit(1)
        return
    if not F["findings"] and not F["resolve"]:
        print("nothing to send: no findings and nothing to resolve")
        return
    if F["findings"]:
        post_review(F, a.findings, line_comments, file_threads, replies)
    _, threads = fetch_threads(F["repo"], F["pr"])
    for r in F["resolve"]:
        t = thread_for(r["thread"], threads)
        if not t["isResolved"]:
            gql("mutation($t:ID!) { resolveReviewThread(input:{threadId:$t}) { thread { id } } }", t=t["id"])
        print(f"resolved {t['id']} ({title_of(t['comments']['nodes'][0]['body'])!r})")


def post_review(F, findings_path, line_comments, file_threads, replies):
    base = f"repos/{F['repo']}/pulls/{F['pr']}/reviews"
    if not (file_threads or replies):
        rev = gh([base, "-X", "POST"], dict(commit_id=F["sha"], event="COMMENT",
                                            body=placeholder(F), comments=line_comments))
    else:
        # A PENDING review (no event) takes file-level threads and thread replies over GraphQL before it's submitted.
        rev = gh([base, "-X", "POST"], dict(commit_id=F["sha"], body=placeholder(F), comments=line_comments))
        for t in file_threads:
            gql("mutation($r:ID!, $p:String!, $b:String!) { addPullRequestReviewThread(input:"
                "{pullRequestReviewId:$r, path:$p, subjectType:FILE, body:$b}) { thread { id } } }",
                r=rev["node_id"], p=t["path"], b=t["body"])
        threads = by_first_comment(fetch_threads(F["repo"], F["pr"])[1])
        for r in replies:
            gql("mutation($r:ID!, $t:ID!, $b:String!) { addPullRequestReviewThreadReply(input:"
                "{pullRequestReviewId:$r, pullRequestReviewThreadId:$t, body:$b}) { comment { databaseId } } }",
                r=rev["node_id"], t=threads[r["reply_to"]]["id"], b=r["body"])
        gh([f"{base}/{rev['id']}/events", "-X", "POST"], dict(event="COMMENT", body=placeholder(F)))
    print(f"posted review {rev['id']}: {rev['html_url']}")
    link(F, rev["id"], findings_path)
    if replies:
        threads = by_first_comment(fetch_threads(F["repo"], F["pr"])[1])
        for r in replies:
            t = threads[r["reply_to"]]
            if t["isResolved"]:
                gql("mutation($t:ID!) { unresolveReviewThread(input:{threadId:$t}) { thread { id } } }", t=t["id"])
                print(f"unresolved {t['id']} ({title_of(t['comments']['nodes'][0]['body'])!r}): it got a reply finding")


def link(F, rid, findings_path):
    """Match each finding to its posted comment, PUT the linked overview, and diff what GitHub stored."""
    mine = [c for c in paged(f"repos/{F['repo']}/pulls/{F['pr']}/comments") if c["pull_request_review_id"] == rid]
    links, bad = {}, []
    for f in F["findings"]:
        if kind(f) == "reply":
            m = [c for c in mine if c.get("in_reply_to_id") == f["reply_to"] and f"**{f['title']}**" in c["body"]]
        else:
            m = [c for c in mine if c["path"] == f["path"] and not c.get("in_reply_to_id") and f"**{f['title']}**" in c["body"]]
        if len(m) != 1:
            bad.append(f"{f['title']!r}: {len(m)} matching comments")
            continue
        links[f["title"]] = m[0]["id"]
        if m[0]["body"] != comment_body(f, F):
            bad.append(f"{f['title']!r}: stored comment body differs from what was sent")
    if any("matching comments" in b for b in bad):
        die("can't link the overview:\n" + "\n".join(bad) + f"\nfix, then: gh_review.py link {findings_path} --review {rid}")
    body = overview(F, links)
    gh([f"repos/{F['repo']}/pulls/{F['pr']}/reviews/{rid}", "-X", "PUT"], dict(body=body))
    stored = gh([f"repos/{F['repo']}/pulls/{F['pr']}/reviews/{rid}"])["body"]
    if stored != body:
        bad.append("stored review body differs from the overview that was sent")
    posted = dict(review_id=rid, commit_id=F["sha"], comments=links)
    Path(findings_path).with_name(Path(findings_path).stem + ".posted.json").write_text(json.dumps(posted, indent=1))
    print(json.dumps(posted, indent=1))
    print("\n".join(f"warning: {b}" for b in bad) if bad else "verified: every comment and the overview body match what was sent")


def cmd_link(a):
    link(load(a.findings), a.review, a.findings)


# ---------------------------------------------------------------- resolve

def cmd_resolve(a):
    _, threads = fetch_threads(a.repo, a.pr)
    first, by_id = by_first_comment(threads), {t["id"]: t for t in threads}
    targets = []
    for i in a.ids:
        t = by_id.get(i) or (first.get(int(i)) if i.isdigit() else None)
        if not t:
            die(f"{i}: no review thread with that node id or first-comment id on {a.repo}#{a.pr}")
        targets.append(t)
    verb = "unresolveReviewThread" if a.unresolve else "resolveReviewThread"
    for t in targets:
        label = f"{t['id']} {t['path']} {title_of(t['comments']['nodes'][0]['body'])!r}"
        if a.dry_run:
            print(f"would {verb}: {label} (now {'resolved' if t['isResolved'] else 'open'})")
            continue
        r = gql(f"mutation($t:ID!) {{ {verb}(input:{{threadId:$t}}) {{ thread {{ id isResolved }} }} }}", t=t["id"])
        print(f"{verb}: {label} -> isResolved={r[verb]['thread']['isResolved']}")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    def pr_args(s, required=True):
        s.add_argument("--repo", default="nushell/nushell")
        s.add_argument("--pr", type=int, required=required)

    s = sub.add_parser("threads"); pr_args(s); s.add_argument("--json", action="store_true")
    s.add_argument("--full", action="store_true", help="print whole comment bodies instead of one-line snippets")
    s.add_argument("--since", metavar="SHA", help="mark the commits after SHA (the head the last review checked)")
    s = sub.add_parser("check"); s.add_argument("findings")
    s = sub.add_parser("preview"); s.add_argument("findings"); s.add_argument("--out", required=True)
    s = sub.add_parser("post"); s.add_argument("findings")
    s.add_argument("--dry-run", metavar="DIR", help="write the payloads, body.md and preview.html to DIR; send nothing")
    s = sub.add_parser("link"); s.add_argument("findings"); s.add_argument("--review", type=int, required=True)
    s = sub.add_parser("resolve"); pr_args(s); s.add_argument("ids", nargs="+")
    s.add_argument("--unresolve", action="store_true"); s.add_argument("--dry-run", action="store_true")

    a = p.parse_args()
    dict(threads=cmd_threads, check=cmd_check, preview=cmd_preview, post=cmd_post, link=cmd_link,
         resolve=cmd_resolve)[a.cmd](a)


if __name__ == "__main__":
    main()
