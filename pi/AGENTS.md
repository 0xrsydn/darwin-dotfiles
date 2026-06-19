# Global Pi Instructions

## Version Control

Prefer Jujutsu (`jj`) over Git for source-control operations.

- Use `jj status` instead of `git status`.
- Use `jj diff` instead of `git diff`.
- Use `jj log` instead of `git log`.
- Use `jj describe` for change descriptions.
- Use `jj new`, `jj split`, and `jj squash` for change management.
- Avoid `git add`, `git commit`, and direct index/staging workflows unless explicitly requested.
- Git commands are acceptable only for operations that `jj` cannot perform or when the user asks for Git specifically.
- When reporting changes, mention the active `jj` change/workspace state rather than Git staging state.
