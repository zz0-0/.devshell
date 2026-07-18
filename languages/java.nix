{ pkgs, devshellVersion ? "", ... }:

{ extraPackages ? [ ], jdk ? pkgs.jdk25 }:

let
  javaMajor = pkgs.lib.versions.major jdk.version;

  vscodeSettings = {
    "java.jdt.ls.java.home" = "${jdk.home}";
    "java.configuration.runtimes" = [
      {
        "name" = "JavaSE-${javaMajor}";
        "path" = "${jdk.home}";
        "default" = true;
      }
    ];
    "java.format.enabled" = true;
    "editor.formatOnSave" = true;
  };
  settingsJson = builtins.toJSON vscodeSettings;

  zedSettings = {
    "languages" = {
      "Java" = {
        "format_on_save" = "on";
        "language_servers" = ["jdtls"];
      };
    };
    "lsp" = {
      "jdtls" = {
        "binary" = {
          "path" = "__PROJECT_DIR__/.zed/lsp/jdtls";
        };
        "settings" = {
          "java" = {
            "home" = "${jdk.home}";
          };
        };
        "initialization_options" = {
          "settings" = {
            "java" = {
              "home" = "${jdk.home}";
              "configuration" = {
                "runtimes" = [
                  {
                    "name" = "JavaSE-${javaMajor}";
                    "path" = "${jdk.home}";
                    "default" = true;
                  }
                ];
              };
            };
          };
        };
      };
    };
  };
  zedFragmentJson = builtins.toJSON zedSettings;
in
pkgs.mkShell {
  buildInputs = [
    jdk
    pkgs.jdt-language-server
    pkgs.maven
    pkgs.gradle
  ] ++ extraPackages;

  shellHook = ''
    # Auto-regenerate config files when devshell version changes
    devshell_stamp=".devshell.stamp"
    if [ ! -f "$devshell_stamp" ] || [ "$(cat "$devshell_stamp" 2>/dev/null)" != "${devshellVersion}" ]; then
      rm -rf .vscode .zed .bin 2>/dev/null
      echo "${devshellVersion}" > "$devshell_stamp"
    fi

    export JAVA_HOME="${jdk.home}"

    echo "☕ Java ${javaMajor} dev environment loaded (JAVA_HOME=$JAVA_HOME)"

    # Setup VS Code
    mkdir -p .vscode
    if [ ! -f ".vscode/settings.json" ] || [ "$(cat .vscode/settings.json 2>/dev/null)" != '${settingsJson}' ]; then
      echo '${settingsJson}' > .vscode/settings.json
    fi

    # Zed LSP wrapper for jdtls (regenerated on every shell entry, safe to embed store paths)
    mkdir -p .zed/lsp
    cat > .zed/lsp/jdtls << 'JDTLS_WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
export JAVA_HOME="${jdk.home}"
exec "${pkgs.jdt-language-server}/bin/jdtls" -data "$PROJECT_DIR/.zed/jdtls-workspace" "$@"
JDTLS_WRAPPER
    chmod +x .zed/lsp/jdtls

    mkdir -p .zed/lsp-config
    echo '${zedFragmentJson}' > .zed/lsp-config/java.json

    # Merge all Zed settings fragments into .zed/settings.json
    if command -v node &>/dev/null; then
      node -e "
        const fs = require('fs');
        const path = require('path');
        const configDir = '.zed/lsp-config';
        const fragments = [];
        if (fs.existsSync(configDir)) {
          fs.readdirSync(configDir).forEach(f => {
            if (f.endsWith('.json')) {
              try {
                fragments.push(JSON.parse(fs.readFileSync(path.join(configDir, f), 'utf8')));
              } catch (e) {}
            }
          });
        }
        function deepMerge(target, source) {
          const output = Object.assign({}, target);
          if (typeof target === 'object' && typeof source === 'object') {
            Object.keys(source).forEach(key => {
              if (typeof source[key] === 'object' && source[key] !== null && !Array.isArray(source[key])) {
                output[key] = deepMerge(target[key] || {}, source[key]);
              } else {
                output[key] = source[key];
              }
            });
          }
          return output;
        }
        const merged = fragments.reduce((acc, frag) => deepMerge(acc, frag), {});
        const projectDir = process.env.PWD || process.cwd();
        const settingsStr = JSON.stringify(merged, null, 2).replace(/__PROJECT_DIR__/g, projectDir);
        fs.writeFileSync('.zed/settings.json', settingsStr + '\n');
      "
    else
      echo '${zedFragmentJson}' | sed "s|__PROJECT_DIR__|$PWD|g" > .zed/settings.json
    fi

    # Auto-fetch Maven dependencies when pom.xml changes
    java_dep_hash=""
    if [ -f "pom.xml" ]; then
      java_dep_hash=$(cat pom.xml 2>/dev/null | sha256sum | cut -d' ' -f1)
    fi

    java_dep_stamp_file=".zed/.mvn-deps.stamp"
    java_previous_dep_hash=""
    if [ -f "$java_dep_stamp_file" ]; then
      java_previous_dep_hash=$(cat "$java_dep_stamp_file")
    fi

    if [ -n "$java_dep_hash" ] && [ "$java_dep_hash" != "$java_previous_dep_hash" ]; then
      echo "📦 pom.xml changed. Fetching Maven dependencies..."
      if mvn -q dependency:go-offline; then
        echo "$java_dep_hash" > "$java_dep_stamp_file"
      fi
    elif [ -n "$java_dep_hash" ]; then
      echo "✅ Maven dependencies unchanged. Skipping fetch."
    fi

    echo "✅ Java toolchain ready (javac, maven, gradle, jdtls)."
  '';

  passthru = {
    inherit vscodeSettings zedSettings;
  };
}
