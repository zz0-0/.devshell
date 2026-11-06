# Maintaining the devshell library

This repo is a **flake library**, not an application. Consumers import it as
`github:zz0-0/devshell` and get `lib.<system>.<lang>` plus `templates/`.

## The loop

1. **Edit** — a shell in `languages/`, a template in `templates/`, or the README.
2. **Check** — all of these must pass before a commit:

   ```bash
   nix flake check
   statix check .
   deadnix --fail .
   nixfmt --check $(git ls-files "*.nix")
   ```

3. **Smoke-test the template you touched**:

   ```bash
   cd "$(mktemp -d)" && nix flake init -t github:zz0-0/devshell#python && direnv allow
   ```

4. **Commit and push.** Consumers read the pushed commit, not this working copy.
   An unpushed change does not exist for any project.

## Adding a language

`languages/<lang>.nix` → export it from `flake.nix` → `templates/<lang>/` →
add the row to the README table. Follow the shape of the existing files.

## What not to do

- Do not bake a local path into a template (`path:$HOME/.devshell`). Projects must
  resolve the GitHub flake; a local path breaks CI and every other machine.
- Do not commit generated artifacts (`.venv/`, `.dart_tool/`, `result`).
- Do not bump the input pin in consumer projects from here — they own their lock.
