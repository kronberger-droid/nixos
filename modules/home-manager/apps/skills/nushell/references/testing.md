# Nushell testing in the nushell repo (nu_test_support)

For writing or refactoring Rust tests in `nushell/nushell`. Vendored from the
`nushell-testing` skill in Darren's skill pack (MIT, as its frontmatter
stated).


Use this guide when writing new tests or refactoring old tests in the Nushell repository. The goal is to use the modern `nu_test_support` infrastructure directly, keep tests small and explicit, and avoid subprocess-style testing unless the behavior under test truly crosses the `nu` binary boundary.

The most important rule: do not use `nu!` in new tests. Do not introduce `nu!`, `nu_with_plugins!`, `nu_with_std!`, or `nu_repl_code`. Some of these APIs may still exist for compatibility in older branches, but new and refactored tests should use `test()` and `NuTester` instead.

## Core Principles

Prefer in-process tests. `test()` returns a `NuTester` that runs Nushell code in-process against the current crate code. This is faster, more deterministic, and avoids stale `nu` binaries.

Assert values, not text rendering. If a command returns a list, record, bool, int, table, duration, or structured error, assert that structured value directly. Do not add `to json`, `to nuon`, `to text`, `str join`, or manual output collapsing just to make assertion easier.

Make required external artifacts explicit. If a test needs a compiled `nu` binary, use `#[deps(NU)]`. If it needs a plugin, use `#[deps(NU_PLUGIN_EXAMPLE)]` or the appropriate plugin dependency. Do not call `add_nu_to_path()` in new code.

Keep tests local and readable. Avoid tiny helper functions that hide the testing infra. Prefer a few explicit lines in the test body, `rstest` cases for repeated shapes, and constants only for large shared data or setup snippets.

Return `Result`. Most Nushell tests should be `fn test_name() -> Result`, where `Result` comes from `nu_test_support::prelude::*`. Let `?` propagate `TestError` from `NuTester` and assertion helpers.

Use the newest guidance over older examples. Older refactors may use `add_nu_to_path()`; newer test infra replaces that with `#[deps(NU)]`.

## Standard Imports

Most test files should start with the prelude:

```rust
use nu_test_support::prelude::*;
```

Add specific imports when needed:

```rust
use nu_protocol::Signals;
use pretty_assertions::assert_matches;
use rstest::rstest;
```

Do not import `test_value!`, `test_record!`, or `test_table!` again; those `test_*!` macros are already provided by `nu_test_support::prelude::*`.

Do not import the old macros for new tests:

```rust
// Bad
use nu_test_support::nu;
use nu_test_support::{nu, nu_repl_code};
use nu_test_support::nu_with_plugins;
```

Why: even when `nu` is still re-exported by compatibility modules or the prelude on some branches, that is not permission to use it in new tests. The direction is to remove these macros from tests.

## The Basic Shape

For a single snippet and a single expected value, chain `test().run(...).expect_value_eq(...)`:

```rust
use nu_test_support::prelude::*;

#[test]
fn can_average_range() -> Result {
    test().run("0..5 | math avg").expect_value_eq(2.5)
}
```

This is better than a `nu!` test because it compares a real `Value` converted through `IntoValue`, not collapsed stdout text.

Do not write this:

```rust
use nu_test_support::nu;

#[test]
fn can_average_range() {
    let actual = nu!("0..5 | math avg");
    assert_eq!(actual.out, "2.5");
}
```

## Multiline Code

Use a local variable named `code` only for long or multiline snippets:

```rust
use nu_test_support::prelude::*;

#[test]
fn format_filesize_respects_float_precision_for_fractional_values() -> Result {
    let code = "
        $env.config = ($env.config | upsert float_precision 5)
        1024B | format filesize kB
    ";

    test().run(code).expect_value_eq("1.02400 kB")
}
```

Guidelines for multiline snippets:

Use `let code = "..."` or `let code = r#"..."#` when the snippet is long or multiline.

For short snippets, pass a one-line string directly to `run(...)` or `run_with_data(...)`.

Keep Nushell code readable; do not compress everything into one line unless it is genuinely clearer.

If the expected output is a multiline Rust string, prefer `indoc::indoc!`.

## Working Directory

Use `cwd` on the tester when the snippet reads files relative to a fixture directory:

```rust
use nu_test_support::prelude::*;

#[test]
fn reads_cargo_sample() -> Result {
    let code = r#"
        open cargo_sample.toml
        | get package
        | format pattern "{name} has license {license}"
    "#;

    test()
        .cwd("tests/fixtures/formats")
        .run(code)
        .expect_value_eq("nu has license ISC")
}
```

`cwd` accepts repo-relative paths and sandbox paths. Prefer it over `cd` in the snippet when the test setup itself should start in a specific directory.

## Structured Values

`run` extracts the result into any type implementing `FromValue`. `expect_value_eq` accepts any type implementing `IntoValue`.

Never write `run::<T>(...)` or `run_with_data::<T>(...)`. If you extract a value, let the left-hand side define the type with `let value: T = test().run(...) ?`. If you call `expect_value_eq`, `expect_shell_error`, `expect_parse_error`, or similar, the helper already fixes the needed type.

Simple expected values should be raw Rust values when they are homogeneous or scalar:

```rust
#[test]
fn filters_ints() -> Result {
    test()
        .run("[3, 1, 2] | sort")
        .expect_value_eq([1, 2, 3])
}
```

Use `test_value!`, `test_record!`, and `test_table!` for mixed, nested, record, or table-like data. Prefer `test_value!` for nested structures instead of nesting `test_record!` inside `test_record!`:

```rust
use nu_test_support::prelude::*;

#[test]
fn insert_at_end_of_list() -> Result {
    test()
        .run("[1, 2, 3] | insert 3 abc")
        .expect_value_eq(test_value!([1, 2, 3, "abc"]))
}
```

```rust
use nu_test_support::prelude::*;

#[test]
fn inserts_into_nested_record() -> Result {
    test()
        .run("{a: {}} | insert a.b.c 0")
        .expect_value_eq(test_value!({
            a: { b: { c: 0 } }
        }))
}
```

```rust
use nu_test_support::prelude::*;

#[test]
fn insert_uses_enumerate_index() -> Result {
    let code = "
        [[a]; [7] [6]]
        | enumerate
        | insert b {|el| $el.index + 1 + $el.item.a }
        | flatten
    ";

    test().run(code).expect_value_eq(test_table![
        ["index", "a", "b"];
        [0, 7, 8],
        [1, 6, 8],
    ])
}
```

Prefer these forms over serialized output:

```rust
// Bad unless serialization itself is under test
#[test]
fn insert_at_end_of_list() -> Result {
    test()
        .run("[1, 2, 3] | insert 3 abc | to json --raw")
        .expect_value_eq(r#"[1,2,3,"abc"]"#)
}
```

```rust
// Good
#[test]
fn insert_at_end_of_list() -> Result {
    test()
        .run("[1, 2, 3] | insert 3 abc")
        .expect_value_eq(test_value!([1, 2, 3, "abc"]))
}
```

Exceptions are real rendering and serialization tests, such as `to json`, `to nuon`, `table`, or `to text`, where the string representation is the behavior under test.

## Pulling Values Into Rust

When assertions need Rust logic, extract a typed value:

```rust
#[test]
fn splits_empty_path() -> Result {
    let outcome: bool = test().cwd("tests").run("echo '' | path split | is-empty")?;
    assert!(outcome);
    Ok(())
}
```

If the test only verifies that a command succeeds and returns a value of a certain type, bind to `_`:

```rust
#[test]
fn is_terminal_accepts_stdin_flag() -> Result {
    let _: bool = test().run("is-terminal --stdin")?;
    Ok(())
}
```

If you only care that a command succeeds and returns any value:

```rust
#[test]
fn help_does_not_error() -> Result {
    let _: Value = test().run("overlay hide --help")?;
    Ok(())
}
```

If the command should return `nothing`, use `let ()` or `expect_value_eq(())`:

```rust
#[test]
fn definition_compiles() -> Result {
    let () = test().run("def helper [] { 'ok' }")?;
    Ok(())
}
```

## Passing Data Into Nushell

Use `run_with_data` when the test needs external data. This keeps the Nushell snippet stable and avoids unsafe or noisy `format!` use:

```rust
use nu_test_support::prelude::*;

#[test]
fn reads_input_record() -> Result {
    let input = test_record! {
        "name" => "nu",
        "license" => "MIT",
    };

    test()
        .run_with_data("$in | format pattern '{name} has license {license}'", input)
        .expect_value_eq("nu has license MIT")
}
```

Prefer this over injecting values into source with `format!`:

```rust
// Bad when only the value changes
#[test]
fn uppercases_name() -> Result {
    let name = "nu";
    test()
        .run(format!("'{name}' | str upcase"))
        .expect_value_eq("NU")
}
```

```rust
// Good
#[test]
fn uppercases_name() -> Result {
    let name = "nu";
    test()
        .run_with_data("$in | str upcase", name)
        .expect_value_eq("NU")
}
```

`format!` is fine when you are intentionally generating Nushell syntax, such as an option flag or a large code fixture, and the generated code remains obvious.

## Multiple Snippets And Shared State

Use one mutable `NuTester` when later snippets depend on definitions, environment changes, overlays, or variables from earlier snippets:

```rust
#[test]
fn use_main_def_env() -> Result {
    let mut tester = test();

    let () = tester.run(r#"module spam { export def --env main [] { $env.SPAM = "spam" } }"#)?;
    let () = tester.run("use spam")?;
    let () = tester.run("spam")?;

    tester.run("$env.SPAM").expect_value_eq("spam")
}
```

Use `run_multiple` when the test intentionally needs to run several pipelines after each other on the same tester and only the final value matters:

```rust
#[test]
fn new_overlay_from_const_name() -> Result {
    let commands = [
        "const mod = 'spam'",
        "overlay new $mod",
        "overlay list | last | get name",
    ];

    test().run_multiple(commands).expect_value_eq("spam")
}
```

Prefer explicit repeated `run` calls when intermediate results matter, when some steps are setup with `nothing` output, or when the source-unit boundaries are important for understanding the test:

```rust
#[test]
fn use_main_def_env() -> Result {
    let mut tester = test();
    let () = tester.run(r#"module spam { export def --env main [] { $env.SPAM = "spam" } }"#)?;
    let () = tester.run("use spam")?;
    let () = tester.run("spam")?;
    tester.run("$env.SPAM").expect_value_eq("spam")
}
```

Do not use `nu_repl_code`. If the test wants REPL-like separate source units, use `run_multiple` for a simple sequence where only the final value matters, or repeated `tester.run(...)` calls when intermediate steps matter.

Be deliberate about source-unit boundaries:

If behavior must occur in one parse/source unit, put it in one `code` block and run once.

If behavior must persist across source units, use repeated `run` calls on one mutable tester.

If scenarios are independent, use separate `test()` calls or `rstest` cases.

Example of independent scenarios using fresh testers:

```rust
#[test]
fn module_main_not_found() -> Result {
    let mut tester = test();
    let () = tester.run("module spam {}")?;
    tester
        .run("use spam main")
        .expect_error_code_eq("nu::parser::export_not_found")?;

    let mut tester = test();
    let () = tester.run("module spam {}")?;
    tester
        .run("use spam [ main ]")
        .expect_error_code_eq("nu::parser::export_not_found")
}
```

## Playground

Use an injected `Playground` argument when the test needs a sandboxed filesystem:

```rust
use nu_test_support::prelude::*;

#[test]
fn rm_deletes_file(playground: Playground) -> Result {
    playground.empty_file("delete-me.txt")?;

    test()
        .cwd(playground.path())
        .run("rm delete-me.txt; 'delete-me.txt' | path exists")
        .expect_value_eq(false)
}
```

Rules for playground tests:

Use `fn test_name(playground: Playground) -> Result` when a test needs sandboxed files. The test harness creates and cleans up the directory.

Use `test().cwd(playground.path())` when the snippet should run in the sandbox.

Use the `PlaygroundFs` methods from the prelude for setup:

```rust
#[test]
fn creates_nested_files(playground: Playground) -> Result {
    playground.dir("logs/archive")?;
    playground.empty_file("logs/archive/empty.log")?;
    playground.file("input.txt", "hello")?;
    playground.readonly_file("readonly.txt", "contents")?;

    Ok(())
}
```

Use `playground.at(...)` only when setting up multiple files or directories under the same parent. For a single file or directory, include the parent path directly in `playground.file(...)`, `playground.empty_file(...)`, or `playground.dir(...)`.

For example, do not use `at` for one file:

```rust
playground.file("originals/spam.txt", "spam")?;
```

Use `at` when several setup calls share that parent:

```rust
#[test]
fn copies_nested_files(playground: Playground) -> Result {
    playground.at("originals", |originals| {
        originals.file("spam.txt", "spam")?;
        originals.file("eggs.txt", "eggs")?;
        originals.empty_file("empty.txt")?;
        originals.at("contributors", |contributors| {
            contributors.file("alice.txt", "Alice")?;
            contributors.file("bob.txt", "Bob")?;
            Ok(())
        })
    })?;

    test()
        .cwd(playground.path())
        .run("cp -r originals copies; ['copies/spam.txt' 'copies/contributors/alice.txt'] | path exists | all { $in }")
        .expect_value_eq(true)
}
```

Use `indoc::indoc!` for indented file contents:

```rust
#[test]
fn opens_indented_fixture(playground: Playground) -> Result {
    playground.file(
        "sample.toml",
        indoc::indoc! {r#"
            [package]
            name = "nu"
            license = "MIT"
        "#},
    )?;

    test()
        .cwd(playground.path())
        .run("open sample.toml | get package.name")
        .expect_value_eq("nu")
}
```

Use `playground.symlink(original, link)?` for symlinks inside the sandbox. Both paths are playground-relative. On Windows, the original must exist so the helper can choose file or directory symlink behavior.

When the Rust side needs to read a file, do not use `file_contents(path)`. Use `std::fs::read_to_string(path)?` or `fs::read_to_string(path)?` if `std::fs` is imported. `io::Error` converts into `TestError`, so this works naturally in tests that return `Result`:

```rust
use std::fs;
use nu_test_support::prelude::*;

#[test]
fn writes_expected_file(playground: Playground) -> Result {
    playground.file("input.txt", "hello")?;

    let () = test()
        .cwd(playground.path())
        .run("open input.txt | str upcase | save output.txt")?;

    let contents = fs::read_to_string(playground.path().join("output.txt"))?;
    assert_eq!(contents, "HELLO");
    Ok(())
}
```

Do not request a `playground: Playground` argument when no filesystem behavior is being tested.

Do not call `Playground::setup` or `Playground::new` in ordinary tests. `Playground::new` is for playground internals and generated harness code.

Do not import `nu_test_support::fs::Stub` or call `sandbox.with_files`. Use `playground.file`, `playground.empty_file`, `playground.dir`, `playground.readonly_file`, `playground.symlink`, and `playground.at` instead.

Do not write this old shape:

```rust
// Bad
use nu_test_support::{fs::Stub::EmptyFile, prelude::*};

#[test]
fn bad_playground_shape() -> Result {
    Playground::setup("case", |dirs, sandbox| {
        sandbox.with_files(&[EmptyFile("x")]);
        test().cwd(dirs.test()).run("ls")?;
        Ok(())
    })
}
```

Write this instead:

```rust
#[test]
fn good_playground_shape(playground: Playground) -> Result {
    playground.empty_file("x")?;
    let _: Value = test().cwd(playground.path()).run("ls")?;
    Ok(())
}
```

## Parameterized Tests With rstest

Use `rstest` when several tests have the same shape and only data changes:

```rust
use nu_test_support::prelude::*;
use rstest::rstest;

#[rstest]
#[case::null("null", ())]
#[case::true_("true", true)]
#[case::false_("false", false)]
fn top_level_values_from_json(#[case] json: &str, #[case] expected: impl IntoValue) -> Result {
    test()
        .run_with_data("from json", json)
        .expect_value_eq(expected)
}
```

This is better than a loop inside one test because every case is reported independently.

When combining `rstest` with `#[deps]`, `#[env]`, `#[exp]`, `#[serial]`, or other harness attributes, explicitly use the harness test macro:

```rust
use nu_test_support::prelude::*;
use rstest::rstest;

#[rstest]
#[case::child_lib_dirs("$env.NU_LIB_DIRS | describe", "list<string>")]
#[case::child_plugin_dirs("$NU_PLUGIN_DIRS | describe", "list<string>")]
#[nu_test_support::test]
#[deps(NU)]
fn child_process_defaults(#[case] child_code: &str, #[case] expected: impl IntoValue) -> Result {
    test()
        .run_with_data("let child_code; nu -n -c $child_code", child_code)
        .expect_value_eq(expected)
}
```

For per-case dependencies, follow nearby repository style and place the dependency attribute next to the case it belongs to.

When combining `rstest` cases with a playground, mark the `Playground` argument with `#[ignore]` so `rstest` leaves it for the Nushell test harness to inject:

```rust
use nu_test_support::prelude::*;
use rstest::rstest;

#[rstest]
#[case::a("a")]
#[case::b("b")]
fn cased_playground(#[case] value: &str, #[ignore] playground: Playground) -> Result {
    playground.file("input.txt", value)?;

    test()
        .cwd(playground.path())
        .run("open input.txt")
        .expect_value_eq(value)
}
```

## Errors

Prefer structured error assertions.

If the exact error code is enough, use `expect_error_code_eq`:

```rust
#[test]
fn insert_past_end_of_list() -> Result {
    test()
        .run("[1, 2, 3] | insert 5 abc")
        .expect_error_code_eq("nu::shell::access_beyond_end")
}
```

If the variant or fields matter, extract the error and match it:

```rust
use nu_test_support::prelude::*;
use pretty_assertions::assert_matches;

#[test]
fn insert_nested_path_into_empty_list_errors_without_underflow() -> Result {
    let err = test().run("[] | insert 0.0 1").expect_shell_error()?;
    assert_matches!(err, ShellError::AccessEmptyContent { .. });
    Ok(())
}
```

Parse and compile errors have dedicated helpers:

```rust
use nu_protocol::Type;
use nu_test_support::prelude::*;
use pretty_assertions::assert_matches;

#[test]
fn parse_function_signature_switch_is_bool() -> Result {
    let err = test()
        .run("def foo [--bar] { let baz: int = $bar }")
        .expect_parse_error()?;

    assert_matches!(err, ParseError::TypeMismatch(Type::Int, Type::Bool, _));
    Ok(())
}
```

Use `ShellErrorExt` for generic or labeled errors when needed:

```rust
#[test]
fn glob_without_match_reports_missing_file() -> Result {
    let err = test().run("ls root3*").expect_shell_error()?;
    let msg = err.generic_msg()?;
    assert_contains("file or folder not found", msg);
    Ok(())
}
```

Avoid this old style:

```rust
// Bad
#[test]
fn insert_past_end_of_list() {
    let actual = nu!("[1, 2, 3] | insert 5 abc");
    assert!(actual.err.contains("too large"));
}
```

## Assertions

Use `expect_value_eq` for Nushell values.

Use `assert_contains(needle, haystack)` for positive contains checks.

Use `pretty_assertions::assert_eq` or `pretty_assertions::assert_str_eq` for large Rust-side values or rendered strings when it improves diffs.

Use `assert_matches!` for error variants and enum shapes.

Avoid `assert!(haystack.contains(needle))`; it gives weaker diagnostics than `assert_contains`.

Avoid `assert_eq!(actual.out, ...)` because new tests should not produce `actual.out` in the first place.

Use `assert_contains_not(needle, haystack)` for negative containment checks. Prefer it over hand-written `assert!(!haystack.contains(needle))` because it matches the positive `assert_contains` style and gives a consistent failure message:

```rust
#[test]
fn overlay_list_does_not_contain_hidden_overlay() -> Result {
    let names: String = test().run("overlay list | get name | str join ' '")?;
    assert_contains_not("spam", names);
    Ok(())
}
```

## Binaries, Child Nushell, And CompleteResult

Most tests should not spawn the `nu` binary. Spawn it only when testing behavior that exists at the process boundary, such as CLI flags, script-file execution, process exit behavior, or child process environment defaults.

When spawning `nu`, declare `#[deps(NU)]`:

```rust
use nu_test_support::prelude::*;

#[test]
#[deps(NU)]
fn source_file_relative_to_file() -> Result {
    let result: CompleteResult = test()
        .cwd("tests/parsing/samples")
        .run("nu -n source_file_relative.nu | complete")?;

    assert_eq!(result.exit_code, 0);
    assert_eq!(result.stdout.trim(), "5");
    assert_eq!(result.stderr, "");
    Ok(())
}
```

Use `CompleteResult` for `complete` output instead of indexing a record:

```rust
#[test]
#[deps(NU)]
fn child_nu_reports_missing_script() -> Result {
    let result: CompleteResult = test().run("nu -n missing-script.nu | complete")?;

    assert_ne!(result.exit_code, 0);
    assert_contains("file_not_found", result.stderr);
    Ok(())
}
```

Do not use `add_nu_to_path()` in new tests:

```rust
// Bad
#[test]
fn child_version() -> Result {
    test()
        .add_nu_to_path()
        .run("nu -n -c 'version | get version'")
        .expect_value_eq(env!("CARGO_PKG_VERSION"))
}
```

```rust
// Good
#[test]
#[deps(NU)]
fn child_version() -> Result {
    test()
        .run("nu -n -c 'version | get version'")
        .expect_value_eq(env!("CARGO_PKG_VERSION"))
}
```

Do not call test binaries through `nu --testbin ...`. That route is deprecated for tests. Declare the testbin dependency and call the binary directly:

```rust
// Bad
#[test]
#[deps(NU)]
fn bad_testbin_call() -> Result {
    test()
        .run("nu --testbin cococo a b c")
        .expect_value_eq("a b c")
}
```

```rust
// Good
#[test]
#[deps(TESTBIN_COCOCO)]
fn calls_testbin_directly() -> Result {
    test()
        .run("cococo a b c")
        .expect_value_eq("a b c")
}
```

Use the appropriate `TESTBIN_*` constant from the prelude, such as `TESTBIN_COCOCO`, `TESTBIN_MEOW`, or `TESTBIN_REPEATER`. Add `NU` only if the behavior under test specifically requires a child Nushell process in addition to the testbin.

## Plugins

Plugin tests should not use `nu_with_plugins!`. Declare plugin dependencies with `#[deps]` and call plugin commands directly in-process:

```rust
use nu_test_support::prelude::*;

#[test]
#[deps(NU_PLUGIN_EXAMPLE)]
fn call_to_json() -> Result {
    test()
        .run("[42] | example call-decl 'to json' {indent: 4}")
        .expect_value_eq("[\n    42\n]")
}
```

```rust
use nu_test_support::prelude::*;

#[test]
#[deps(NU_PLUGIN_EXAMPLE)]
fn plugin_receives_config() -> Result {
    let code = r#"
        $env.config = {
            plugins: {
                example: {
                    path: "some/path"
                    nested: { bool: true, string: "Hello Example!" }
                }
            }
        }
        example config
    "#;

    test().run(code).expect_value_eq(test_value!({
        path: "some/path",
        nested: {
            bool: true,
            string: "Hello Example!"
        }
    }))
}
```

If a plugin test specifically needs an actual child `nu` process plus a plugin path, declare both dependencies and pass the plugin path as data:

```rust
#[test]
#[deps(NU, NU_PLUGIN_INC)]
fn plugin_process_exits_when_nushell_exits() -> Result {
    let pid: u32 = test().run_with_data(
        r#"nu -n --plugins $in -c "'2.0.0' | inc -m; (plugin list).0.pid" | into int"#,
        NU_PLUGIN_INC.path(),
    )?;

    let mut tester = test();
    let () = tester.run("sleep 500ms")?;
    let () = tester.run_with_data("let pid = $in", pid)?;
    tester
        .run("ps | where pid == $pid | is-empty")
        .expect_value_eq(true)
}
```

Use `#[serial]` for plugin tests that check process identity, start/stop timing, or shared process state. Do not mark all plugin tests serial by default.

## External Commands And PATH

By default, `NuTester` keeps `$env.PATH` unset or minimal for deterministic tests.

Use `#[deps(NU)]` for the Nushell binary.

Use plugin dependencies for plugins.

Use `#[deps(TESTBIN_X)]` for test binaries and invoke them directly by name. Do not route testbins through `nu --testbin`.

Use `inherit_path()` only when the test intentionally relies on arbitrary system commands.

Use `inherit_rust_toolchain_env()` for tests that intentionally spawn `cargo`, `rustc`, or `rustup`.

Example:

```rust
#[test]
fn cargo_is_available_when_inheriting_rust_toolchain_env() -> Result {
    test()
        .inherit_rust_toolchain_env()
        .run("cargo --version | split row ' ' | get 0")
        .expect_value_eq("cargo")
}
```

Do not use `inherit_path()` as a workaround for missing `#[deps]`.

## Harness Attributes

The custom harness supports attributes on tests:

`#[serial]` runs tests sequentially. Use it for process-wide state, heavy IO contention, plugin PID lifecycle tests, or other unavoidable shared-state cases. Do not use global locks instead.

`#[env(KEY = "value")]` sets process environment variables for a test group. Use this when engine setup or harness grouping depends on an environment variable.

`#[exp(OPTION)]` enables an experimental option. Use it instead of setting experimental options manually in a `nu!` call.

`#[deps(...)]` declares binaries or plugins that must be built and made available to `test()`.

Example:

```rust
use nu_experimental::REORDER_CELL_PATHS;
use nu_test_support::prelude::*;

#[test]
#[exp(REORDER_CELL_PATHS)]
fn update_table_cell_respects_reorder_option() -> Result {
    let code = "
        let a = [[foo]; [bar]]
        let b = ($a | update foo.0 'baz')
        $b.0.foo
    ";

    test().run(code).expect_value_eq("baz")
}
```

For locale-sensitive tests, use `#[env(NU_TEST_LOCALE_OVERRIDE = "en_US.UTF-8")]` when the locale must affect harness/engine setup, or `test().locale_en()` when configuring only the tester is enough.

## Table And Rendering Tests

For commands whose output is intentionally a string rendering, assert the string directly. Use `indoc!` to keep expected output readable.

```rust
use indoc::indoc;
use nu_test_support::prelude::*;

#[test]
fn table_padding_zero() -> Result {
    test()
        .run_with_data(
            "
                let data = $in
                $env.config.table.padding = {left: 0, right: 0}
                $data | table --width=80
            ",
            test_table![
                ["a", "b", "c"];
                [1, 2, 3],
                [4, 5, [1, 2, 3]],
            ],
        )
        .expect_value_eq(indoc! {"
            ╭─┬─┬─┬──────────────╮
            │#│a│b│      c       │
            ├─┼─┼─┼──────────────┤
            │0│1│2│             3│
            │1│4│5│[list 3 items]│
            ╰─┴─┴─┴──────────────╯
        "})
}
```

Notes for rendering tests:

Use `run_with_data` for complex input so the test focuses on rendering.

Use `ansi strip` when colors are not the behavior under test.

When colors are the behavior under test, assert the ANSI string explicitly.

Use `pretty_assertions::assert_str_eq!` when comparing large rendered strings extracted as `String`.

## Refactoring Old nu! Tests

Use this checklist when converting old tests.

1. Remove `use nu_test_support::nu`, `nu_with_plugins`, and `nu_repl_code` imports.
2. Add `use nu_test_support::prelude::*;` and only specific extra imports that are needed.
3. Change `fn test_name()` to `fn test_name() -> Result`.
4. Replace `let actual = nu!(...)` with `test().run(...)`, `test().cwd(...).run(...)`, or `let mut tester = test(); tester.run(...)`.
5. Replace `assert_eq!(actual.out, "...")` with `.expect_value_eq(...)` or typed extraction.
6. Replace `assert!(actual.err.contains(...))` with `.expect_error_code_eq(...)`, `.expect_shell_error()?`, `.expect_parse_error()?`, or `.expect_compile_error()?`.
7. Replace plugin macro usage with `#[deps(NU_PLUGIN_...)]` and direct plugin commands.
8. Replace `add_nu_to_path()` with `#[deps(NU)]`.
9. Replace `nu --testbin name ...` with `#[deps(TESTBIN_NAME)]` and direct `name ...` calls.
10. Replace `nu_repl_code` with `run_multiple` or a mutable `NuTester` and repeated `run` calls, depending on which is clearer.
11. Replace serialization-only assertions with structured values unless serialization is the feature under test.
12. Replace `Playground::setup` with a `playground: Playground` test argument, `playground.path()`, and the `PlaygroundFs` setup methods.
13. Replace `nu_test_support::fs::Stub` and `sandbox.with_files` with `playground.file`, `playground.empty_file`, `playground.dir`, `playground.readonly_file`, `playground.symlink`, or `playground.at`.
14. Use `rstest` when the refactor exposes several same-shaped tests.
15. Keep the test body explicit rather than moving a small sequence into a helper.

Example refactor:

```rust
// Old
use nu_test_support::nu;

#[test]
fn insert_into_list() {
    let actual = nu!("[1, 2, 3] | insert 1 abc | to json -r");
    assert_eq!(actual.out, r#"[1,"abc",2,3]"#);
}
```

```rust
// New
use nu_test_support::prelude::*;

#[test]
fn insert_into_list() -> Result {
    test()
        .run("[1, 2, 3] | insert 1 abc")
        .expect_value_eq(test_value!([1, "abc", 2, 3]))
}
```

Error refactor:

```rust
// Old
#[test]
fn list_unknown_long_flag() {
    let actual = nu!("ls --full-path");
    assert!(actual.err.contains("Did you mean: `--full-paths`?"));
}
```

```rust
// New
use nu_protocol::ParseError;
use nu_test_support::prelude::*;
use pretty_assertions::assert_matches;

#[test]
fn list_unknown_long_flag() -> Result {
    let err = test().run("ls --full-path").expect_parse_error()?;
    assert_matches!(
        err,
        ParseError::UnknownFlag(_, _, _, help) if help == "Did you mean: `--full-paths`?"
    );
    Ok(())
}
```

Plugin refactor:

```rust
// Old
#[test]
fn call_reduce() {
    let result = nu_with_plugins!(
        cwd: ".",
        plugin: ("nu_plugin_example"),
        "[1 2 3] | example call-decl 'reduce' {fold: 10} { |it, acc| $it + $acc }"
    );
    assert_eq!("16", result.out);
}
```

```rust
// New
#[test]
#[deps(NU_PLUGIN_EXAMPLE)]
fn call_reduce() -> Result {
    test()
        .run("[1 2 3] | example call-decl 'reduce' {fold: 10} {|it, acc| $it + $acc}")
        .expect_value_eq(16)
}
```

Multiple source-unit refactor:

```rust
// Acceptable when only the final value matters
#[test]
fn new_overlay_from_const_name() -> Result {
    let commands = [
        "const mod = 'spam'",
        "overlay new $mod",
        "overlay list | last | get name",
    ];

    test().run_multiple(commands).expect_value_eq("spam")
}
```

```rust
// Prefer this when intermediate steps or assertions matter
#[test]
fn new_overlay_from_const_name() -> Result {
    let mut tester = test();
    let () = tester.run("const mod = 'spam'")?;
    let () = tester.run("overlay new $mod")?;
    tester.run("overlay list | last | get name").expect_value_eq("spam")
}
```

## Do Not Use

Do not use `nu!` for new tests.

Do not use `nu_with_plugins!`.

Do not use `nu_repl_code`.

Do not use `add_nu_to_path()`.

Do not call testbins via `nu --testbin`; use `#[deps(TESTBIN_...)]` and call them directly.

Do not assert `actual.out`, `actual.err`, or `actual.status` from `nu!` output.

Do not write `run::<T>(...)` or `run_with_data::<T>(...)`; annotate the left-hand binding or use the expectation helpers.

Do not depend on `NU` just because a test used to spawn `nu`; first ask whether the behavior can be tested in-process.

Do not depend on a plugin or binary without `#[deps(...)]`.

Do not serialize values to JSON, NUON, markdown, text, or joined strings only to assert them.

Do not request a `playground: Playground` argument when no filesystem behavior is needed.

Do not use `Playground::setup` in ordinary tests; use an injected `playground: Playground` argument instead.

Do not call `Playground::new` directly except when testing playground internals.

Do not use `nu_test_support::fs::Stub`, `sandbox.with_files`, `dirs.test()`, or `dirs.root()` in new playground tests.

Do not use `file_contents(path)`; use `std::fs::read_to_string(path)?` instead.

Do not emulate serialization or isolation with global mutexes; use `#[serial]` when serial execution is truly required.

Do not create helper functions just to wrap `test().run` or hide a small command sequence.

Do not manually set process environment with `std::env::set_var`; use `#[env]` or `test().env(...)`.

Do not manually enable experimental options in the snippet or old macro options; use `#[exp]`.

Do not import `test_value`, `test_record`, or `test_table` from `nu_protocol` when `nu_test_support::prelude::*` is already imported; the prelude provides the `test_*!` macros.

## Quick Decision Table

Use `test().run(code).expect_value_eq(expected)` for one snippet and one expected value.

Use `let mut tester = test(); tester.run(...)` for shared state across source units.

Use `test().run_multiple(commands)` for a simple sequence of pipelines where only the last output is asserted.

Use one multiline `code` block for behavior that must parse or execute in one source unit.

Use `run_with_data` when external Rust data is the input.

Use a `playground: Playground` test argument plus `.cwd(playground.path())` for sandboxed files.

Use `rstest` for same-shaped cases.

Use `expect_error_code_eq` when the code is the contract.

Use `expect_shell_error`, `expect_parse_error`, or `expect_compile_error` when the error shape matters.

Use `#[deps(NU)]` plus `CompleteResult` when testing a child `nu` process.

Use `#[deps(TESTBIN_...)]` when testing commands that need a testbin, then call the testbin directly.

Use `#[deps(NU_PLUGIN_...)]` when testing plugin commands in-process.

Use `#[serial]` only for unavoidable shared state, timing-sensitive process lifecycle, or heavy IO conflicts.

Above all, keep the test explicit, type-aware, and free of `nu!`.