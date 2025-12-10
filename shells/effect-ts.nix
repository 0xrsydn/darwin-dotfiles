{ pkgs, ... }:

let
  effectInit = pkgs.writeShellScriptBin "effect-init" ''
        set -e

        PROJECT_NAME="''${1:-.}"

        if [ "$PROJECT_NAME" != "." ]; then
          mkdir -p "$PROJECT_NAME"
          cd "$PROJECT_NAME"
          echo "Creating Effect project in $PROJECT_NAME..."
        else
          PROJECT_NAME=$(basename "$PWD")
          echo "Initializing Effect project in current directory..."
        fi

        # Generate package.json
        cat > package.json << 'PACKAGE_EOF'
    {
      "name": "PROJECT_NAME_PLACEHOLDER",
      "type": "module",
      "scripts": {
        "typecheck": "tsc --noEmit",
        "lint": "biome check .",
        "format": "biome format --write .",
        "es": "effect-solutions"
      },
      "dependencies": {
        "effect": "latest"
      },
      "devDependencies": {
        "@effect/language-service": "latest",
        "effect-solutions": "latest",
        "typescript": "latest"
      }
    }
    PACKAGE_EOF

        # Replace placeholder with actual project name
        ${pkgs.gnused}/bin/sed -i "s/PROJECT_NAME_PLACEHOLDER/$PROJECT_NAME/" package.json

        # Generate tsconfig.json
        cat > tsconfig.json << 'TSCONFIG_EOF'
    {
      "compilerOptions": {
        "target": "ES2022",
        "module": "NodeNext",
        "moduleResolution": "NodeNext",
        "strict": true,
        "exactOptionalPropertyTypes": true,
        "noUncheckedIndexedAccess": true,
        "noEmit": true,
        "skipLibCheck": true,
        "plugins": [{ "name": "@effect/language-service" }]
      },
      "include": ["src/**/*"]
    }
    TSCONFIG_EOF

        # Generate biome.json
        cat > biome.json << 'BIOME_EOF'
    {
      "$schema": "https://biomejs.dev/schemas/1.9.4/schema.json",
      "organizeImports": { "enabled": true },
      "linter": { "enabled": true },
      "formatter": { "enabled": true, "indentStyle": "space", "indentWidth": 2 }
    }
    BIOME_EOF

        # Create src directory with starter file
        mkdir -p src
        cat > src/index.ts << 'SRC_EOF'
    import { Effect, Console } from "effect"

    const program = Console.log("Hello, Effect!")

    Effect.runPromise(program)
    SRC_EOF

        # Install dependencies
        echo ""
        echo "Installing dependencies..."
        ${pkgs.bun}/bin/bun install

        echo ""
        echo "Effect project initialized successfully!"
        echo ""
        echo "Next steps:"
        echo "  bun run src/index.ts  - Run the starter program"
        echo "  bun typecheck         - Check types"
        echo "  bun lint              - Lint code"
        echo "  bun es list           - Browse Effect patterns"
  '';

in pkgs.mkShell {
  name = "effect-ts";
  packages = with pkgs; [
    bun
    typescript
    biome
    vscode-langservers-extracted
    effectInit
  ];
  shellHook = ''
    mkdir -p "$PWD/.cache/bun"
    export BUN_INSTALL_CACHE="$PWD/.cache/bun"

    es() { ${pkgs.bun}/bin/bunx effect-solutions "$@"; }
    export -f es

    echo "Effect TypeScript shell ready"
    echo "  Bun: ${pkgs.bun.version} | TypeScript: ${pkgs.typescript.version} | Biome: ${pkgs.biome.version}"
    echo ""
    echo "Commands:"
    echo "  effect-init [name]  - Scaffold new Effect project"
    echo "  es <command>        - Run effect-solutions CLI (via bunx)"
    echo "  bun typecheck       - Run TypeScript type checking"
    echo "  bun lint            - Run Biome linter"
    echo "  bun format          - Format code with Biome"
  '';
}
