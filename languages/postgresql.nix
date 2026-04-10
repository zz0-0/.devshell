{ pkgs, ... }:
{ extraPackages ? [] }:

let
  # Create helper scripts directory
  pg-helpers = pkgs.writeScriptBin "pg-helpers" ''
    # This package provides: start_pg, stop_pg, reset_pg
    # Scripts are installed via shellHook
  '';
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    postgresql
  ] ++ extraPackages;

  shellHook = ''
    echo "🐘 PostgreSQL dev environment loaded"

    export PGDATA="''${PWD}/.postgres/data"
    export PGHOST="''${PWD}/.postgres"
    export PGPORT="5432"

    # Create helper scripts in project-local bin
    LOCAL_BIN="''${PWD}/.nix/bin"
    mkdir -p "$LOCAL_BIN"
    export PATH="$LOCAL_BIN:$PATH"

    # start_pg script
    cat > "$LOCAL_BIN/start_pg" << 'SCRIPT'
#!/usr/bin/env bash
set -e
PGDATA="''${PWD}/.postgres/data"
PGHOST="''${PWD}/.postgres"
PGPORT="5432"

if [ ! -d "$PGDATA" ]; then
  echo "📦 Initializing PostgreSQL at $PGDATA"
  mkdir -p "$PGDATA"
  initdb --auth=trust --encoding=UTF8 --locale=C
fi

# Create socket directory (needed on NixOS)
SOCKET_DIR="/run/postgresql"
if [ ! -d "$SOCKET_DIR" ]; then
  mkdir -p "$SOCKET_DIR" 2>/dev/null || true
  export PGHOST="$PGDATA"  # fallback to local socket
fi

if [ ! -f "$PGDATA/postmaster.pid" ]; then
  echo "🚀 Starting PostgreSQL on port $PGPORT..."
  pg_ctl -D "$PGDATA" -l "$PGDATA/logfile" -o "-k $PGHOST" start
  sleep 2
  echo "✅ PostgreSQL started"
  echo "   Connection: postgresql://$(whoami)@localhost:$PGPORT/$(whoami)"
else
  PID=$(head -1 "$PGDATA/postmaster.pid" 2>/dev/null)
  echo "ℹ️  PostgreSQL already running (PID: $PID)"
fi
SCRIPT
    chmod +x "$LOCAL_BIN/start_pg"

    # stop_pg script
    cat > "$LOCAL_BIN/stop_pg" << 'SCRIPT'
#!/usr/bin/env bash
PGDATA="''${PWD}/.postgres/data"
if [ -f "$PGDATA/postmaster.pid" ]; then
  echo "🛑 Stopping PostgreSQL..."
  pg_ctl -D "$PGDATA" stop
  echo "✅ PostgreSQL stopped"
else
  echo "ℹ️  PostgreSQL is not running"
fi
SCRIPT
    chmod +x "$LOCAL_BIN/stop_pg"

    # reset_pg script
    cat > "$LOCAL_BIN/reset_pg" << 'SCRIPT'
#!/usr/bin/env bash
PGDATA="''${PWD}/.postgres/data"
if [ -f "$PGDATA/postmaster.pid" ]; then
  echo "🛑 Stopping PostgreSQL..."
  pg_ctl -D "$PGDATA" stop
fi
if [ -d "$PGDATA" ]; then
  echo "🗑️  Removing data..."
  rm -rf "$PGDATA"
  echo "✅ Removed. Run start_pg to reinitialize."
fi
SCRIPT
    chmod +x "$LOCAL_BIN/reset_pg"

    echo ""
    echo "📋 Available commands:"
    echo "   start_pg   - Start PostgreSQL server"
    echo "   stop_pg    - Stop PostgreSQL server"
    echo "   reset_pg   - Stop and remove all data (fresh start)"
    echo "   psql       - Connect to database (after starting)"
    echo ""
    echo "💡 Quick start:"
    echo "   start_pg"
    echo "   createdb kenix"
    echo "   psql kenix"
  '';
}
