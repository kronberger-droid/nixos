---
name: rust-to-cpp
description: Convert Rust code to idiomatic C++ for numerical methods coursework.
when_to_use: When the user wants to convert Rust code to C++, or asks to translate Rust to C++ for their numerical methods class.
argument-hint: <rust-file> [exercise-pdf]
user-invocable: true
allowed-tools: Read Write Edit Grep Glob mcp__inpdf__pdf_read_pages mcp__inpdf__pdf_info mcp__inpdf__pdf_toc mcp__inpdf__pdf_grep
---

# Rust to C++ Converter

Convert the Rust code in `$0` to idiomatic, modern C++ (C++20 or later).

## Read the source first

Read the Rust file at `$0`. If no argument is given, ask the user which file to convert.

## Exercise sheet (optional)

If a second argument `$1` is provided, it is a path to a PDF exercise sheet.
- Use `pdf_info` and `pdf_read_pages` to read the exercise sheet
- Match the C++ output to any requirements specified in the exercise (function signatures, input/output format, naming conventions, specific algorithms requested)
- Add a comment at the top referencing which exercise this solves: `// Exercise N — <title>`
- If the exercise specifies particular I/O behavior (stdin/stdout format, file I/O), implement that exactly

## Translation rules

### General
- Output a single `.cpp` file (with `#include` headers inline) unless the user asks for header separation
- Use `auto` where type inference is obvious, explicit types otherwise
- Prefer value semantics; use `std::unique_ptr` only where Rust uses `Box`
- Translate `Result<T, E>` to exceptions or `std::expected<T, E>` (C++23) — prefer exceptions for simplicity in coursework
- Translate `Option<T>` to `std::optional<T>`

### Numerical methods specifics
- `f64` → `double`, `f32` → `float`
- `Vec<f64>` → `std::vector<double>`
- `ndarray` / `nalgebra` types → `std::vector<std::vector<double>>` for matrices (keep it simple, no Eigen dependency unless asked)
- Rust iterators with `.map()`, `.sum()`, `.fold()` → range-based for loops or `std::transform` / `std::accumulate`
- `(0..n).map(|i| ...)` → simple for loop
- Preserve all mathematical comments and variable names exactly

### Ownership & borrowing
- `&[f64]` → `std::span<const double>` or `const std::vector<double>&`
- `&mut [f64]` → `std::span<double>` or `std::vector<double>&`
- Owned `Vec<T>` parameters → `std::vector<T>` by value (let move semantics handle it)
- `clone()` → just copy (C++ copies by default)

### Control flow
- `match` → `switch` for enums, `if/else if` chains for pattern matching
- `if let Some(x) = ...` → `if (auto x = ...; x.has_value())`
- `for x in iter` → range-based `for`
- `loop { ... break val; }` → `while (true) { ... }` with result variable

### Error handling
- `unwrap()` / `expect()` → direct use (or `assert()` for preconditions)
- `?` operator → just let exceptions propagate
- `panic!()` → `throw std::runtime_error(...)`

### Printing
- `println!("{}", x)` → `std::println("{}", x)` (C++23) or `std::cout << x << '\n'`
- `format!()` → `std::format()`

### Standard library mappings
- `HashMap` → `std::unordered_map`
- `BTreeMap` → `std::map`
- `String` → `std::string`
- `&str` → `std::string_view`
- `Arc<T>` → `std::shared_ptr<T>`
- `Mutex<T>` → `std::mutex` + separate `T`

## Output

1. Write the converted C++ file next to the original with a `.cpp` extension
2. Add a brief comment at the top: `// Converted from <original-filename>`
3. Include a `main()` if the Rust source has one
4. Show a short summary of any non-trivial translation decisions you made
