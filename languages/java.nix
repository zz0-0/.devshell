{ pkgs, ... }:

{
  extraPackages ? [ ],
  jdk ? pkgs.jdk25,
}:

let
  common = import ./common.nix { inherit pkgs; };
  inherit (common)
    mkShell
    writeVscodeSettings
    writeZedFragment
    mergeZedSettings
    writeLspWrapper
    ;

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
        "language_servers" = [ "jdtls" ];
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
common.mkShell {
  buildInputs = [
    jdk
    pkgs.jdt-language-server
    pkgs.maven
    pkgs.gradle
  ]
  ++ extraPackages;

  shellHook = ''
    ${writeVscodeSettings settingsJson}
    ${writeZedFragment "java" zedFragmentJson}
    ${writeLspWrapper {
      name = "jdtls";
      command = "jdtls -data \"$PROJECT_DIR/.zed/jdtls-workspace\"";
    }}
    ${mergeZedSettings}

    export JAVA_HOME="${jdk.home}"

    echo "☕ Java ${javaMajor} dev environment loaded (JAVA_HOME=$JAVA_HOME)"

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
