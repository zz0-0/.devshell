{ pkgs }:

let
  # Write a JSON file, but only touch the file when its content changed
  # (avoids dirtying the working tree on every shell entry).
  writeJson = file: json: ''
    mkdir -p "$(dirname ${file})"
    if [ ! -f ${file} ] || [ "$(cat ${file} 2>/dev/null)" != '${json}' ]; then
      echo '${json}' > ${file}
    fi
  '';

  # Same as writeJson, but the content is a bash variable reference
  # (e.g. varRef = "$zed_settings") resolved at runtime.
  writeJsonFromVar = file: varRef: ''
    mkdir -p "$(dirname ${file})"
    if [ ! -f ${file} ] || [ "$(cat ${file} 2>/dev/null)" != "${varRef}" ]; then
      echo "${varRef}" > ${file}
    fi
  '';
in
{
  # Wrapper around pkgs.mkShell that adds shared dependencies (jq) and the
  # Zed settings merge, so combined shells stay consistent.
  mkShell =
    { buildInputs, shellHook, ... }@args:
    pkgs.mkShell (args // { buildInputs = buildInputs ++ [ pkgs.jq ]; });

  # Generate a direnv-based LSP wrapper script into .zed/lsp/<name>.
  # The wrapper resolves the project root from its own location and runs the
  # command inside the project's direnv environment, so the exact toolchain
  # from this devshell is used regardless of how the editor was launched.
  writeLspWrapper =
    { name, command }:
    let
      script = ''
        #!/usr/bin/env bash
        set -euo pipefail
        SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
        PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
        export PROJECT_DIR
        exec direnv exec "$PROJECT_DIR" bash -c 'exec ${command} "$@"' bash "$@"
      '';
    in
    ''
      mkdir -p .zed/lsp
      cat > .zed/lsp/${name} << 'LSP_WRAPPER'
      ${script}
      LSP_WRAPPER
      chmod +x .zed/lsp/${name}
    '';

  # VS Code settings are written verbatim (no placeholders).
  writeVscodeSettings = settingsJson: writeJson ".vscode/settings.json" settingsJson;

  # Zed settings are written per-language as fragments; the merge step
  # combines all fragments so multiple shells can coexist in one project.
  writeZedFragment = name: fragmentJson: ''
    mkdir -p .zed/lsp-config
    echo '${fragmentJson}' > .zed/lsp-config/${name}.json
  '';

  # Merge all Zed fragments (deep-merged via jq) into .zed/settings.json.
  # Must run after every fragment write.
  mergeZedSettings = ''
    zed_settings="$(jq -s 'reduce .[] as $f ({}; . * $f)' .zed/lsp-config/*.json 2>/dev/null | sed "s|__PROJECT_DIR__|$PWD|g")"
    if [ -n "$zed_settings" ]; then
      ${writeJsonFromVar ".zed/settings.json" "$zed_settings"}
    fi
  '';
}
