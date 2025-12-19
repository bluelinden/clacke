{ pkgs, lib, config, inputs, ... }:

# very sorry for the ai slop, i was sick and i couldn't think on the day i had to write this.

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = with pkgs; [
    git
    curl
    wget
    jq
    python313Packages.setuptools
    # bestzip
    sqlite
    # Ghost CLI and related tools
    python3 # Required for some Ghost dependencies
    vips # Image processing for Ghost
  ];

  # https://devenv.sh/languages/
  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_22;
    npm = {
      enable = true;
      install.enable = true;
    };
    yarn = {
      enable = true;
      install.enable = true;
    };
  };

  # https://devenv.sh/services/
  services = {
    mysql = {
      enable = true;
      package = pkgs.mysql80;
      initialDatabases = [{ name = "ghost_dev"; }];
      ensureUsers = [{
        name = "ghost";
        password = "ghost";
        ensurePermissions = { "ghost_dev.*" = "ALL PRIVILEGES"; };
      }];
      settings = {
        mysqld = {
          port = 3306;
          bind-address = "127.0.0.1";
        };
      };
    };
  };

  # https://devenv.sh/processes/
  processes = {
    theme-dev = {
      exec = "npm run dev";
      process-compose = {
        depends_on = {
          theme-install = { condition = "process_completed_successfully"; };
        };
      };
    };
    theme-install = {
      exec = "npm install";
      process-compose = { availability = { restart = "no"; }; };
    };
    ghost-dev = {
      exec = "cd .ghost && ghost start --development";
      process-compose = {
        depends_on = {
          # mysql = { condition = "process_healthy"; };
          ghost-setup-complete = {
            condition = "process_completed_successfully";
          };
        };
      };
    };
    ghost-setup-complete = {
      exec = ''
        if [ ! -d ".ghost" ]; then
          echo "Ghost not installed. Run 'ghost-install' first."
          exit 1
        fi
        echo "Ghost setup complete, ready to start"
      '';
      process-compose = { availability = { restart = "no"; }; };
    };
  };

  # https://devenv.sh/scripts/
  scripts = {
    # Theme development scripts
    theme-build.exec = "npm run build";
    theme-test.exec = "npm run test";
    theme-zip.exec = "npm run zip";
    theme-clean.exec = "rm -rf node_modules assets/built *.zip";

    # Ghost installation scripts
    ghost-install.exec = ''
      echo "🎃 Installing Ghost development instance..."

      # Install Ghost CLI globally if not present
      if ! command -v ghost &> /dev/null; then
        echo "Installing Ghost CLI..."
        npm install -g ghost-cli@latest
      fi

      # Create Ghost directory
      mkdir -p .ghost
      cd .ghost

      # Initialize Ghost with development config
      if [ ! -f "config.development.json" ]; then
        echo "Setting up Ghost..."
        ghost install local --development \
          --db mysql \
          --dbhost localhost \
          --dbport 3306 \
          --dbuser ghost \
          --dbpass ghost \
          --dbname ghost_dev \
          --url http://localhost:2368 \
          --port 2368 \
          --process local \
          --no-start \
          --no-prompt
      fi

      echo "✓ Ghost installed in .ghost/ directory"
      echo "✓ Configured for development with MySQL"
      echo ""
      echo "Next steps:"
      echo "  1. Run 'devenv up' to start all services"
      echo "  2. Visit http://localhost:2368/ghost to complete setup"
      echo "  3. Install your theme with 'ghost-theme-install'"
    '';

    ghost-remove.exec = ''
      echo "🗑️  Removing Ghost development instance..."

      # Stop Ghost if running
      if [ -d ".ghost" ]; then
        cd .ghost
        ghost stop || true
      fi

      # Remove Ghost directory
      rm -rf .ghost

      echo "✓ Ghost development instance removed"
    '';

    ghost-theme-install.exec = ''
      if [ ! -d ".ghost" ]; then
        echo "❌ Ghost not installed. Run 'ghost-install' first."
        exit 1
      fi

      echo "📦 Installing current theme to Ghost..."

      # Build the theme first
      npm run build

      # Create theme zip
      npm run zip

      # Get theme name from package.json
      THEME_NAME=$(node -p "require('./package.json').name")

      # Copy theme to Ghost themes directory
      cd .ghost
      mkdir -p content/themes

      # Remove existing theme if present
      rm -rf "content/themes/$THEME_NAME"

      # Extract theme zip to Ghost themes directory
      cd content/themes
      unzip -q "../../../$THEME_NAME.zip" -d "$THEME_NAME"

      echo "✓ Theme '$THEME_NAME' installed to Ghost"
      echo "✓ Activate it in Ghost Admin at http://localhost:2368/ghost"
    '';

    ghost-theme-activate.exec = ''
      if [ ! -d ".ghost" ]; then
        echo "❌ Ghost not installed. Run 'ghost-install' first."
        exit 1
      fi

      THEME_NAME=$(node -p "require('./package.json').name")

      echo "🎨 Activating theme '$THEME_NAME'..."

      cd .ghost
      ghost theme activate "$THEME_NAME" || echo "⚠️  Theme activation failed. You may need to activate it manually in Ghost Admin."
    '';

    ghost-theme-link.exec = ''
      if [ ! -d ".ghost" ]; then
        echo "❌ Ghost not installed. Run 'ghost-install' first."
        exit 1
      fi

      echo "🔗 Symlinking current theme to Ghost..."

      # Get theme name from package.json
      THEME_NAME=$(node -p "require('./package.json').name")

      # Build the theme first to ensure assets are ready
      npm run build

      # Create themes directory if it doesn't exist
      mkdir -p .ghost/content/themes

      # Remove existing theme if present (could be directory or symlink)
      if [ -e ".ghost/content/themes/$THEME_NAME" ]; then
        echo "Removing existing theme '$THEME_NAME'..."
        rm -rf ".ghost/content/themes/$THEME_NAME"
      fi

      # Create absolute paths
      THEME_SOURCE=$(pwd)
      THEME_TARGET="$THEME_SOURCE/.ghost/content/themes/$THEME_NAME"

      # Create the symlink
      ln -sf "$THEME_SOURCE" "$THEME_TARGET"

      echo "✓ Theme '$THEME_NAME' symlinked to Ghost"
      echo "✓ Changes to theme files will be immediately reflected"
      echo "✓ Activate it in Ghost Admin at http://localhost:2368/ghost"
    '';

    ghost-reset.exec = ''
      echo "🔄 Resetting Ghost development instance..."
      ghost-remove
      ghost-install
    '';

    dev-setup.exec = ''
      echo "🚀 Setting up complete Ghost theme development environment..."
      echo ""
      echo "1️⃣ Installing theme dependencies..."
      npm install
      echo ""
      echo "2️⃣ Installing Ghost development instance..."
      ghost-install
      echo ""
      echo "✅ Setup complete!"
      echo ""
      echo "🎯 Next steps:"
      echo "  1. Run 'devenv up' to start all services (MySQL, Ghost, theme dev server)"
      echo "  2. Visit http://localhost:2368/ghost to complete Ghost setup"
      echo "  3. Run 'ghost-theme-install' to install your theme"
      echo "  4. Theme changes will auto-reload on http://localhost:3000 (Rollup dev server)"
      echo "  5. Ghost site will be available at http://localhost:2368"
    '';
  };

  # # https://devenv.sh/pre-commit-hooks/
  # git-hooks = {
  #   # General hooks
  #   trailing-whitespace.enable = true;
  #   end-of-file-fixer.enable = true;
  #   check-merge-conflicts.enable = true;
  #   # check-case-conflicts.enable = true;
  # };

  # https://devenv.sh/integrations/dotenv/
  dotenv.enable = true;

  # Environment variables
  env = {
    # Node.js environment
    NODE_ENV = lib.mkDefault "development";

    # Ghost development
    GHOST_ENV = "development";
    GHOST_PORT = "2368";
    GHOST_HOST = "localhost";

    # Database configuration
    DB_HOST = "localhost";
    DB_PORT = "3306";
    DB_USER = "ghost";
    DB_PASS = "ghost";
    DB_NAME = "ghost_dev";

    # Theme development
    BUILD = lib.mkDefault "development";
    ROLLUP_WATCH = "true";
    LIVERELOAD_PORT = "35729";
  };

  # https://devenv.sh/reference/options/
  enterShell = ''
    # Create necessary directories
    mkdir -p assets/built
    mkdir -p assets/css
    mkdir -p assets/js

    # Set proper permissions
    chmod -R 755 assets/ partials/ members/ || true

    echo "👻 Ghost Theme Development Environment"
    echo "Theme: clacke"
    echo "Node.js: $(node --version)"
    echo "npm: $(npm --version)"
    echo ""

    if [ -d ".ghost" ]; then
      echo "✅ Ghost development instance: INSTALLED"
    else
      echo "⭕ Ghost development instance: NOT INSTALLED"
    fi

    echo ""
    echo "🚀 Quick Start:"
    echo "  dev-setup          - Complete setup (theme + Ghost)"
    echo "  devenv up          - Start all services"
    echo ""
    echo "🎨 Theme Commands:"
    echo "  theme-build        - Build theme for production"
    echo "  theme-test         - Test theme with gscan"
    echo "  theme-zip          - Create theme package"
    echo "  theme-clean        - Clean build artifacts"
    echo ""
    echo "👻 Ghost Commands:"
    echo "  ghost-install      - Install Ghost development instance"
    echo "  ghost-remove       - Remove Ghost development instance"
    echo "  ghost-reset        - Reset Ghost instance"
    echo "  ghost-theme-install - Install current theme to Ghost (zip method)"
    echo "  ghost-theme-link   - Symlink theme to Ghost (live development)"
    echo "  ghost-theme-activate - Activate theme in Ghost"
    echo ""
    echo "🌐 Development URLs:"
    echo "  Ghost site: http://localhost:2368"
    echo "  Ghost admin: http://localhost:2368/ghost"
    echo "  Theme dev server: http://localhost:3000 (with live reload)"
  '';

  enterTest = ''
    echo "🧪 Running Ghost theme tests..."
    npm run test
  '';
}
