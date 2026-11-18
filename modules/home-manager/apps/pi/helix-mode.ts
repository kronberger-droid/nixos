/**
 * Helix-style modal editing for pi's prompt editor.
 *
 * Modelled on reedline's `Helix` edit mode (nushell): selection-first editing
 * with Normal / Insert / Select modes, a count prefix, and pending-argument
 * keys (`f`/`t`/`r`/`g`/`m`). Starts in Insert mode, like reedline.
 *
 * Normal mode
 *   h l j k        move (j/k walk prompt history at the edges, like Up/Down)
 *   w b e W B E    select word motions
 *   f F t T <ch>   select to/till char on the line
 *   gh gl gs gg ge goto line start/end/first non-blank, buffer start/end
 *   x  %           select line (repeat to extend) / select all
 *   ;  alt-;       collapse selection / flip anchor and head
 *   i a I A o O    enter insert (before/after selection, line start/end, open line)
 *   d c y          cut / change / yank selection (alt-d, alt-c: without yanking)
 *   p P            paste after / before selection
 *   r <ch>         replace selection with char
 *   ~ ` alt-`      switch case / lowercase / uppercase
 *   u U            undo / redo
 *   v              toggle select mode (motions extend)
 *   mi<obj> ma<obj> select inside/around: w W ( [ { < " ' ` or any ascii pair
 *   ms<ch> md<ch> mr<old><new>  add / delete / replace surround; mm match bracket
 *   Enter          submit
 *   Esc            drop selection; with nothing selected, falls through to pi
 *                  (interrupts the agent)
 *
 * Every other key (ctrl chords, arrows, Tab, ...) goes to pi's editor, so app
 * shortcuts keep working. `/helix` toggles the mode off and on.
 *
 * Note: pi's `Editor` exposes no public cursor/selection API, so this reaches
 * into its runtime fields (`state`, `segment`, `undo`, ...). Re-check after
 * pi upgrades.
 */

import { CustomEditor, type ExtensionAPI, type ExtensionContext, type KeybindingsManager } from "@earendil-works/pi-coding-agent";
import { decodeKittyPrintable, type EditorTheme, parseKey, type TUI, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type Mode = "normal" | "insert" | "select";
type Dir = "forward" | "backward";
type Pending =
	| { kind: "find"; dir: Dir; till: boolean; count: number }
	| { kind: "replace" }
	| { kind: "goto" }
	| { kind: "match1"; count: number }
	| { kind: "match2"; action: "i" | "a" | "s" | "d" | "r"; count: number }
	| { kind: "matchReplace"; old: string };

type Cat = "eol" | "ws" | "word" | "punct";

const SEL_END = "\x1b[49m";
const BRACKETS: Record<string, [string, string]> = {
	"(": ["(", ")"],
	")": ["(", ")"],
	"[": ["[", "]"],
	"]": ["[", "]"],
	"{": ["{", "}"],
	"}": ["{", "}"],
	"<": ["<", ">"],
	">": ["<", ">"],
};

function category(g: string | undefined, long: boolean): Cat {
	if (g === undefined || g === "\n") return "eol";
	if (/^\s+$/u.test(g)) return "ws";
	if (long) return "word";
	if (/^[\p{L}\p{N}_]/u.test(g) || g.startsWith("[paste #")) return "word";
	return "punct";
}

function pairFor(ch: string): [string, string] | undefined {
	if (BRACKETS[ch]) return BRACKETS[ch];
	// reedline: any printable ascii char forms a symmetric pair (quotes etc.)
	if (/^[\x21-\x7e]$/.test(ch) && !/[\p{L}\p{N}]/u.test(ch)) return [ch, ch];
	return undefined;
}

const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));

/** Buffer helpers over an array of graphemes; positions are grapheme indices. */
class Buf {
	constructor(public gs: string[]) {}
	get n() {
		return this.gs.length;
	}
	cat(i: number, long = false) {
		return category(this.gs[i], long);
	}
	lineStart(p: number) {
		while (p > 0 && this.gs[p - 1] !== "\n") p--;
		return p;
	}
	/** Index of the line's newline, or n on the last line. */
	lineEnd(p: number) {
		while (p < this.n && this.gs[p] !== "\n") p++;
		return p;
	}
	firstNonBlank(p: number) {
		let k = this.lineStart(p);
		while (k < this.n && this.cat(k) === "ws") k++;
		return k;
	}
	toLC(pos: number) {
		let line = 0;
		let col = 0;
		for (let k = 0; k < pos && k < this.n; k++) {
			if (this.gs[k] === "\n") {
				line++;
				col = 0;
			} else col += this.gs[k]!.length;
		}
		return { line, col };
	}
	fromLC(line: number, col: number) {
		let l = 0;
		let k = 0;
		while (k < this.n && l < line) if (this.gs[k++] === "\n") l++;
		let c = 0;
		while (k < this.n && this.gs[k] !== "\n" && c < col) c += this.gs[k++]!.length;
		return k;
	}

	// ── word motions (helix semantics: skip a boundary, then select a run) ──
	private skipBoundaryForward(head: number, long: boolean) {
		let s = head;
		if (s + 1 < this.n && this.cat(s, long) !== this.cat(s + 1, long)) s++;
		while (s < this.n && this.gs[s] === "\n") s++;
		return s;
	}
	nextWordStart(head: number, long: boolean): [number, number] | null {
		const s = this.skipBoundaryForward(head, long);
		if (s >= this.n) return null;
		let i = s;
		const c = this.cat(i, long);
		while (i < this.n && this.cat(i, long) === c) i++;
		if (c !== "ws") while (i < this.n && this.cat(i, long) === "ws") i++;
		return [s, i - 1];
	}
	nextWordEnd(head: number, long: boolean): [number, number] | null {
		const s = this.skipBoundaryForward(head, long);
		if (s >= this.n) return null;
		let i = s;
		while (i < this.n && this.cat(i, long) === "ws") i++;
		const c = this.cat(i, long);
		if (c !== "eol") while (i < this.n && this.cat(i, long) === c) i++;
		return [s, Math.max(s, i - 1)];
	}
	prevWordStart(head: number, long: boolean): [number, number] | null {
		if (this.n === 0 || head === 0) return null;
		let s = Math.min(head, this.n - 1);
		if (head < this.n && this.cat(s, long) !== this.cat(s - 1, long)) s--;
		while (s > 0 && this.gs[s] === "\n") s--;
		let i = s;
		while (i > 0 && (this.cat(i, long) === "ws" || this.cat(i, long) === "eol")) i--;
		const c = this.cat(i, long);
		while (i > 0 && this.cat(i - 1, long) === c) i--;
		return [s, i];
	}

	/** f/t/F/T within the current line. Returns the new head or null. */
	find(head: number, ch: string, dir: Dir, till: boolean, count: number): number | null {
		let pos = head;
		for (let c = 0; c < count; c++) {
			let found = -1;
			if (dir === "forward") {
				for (let k = pos + (till ? 2 : 1); k < this.n && this.gs[k] !== "\n"; k++)
					if (this.gs[k] === ch) {
						found = k;
						break;
					}
				if (found < 0) return c === 0 ? null : pos;
				pos = till ? found - 1 : found;
			} else {
				for (let k = pos - (till ? 2 : 1); k >= 0 && this.gs[k] !== "\n"; k--)
					if (this.gs[k] === ch) {
						found = k;
						break;
					}
				if (found < 0) return c === 0 ? null : pos;
				pos = till ? found + 1 : found;
			}
		}
		return pos;
	}

	// ── text objects ──
	enclosingBrackets(p: number, open: string, close: string, count: number): [number, number] | null {
		let result: [number, number] | null = null;
		let from = p;
		for (let c = 0; c < count; c++) {
			let s = -1;
			if (c === 0 && this.gs[from] === open) s = from;
			else {
				let depth = 0;
				let k = c === 0 && this.gs[from] === close ? from - 1 : from;
				for (; k >= 0; k--) {
					if (this.gs[k] === close) depth++;
					else if (this.gs[k] === open) {
						if (depth === 0) {
							s = k;
							break;
						}
						depth--;
					}
				}
			}
			if (s < 0) return result;
			let depth = 0;
			let e = -1;
			for (let k = s + 1; k < this.n; k++) {
				if (this.gs[k] === open) depth++;
				else if (this.gs[k] === close) {
					if (depth === 0) {
						e = k;
						break;
					}
					depth--;
				}
			}
			if (e < 0) return result;
			result = [s, e];
			from = s - 1;
			if (from < 0) break;
		}
		return result;
	}
	enclosingQuotes(p: number, q: string): [number, number] | null {
		const ls = this.lineStart(p);
		const le = this.lineEnd(p);
		const qs: number[] = [];
		for (let k = ls; k < le; k++) if (this.gs[k] === q) qs.push(k);
		const at = qs.indexOf(p);
		if (at >= 0) {
			if (at % 2 === 0) return at + 1 < qs.length ? [qs[at]!, qs[at + 1]!] : null;
			return [qs[at - 1]!, qs[at]!];
		}
		const before = qs.filter((k) => k < p).length;
		if (before % 2 === 1 && before < qs.length) return [qs[before - 1]!, qs[before]!];
		return null;
	}
	enclosingPair(p: number, ch: string, count: number): [number, number] | null {
		const pair = pairFor(ch);
		if (!pair) return null;
		return pair[0] === pair[1] ? this.enclosingQuotes(p, pair[0]) : this.enclosingBrackets(p, pair[0], pair[1], count);
	}
	wordObject(p: number, long: boolean, around: boolean): [number, number] | null {
		if (p >= this.n || this.gs[p] === "\n") return null;
		const c = this.cat(p, long);
		let s = p;
		let e = p;
		while (s > 0 && this.cat(s - 1, long) === c) s--;
		while (e + 1 < this.n && this.cat(e + 1, long) === c) e++;
		if (around && c !== "ws") {
			if (e + 1 < this.n && this.cat(e + 1) === "ws") {
				while (e + 1 < this.n && this.cat(e + 1) === "ws") e++;
			} else {
				while (s > 0 && this.cat(s - 1) === "ws") s--;
			}
		}
		return [s, e];
	}
	matchingBracket(p: number): number | null {
		const ch = this.gs[p];
		if (!ch || !BRACKETS[ch]) return null;
		const [open, close] = BRACKETS[ch]!;
		const r = this.enclosingBrackets(p, open, close, 1);
		if (!r) return null;
		return ch === open ? r[1] : r[0];
	}
}

function printable(data: string): string | undefined {
	const kitty = decodeKittyPrintable(data);
	if (kitty !== undefined) return kitty;
	if (data.length === 0 || data.startsWith("\x1b")) return undefined;
	const cp = data.codePointAt(0)!;
	if (cp < 32 || cp === 0x7f) return undefined;
	return [...data].length === 1 ? data : undefined;
}

class HelixEditor extends CustomEditor {
	private mode: Mode = "insert";
	private count: number | null = null;
	private pending: Pending | null = null;
	private anchor = 0;
	private head = 0;
	private register = "";
	private redoStack: { lines: string[]; cursorLine: number; cursorCol: number }[] = [];
	private syncText: string | null = null;
	private syncCursor = "";

	constructor(
		tui: TUI,
		theme: EditorTheme,
		keybindings: KeybindingsManager,
		private readonly ctx: ExtensionContext,
	) {
		super(tui, theme, keybindings);
		// `layoutText` is private on Editor; shadow it per-instance to paint the selection.
		const baseLayout = Object.getPrototypeOf(HelixEditor.prototype).layoutText;
		this.ed.layoutText = (width: number) => this.layoutWithSelection(baseLayout, width);
	}

	/** Untyped handle on Editor's private runtime fields. */
	private get ed(): any {
		return this;
	}

	// ── state bridging ───────────────────────────────────────────────────────

	private buf(): Buf {
		return new Buf([...this.ed.segment(this.getText(), "grapheme")].map((s: { segment: string }) => s.segment));
	}

	private remember() {
		const c = this.getCursor();
		this.syncText = this.getText();
		this.syncCursor = `${c.line}:${c.col}`;
	}

	/** Collapse the selection onto pi's cursor if something else moved it or edited the text. */
	private syncFromBase(clearRedo = true) {
		const text = this.getText();
		const c = this.getCursor();
		if (text === this.syncText && `${c.line}:${c.col}` === this.syncCursor) return;
		if (clearRedo && this.syncText !== null && text !== this.syncText) this.redoStack = [];
		this.anchor = this.head = this.buf().fromLC(c.line, c.col);
		this.remember();
	}

	private commit(b: Buf, anchor: number, head: number, mutated: boolean) {
		const ed = this.ed;
		if (mutated) {
			ed.cancelAutocomplete?.();
			ed.exitHistoryBrowsing?.();
			ed.pushUndoSnapshot();
			ed.state.lines = b.gs.join("").split("\n");
			this.redoStack = [];
		}
		this.anchor = clamp(anchor, 0, b.n);
		this.head = clamp(head, 0, b.n);
		const { line, col } = b.toLC(this.head);
		ed.state.cursorLine = line;
		ed.state.cursorCol = col;
		ed.preferredVisualCol = null;
		ed.lastAction = null;
		if (mutated) this.onChange?.(this.getText());
		this.remember();
	}

	/** Selected grapheme range [from, to). Helix selections always cover the head. */
	private range(n: number): [number, number] {
		const from = Math.min(this.anchor, this.head, n);
		const to = Math.min(Math.max(this.anchor, this.head) + 1, n);
		return [from, Math.max(from, to)];
	}

	private setMode(mode: Mode) {
		this.mode = mode;
		this.pending = null;
		this.count = null;
	}

	// ── input ────────────────────────────────────────────────────────────────

	handleInput(data: string): void {
		const ed = this.ed;
		if (ed.isInPaste || data.includes("\x1b[200~")) {
			super.handleInput(data);
			return;
		}

		const key = parseKey(data);

		if (this.mode === "insert") {
			if (key === "escape" && !this.isShowingAutocomplete()) {
				this.setMode("normal");
				this.syncFromBase();
				return;
			}
			super.handleInput(data);
			return;
		}

		this.syncFromBase();

		if (key === "escape") {
			if (this.pending || this.count !== null) {
				this.pending = null;
				this.count = null;
			} else if (this.mode === "select") {
				this.setMode("normal");
			} else if (this.anchor !== this.head) {
				this.anchor = this.head;
			} else {
				super.handleInput(data); // pi: interrupt agent, etc.
			}
			return;
		}

		const ch = printable(data);

		if (this.pending) {
			const p = this.pending;
			this.pending = null;
			if (ch !== undefined) this.completePending(p, ch);
			this.count = null;
			return;
		}

		if (ch !== undefined && /^[0-9]$/.test(ch) && (ch !== "0" || this.count !== null)) {
			this.count = Math.min((this.count ?? 0) * 10 + Number(ch), 9999);
			return;
		}

		if (ch !== undefined) {
			const count = this.count ?? 1;
			const hadCount = this.count !== null;
			this.count = null;
			this.interpret(ch, count, hadCount);
			return;
		}

		const count = this.count ?? 1;
		this.count = null;
		switch (key) {
			case "alt+d":
				return this.cut(false, "normal");
			case "alt+c":
				return this.cut(false, "insert");
			case "alt+`":
				return this.mapCase((s) => s.toUpperCase());
			case "alt+;":
				[this.anchor, this.head] = [this.head, this.anchor];
				return this.commit(this.buf(), this.anchor, this.head, false);
			case "enter": {
				const b = this.buf();
				const [, to] = this.range(b.n);
				this.commit(b, to, to, false);
				this.setMode("insert");
				super.handleInput(data);
				return;
			}
			case "backspace":
				return this.interpret("h", count, false);
		}
		if (this.mode === "select") {
			const arrows: Record<string, string> = { left: "h", right: "l", up: "k", down: "j" };
			if (key && arrows[key]) return this.interpret(arrows[key]!, count, false);
		}
		super.handleInput(data);
		this.syncFromBase();
	}

	private interpret(ch: string, count: number, hadCount: boolean) {
		const b = this.buf();
		const extend = this.mode === "select";
		const [from, to] = this.range(b.n);

		const motion = (fn: (head: number) => [number, number] | null) => {
			let anchor = this.anchor;
			let head = this.head;
			for (let i = 0; i < count; i++) {
				const r = fn(head);
				if (!r) break;
				[anchor, head] = r;
			}
			this.commit(b, extend ? this.anchor : anchor, head, false);
		};

		switch (ch) {
			case "h":
			case "l": {
				const head = clamp(this.head + (ch === "l" ? count : -count), 0, b.n);
				return this.commit(b, extend ? this.anchor : head, head, false);
			}
			case "j":
			case "k": {
				if (extend) {
					const anchor = this.anchor;
					for (let i = 0; i < count; i++) this.ed.moveCursor(ch === "j" ? 1 : -1, 0);
					const c = this.getCursor();
					this.anchor = anchor;
					this.head = this.buf().fromLC(c.line, c.col);
					this.remember();
				} else {
					for (let i = 0; i < count; i++) super.handleInput(ch === "j" ? "\x1b[B" : "\x1b[A");
					this.syncFromBase();
				}
				return;
			}
			case "w":
			case "W":
				return motion((h) => b.nextWordStart(h, ch === "W"));
			case "e":
			case "E":
				return motion((h) => b.nextWordEnd(h, ch === "E"));
			case "b":
			case "B":
				return motion((h) => b.prevWordStart(h, ch === "B"));
			case "f":
			case "F":
			case "t":
			case "T":
				this.pending = { kind: "find", dir: ch === "f" || ch === "t" ? "forward" : "backward", till: ch.toLowerCase() === "t", count };
				return;
			case "r":
				this.pending = { kind: "replace" };
				return;
			case "m":
				this.pending = { kind: "match1", count };
				return;
			case "g":
				// helix reads `3g` as goto-line; unsupported, like reedline
				if (!hadCount) this.pending = { kind: "goto" };
				return;
			case "x": {
				if (b.n === 0) return;
				// Grow to whole lines; if already whole lines, each press adds the next one.
				const lineEndIncl = (p: number) => Math.min(b.lineEnd(p), b.n - 1);
				const s = b.lineStart(from);
				let e = to - 1;
				const whole = s === from && lineEndIncl(e) === e && from !== to - 1;
				e = lineEndIncl(e);
				for (let i = whole ? 0 : 1; i < count && e + 1 < b.n; i++) e = lineEndIncl(e + 1);
				return this.commit(b, s, e, false);
			}
			case "%":
				return this.commit(b, 0, Math.max(0, b.n - 1), false);
			case ";":
				return this.commit(b, this.head, this.head, false);
			case "~":
				return this.mapCase((s) => (s === s.toUpperCase() ? s.toLowerCase() : s.toUpperCase()));
			case "`":
				return this.mapCase((s) => s.toLowerCase());
			case "v":
				this.setMode(this.mode === "select" ? "normal" : "select");
				return;
			case "i":
				this.commit(b, from, from, false);
				return this.setMode("insert");
			case "a":
				this.commit(b, to, to, false);
				return this.setMode("insert");
			case "I": {
				const p = b.firstNonBlank(this.head);
				this.commit(b, p, p, false);
				return this.setMode("insert");
			}
			case "A": {
				const p = b.lineEnd(this.head);
				this.commit(b, p, p, false);
				return this.setMode("insert");
			}
			case "o":
			case "O": {
				const at = ch === "o" ? b.lineEnd(this.head) : b.lineStart(this.head);
				b.gs.splice(at, 0, ...Array(count).fill("\n"));
				const p = ch === "o" ? at + count : at;
				this.commit(b, p, p, true);
				return this.setMode("insert");
			}
			case "d":
				return this.cut(true, "normal");
			case "c":
				return this.cut(true, "insert");
			case "y":
				this.register = b.gs.slice(from, to).join("");
				if (this.mode === "select") this.setMode("normal");
				return;
			case "p":
			case "P": {
				if (!this.register) return;
				const ins = [...this.ed.segment(this.register.repeat(count), "grapheme")].map((s: { segment: string }) => s.segment);
				const at = ch === "p" ? to : from;
				b.gs.splice(at, 0, ...ins);
				this.commit(b, at, at + ins.length - 1, true);
				if (this.mode === "select") this.setMode("normal");
				return;
			}
			case "u":
			case "U":
				for (let i = 0; i < count; i++) (ch === "u" ? this.undoOnce() : this.redoOnce());
				return;
		}
	}

	private completePending(p: Pending, ch: string) {
		const b = this.buf();
		const extend = this.mode === "select";
		switch (p.kind) {
			case "find": {
				const head = b.find(this.head, ch, p.dir, p.till, p.count);
				if (head !== null) this.commit(b, extend ? this.anchor : this.head, head, false);
				return;
			}
			case "replace": {
				const [from, to] = this.range(b.n);
				if (from === to) return;
				for (let k = from; k < to; k++) if (b.gs[k] !== "\n") b.gs[k] = ch;
				return this.commit(b, this.anchor, this.head, true);
			}
			case "goto": {
				const targets: Record<string, () => number> = {
					h: () => b.lineStart(this.head),
					l: () => Math.max(b.lineStart(this.head), b.lineEnd(this.head) - 1),
					s: () => b.firstNonBlank(this.head),
					g: () => 0,
					e: () => b.n,
				};
				const t = targets[ch];
				if (t) {
					const head = t();
					this.commit(b, extend ? this.anchor : head, head, false);
				}
				return;
			}
			case "match1":
				if (ch === "m") {
					const m = b.matchingBracket(this.head);
					if (m !== null) this.commit(b, extend ? this.anchor : m, m, false);
				} else if ("aisdr".includes(ch)) {
					this.pending = { kind: "match2", action: ch as "a" | "i" | "s" | "d" | "r", count: p.count };
				}
				return;
			case "match2": {
				const isWord = ch === "w" || ch === "W";
				if (p.action === "i" || p.action === "a") {
					const around = p.action === "a";
					let r: [number, number] | null;
					if (isWord) r = b.wordObject(this.head, ch === "W", around);
					else {
						r = b.enclosingPair(this.head, ch, p.count);
						if (r && !around) r = r[1] - r[0] > 1 ? [r[0] + 1, r[1] - 1] : null;
					}
					if (r) this.commit(b, r[0], r[1], false);
					return;
				}
				if (isWord) return;
				const pair = pairFor(ch);
				if (!pair) return;
				if (p.action === "s") {
					const [from, to] = this.range(b.n);
					b.gs.splice(to, 0, pair[1]);
					b.gs.splice(from, 0, pair[0]);
					return this.commit(b, from, to + 1, true);
				}
				if (p.action === "r") {
					this.pending = { kind: "matchReplace", old: ch };
					return;
				}
				// "d": delete surround
				const r = b.enclosingPair(this.head, ch, p.count);
				if (!r) return;
				const [s, e] = r;
				b.gs.splice(e, 1);
				b.gs.splice(s, 1);
				const shift = (x: number) => (x > e ? x - 2 : x > s ? x - 1 : x);
				return this.commit(b, shift(this.anchor), shift(this.head), true);
			}
			case "matchReplace": {
				const r = b.enclosingPair(this.head, p.old, 1);
				const pair = pairFor(ch);
				if (!r || !pair) return;
				b.gs[r[0]] = pair[0];
				b.gs[r[1]] = pair[1];
				return this.commit(b, this.anchor, this.head, true);
			}
		}
	}

	private cut(yank: boolean, next: Mode) {
		const b = this.buf();
		const [from, to] = this.range(b.n);
		if (to > from) {
			const removed = b.gs.splice(from, to - from);
			if (yank) this.register = removed.join("");
			this.commit(b, from, from, true);
		}
		this.setMode(next);
	}

	private mapCase(fn: (s: string) => string) {
		const b = this.buf();
		const [from, to] = this.range(b.n);
		for (let k = from; k < to; k++) b.gs[k] = fn(b.gs[k]!);
		this.commit(b, this.anchor, this.head, true);
	}

	private undoOnce() {
		const ed = this.ed;
		if (!ed.undoStack?.length) return;
		this.redoStack.push({ lines: [...ed.state.lines], cursorLine: ed.state.cursorLine, cursorCol: ed.state.cursorCol });
		ed.undo();
		this.syncFromBase(false);
	}

	private redoOnce() {
		const ed = this.ed;
		const snap = this.redoStack.pop();
		if (!snap) return;
		ed.pushUndoSnapshot();
		ed.state.lines = snap.lines;
		ed.state.cursorLine = snap.cursorLine;
		ed.state.cursorCol = snap.cursorCol;
		this.onChange?.(this.getText());
		this.syncFromBase(false);
	}

	// ── rendering ────────────────────────────────────────────────────────────

	/** Selection as logical (line, col) code-unit coordinates, end exclusive. */
	private selectionLC() {
		if (this.mode === "insert" || this.anchor === this.head) return null;
		const b = this.buf();
		const [from, to] = this.range(b.n);
		if (to <= from) return null;
		return { start: b.toLC(from), end: b.toLC(to) };
	}

	private layoutWithSelection(baseLayout: (w: number) => any[], width: number) {
		const sel = this.selectionLC();
		if (!sel) return baseLayout.call(this, width);
		const ed = this.ed;
		const state = ed.state;
		const START = this.ctx.ui.theme.getBgAnsi("selectedBg");
		const out: any[] = [];
		try {
			for (let i = 0; i < state.lines.length; i++) {
				const line: string = state.lines[i] ?? "";
				const hasCur = i === state.cursorLine;
				let chunks: any[];
				if (line === "") chunks = [{ text: "", hasCursor: hasCur, cursorPos: hasCur ? 0 : undefined }];
				else {
					// Lay out one line at a time so each chunk maps back to its logical line.
					ed.state = { lines: [line], cursorLine: hasCur ? 0 : -1, cursorCol: state.cursorCol };
					chunks = baseLayout.call(this, width);
				}
				const inSel = i >= sel.start.line && i <= sel.end.line;
				const colStart = i === sel.start.line ? sel.start.col : 0;
				const colEnd = i === sel.end.line ? sel.end.col : line.length;
				const newlineSelected = i >= sel.start.line && i < sel.end.line;
				let pos = 0;
				chunks.forEach((chunk, idx) => {
					const found = line.indexOf(chunk.text, pos);
					const cs = found < 0 ? pos : found;
					pos = cs + chunk.text.length;
					if (!inSel) return out.push(chunk);
					let text: string = chunk.text;
					let cursorPos: number | undefined = chunk.cursorPos;
					const s = clamp(colStart - cs, 0, text.length);
					const e = clamp(colEnd - cs, 0, text.length);
					if (s < e) {
						text = text.slice(0, s) + START + text.slice(s, e) + SEL_END + text.slice(e);
						if (cursorPos !== undefined) cursorPos += (cursorPos >= s ? START.length : 0) + (cursorPos >= e ? SEL_END.length : 0);
					}
					const isLast = idx === chunks.length - 1;
					const cursorAtEnd = chunk.hasCursor && chunk.cursorPos === chunk.text.length;
					if (isLast && newlineSelected && !cursorAtEnd && visibleWidth(text) < width) text += `${START} ${SEL_END}`;
					out.push({ ...chunk, text, cursorPos });
				});
			}
		} finally {
			ed.state = state;
		}
		return out;
	}

	render(width: number): string[] {
		if (this.mode !== "insert") this.syncFromBase();
		const lines = super.render(width);
		const bottom = (this.ed.renderedVisibleLineCount ?? 0) + 1;
		if (!lines[bottom]) return lines;

		const theme = this.ctx.ui.theme;
		const names = { normal: ["NOR", "accent"], insert: ["INS", "success"], select: ["SEL", "warning"] } as const;
		const [name, color] = names[this.mode];
		const keys = `${this.count ?? ""}${this.pendingLabel()}`;
		const label = `${keys ? theme.fg("muted", ` ${keys}`) : ""}${theme.fg(color, ` ${name} `)}${this.borderColor("─")}`;
		const lw = visibleWidth(label);
		if (width > lw + 2) lines[bottom] = truncateToWidth(lines[bottom]!, width - lw, "") + label;
		return lines;
	}

	private pendingLabel() {
		const p = this.pending;
		if (!p) return "";
		switch (p.kind) {
			case "find":
				return p.dir === "forward" ? (p.till ? "t" : "f") : p.till ? "T" : "F";
			case "replace":
				return "r";
			case "goto":
				return "g";
			case "match1":
				return "m";
			case "match2":
				return `m${p.action}`;
			case "matchReplace":
				return `mr${p.old}`;
		}
	}
}

export default function (pi: ExtensionAPI) {
	let enabled = true;

	const install = (ctx: ExtensionContext) => {
		if (enabled) ctx.ui.setEditorComponent((tui, theme, kb) => new HelixEditor(tui, theme, kb, ctx));
		else ctx.ui.setEditorComponent(undefined);
	};

	pi.on("session_start", (_event, ctx) => {
		if (ctx.hasUI) install(ctx);
	});

	pi.registerCommand("helix", {
		description: "Toggle Helix-style modal editing",
		handler: async (_args, ctx) => {
			enabled = !enabled;
			install(ctx);
			ctx.ui.notify(`Helix mode ${enabled ? "on" : "off"}`, "info");
		},
	});
}
