# Copilot Project Rules

## 1. Documentation
- Always update README.md with the current project structure and newly added scripts.
- Document every user-facing file and directory in README.md, omitting internal directories like `.copilot`, `.Test`, `.git`, `.github`, and `.vscode`.
- Mention in README.md that AI/KI tooling was used to support the creation of this module.
- Do not insert line breaks in the middle of a sentence in README.md, regular comments, or comment-based help blocks. Start a new line only between complete sentences or list items.
- Every change to documentation and code must have clear commit messages.
- After code changes, verify that all examples, file structures, and guidelines are accurate.

## 2. Comment-Based Help & Comments
- Place exactly one comment-based help block (`<# ... #>`) at the top (beginning) of each `.ps1` or `.psm1` file, before any executable code and function definitions.
- Comment-based help blocks are strictly forbidden inside function bodies or before individual functions.
- All other comments in any file must be regular single-line comments starting with `#`.
- Every function must be human-readably commented with a concise regular comment (`#`) placed immediately before the function definition, explaining its purpose and observable behavior.
- Do not break a sentence across lines in regular comments or comment-based help blocks.
- The module manifest (`.psd1`) is the single source of truth for module versioning; do not duplicate module version metadata inside comment-based help blocks.

## 3. PowerShell & Microsoft Best Practices (PowerShell 5.1)
- The project must strictly maintain compatibility with Windows PowerShell 5.1.
- Do not use PowerShell 7+ syntax, features, or APIs that are unavailable in Windows PowerShell 5.1.
- Follow Microsoft and PowerShell best practices for module authoring and scripting.
- Use approved Verb-Noun command names (verified via `Get-Verb`).
- Use explicit parameter definitions, pipeline-friendly output, and predictable error handling.
- Use `Set-StrictMode -Version Latest` at script/module scope.
- Use `[CmdletBinding()]` for advanced functions, including `SupportsShouldProcess` for state-changing or destructive actions.
- Avoid aliases, global state, wildcard exports, and unnecessary side effects.
- Explicitly define `VariablesToExport = @()`, `CmdletsToExport = @()`, `AliasesToExport = @()`, and `FunctionsToExport` in the module manifest (`.psd1`).
- All code, comments, help blocks, and console output messages must be written in English.
- Error handling is mandatory: use terminating errors (`ErrorAction Stop`), focused try/catch blocks, and `Write-Verbose` for intentional fallback/recovery diagnostics.
- Store standalone installer scripts at the project root.

## 4. Project Rules & Memory File Constraints
- Project rules must strictly be stored in `.copilot/project-rules.md`.
- Project memory must strictly be stored in `.copilot/repo-memory.md`.
- All other paths or files for project rules and repository memory are not allowed.

## 5. Coding Standards & Performance
- Use descriptive, consistent variable and parameter names (no abbreviations except loop counters).
- Functions should have a single responsibility, ideally no more than 3 parameters, and clear action-oriented names.
- Validate inputs at boundaries and return early to reduce nesting.
- Optimize only after measurement; never sacrifice readability for performance.

## 6. Security
- Never trust external or user input; always validate at boundaries.
- Never store secrets or sensitive credentials in source code.
