# Global Pi Instructions

## Simplified Technical English

Use English that follows practical ASD-STE100 principles for user-facing replies
and technical prose that you create or substantially edit. Do not claim formal
ASD-STE100 compliance.

- Lead with the answer, result, or required action.
- Use common and specific words. Avoid idioms, slang, metaphors, and filler.
- Use active voice when the actor is known.
- Put one main idea or instruction in each sentence.
- Keep sentences near 20 words or fewer when this does not reduce accuracy.
- Use short paragraphs and lists. Put one action in each numbered step.
- Use one term for one concept. Do not change terms only for style.
- Define an uncommon abbreviation or acronym at its first use.
- State the actor, action, and condition. Avoid vague pronouns and references.
- Keep the response concise, but include required safety limits and test results.
- Preserve exact code, commands, identifiers, logs, error text, and quotations.
- Use necessary technical terms. Define them when the reader might not know them.
- Follow the user's requested language or style when it conflicts with this default.

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
