#!/usr/bin/env bash
set -e

# ==============================================================================
# Home Assistant Add-on: Git Config Backup
# Main entry point
# ==============================================================================

CONFIG_PATH="/data/options.json"
REPO_DIR="/data/repository"
HA_CONFIG="/config"
SSH_DIR="/data/ssh"
STATUS_FILE="/data/status.json"
WEBUI_DIR="/data/webui"

# ------------------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------------------
get_config() {
    local key="$1"
    local default="$2"
    jq -r ".$key // \"$default\"" "$CONFIG_PATH"
}

get_config_array() {
    local key="$1"
    jq -r ".$key[]? // empty" "$CONFIG_PATH"
}

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

update_status() {
    local status="$1"
    local message="$2"
    local last_commit="${3:-}"

    cat > "$STATUS_FILE" << EOF
{
  "status": "$status",
  "message": "$message",
  "last_commit": "$last_commit",
  "last_update": "$(date -Iseconds)",
  "repository": "$REPOSITORY_URL",
  "branch": "$BRANCH"
}
EOF
}

# ------------------------------------------------------------------------------
# Load configuration
# ------------------------------------------------------------------------------
REPOSITORY_URL=$(get_config "repository_url" "")
BRANCH=$(get_config "branch" "main")
USERNAME=$(get_config "username" "")
PASSWORD=$(get_config "password" "")
SSH_KEY=$(get_config "ssh_key" "")
AUTO_GENERATE_SSH_KEY=$(get_config "auto_generate_ssh_key" "true")
COMMIT_MESSAGE=$(get_config "commit_message" "Automated backup: {date}")
COMMIT_USER_NAME=$(get_config "commit_user_name" "Home Assistant")
COMMIT_USER_EMAIL=$(get_config "commit_user_email" "homeassistant@local")
BACKUP_INTERVAL=$(get_config "backup_interval_hours" "24")
BACKUP_ON_START=$(get_config "backup_on_start" "true")
WATCH_REALTIME=$(get_config "watch_realtime" "false")
WATCH_DEBOUNCE=$(get_config "watch_debounce_seconds" "30")
CRON_SCHEDULE=$(get_config "cron_schedule" "")

# ------------------------------------------------------------------------------
# SSH Key Management
# ------------------------------------------------------------------------------
setup_ssh_key() {
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    local key_file="$SSH_DIR/id_ed25519"
    local pub_file="$SSH_DIR/id_ed25519.pub"

    # If user provided an SSH key, use it
    if [ -n "$SSH_KEY" ]; then
        log_info "Using provided SSH key..."
        echo "$SSH_KEY" > "$key_file"
        chmod 600 "$key_file"

        # Generate public key from private
        ssh-keygen -y -f "$key_file" > "$pub_file" 2>/dev/null || {
            log_error "Invalid SSH key provided"
            return 1
        }
    elif [ "$AUTO_GENERATE_SSH_KEY" = "true" ]; then
        # Auto-generate if doesn't exist
        if [ ! -f "$key_file" ]; then
            log_info "Generating new SSH key..."
            ssh-keygen -t ed25519 -f "$key_file" -N "" -C "homeassistant-git-backup"
            log_info "SSH key generated successfully"
        else
            log_info "Using existing auto-generated SSH key"
        fi
    else
        log_info "No SSH key configured, will use HTTPS authentication"
        return 0
    fi

    # Setup SSH config
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh

    cp "$key_file" /root/.ssh/id_ed25519
    cp "$pub_file" /root/.ssh/id_ed25519.pub 2>/dev/null || true
    chmod 600 /root/.ssh/id_ed25519

    cat > /root/.ssh/config << EOF
Host *
    StrictHostKeyChecking accept-new
    UserKnownHostsFile /root/.ssh/known_hosts
    IdentityFile /root/.ssh/id_ed25519
EOF
    chmod 600 /root/.ssh/config

    # Pre-populate known hosts for common providers
    ssh-keyscan -t ed25519,rsa github.com >> /root/.ssh/known_hosts 2>/dev/null || true
    ssh-keyscan -t ed25519,rsa gitlab.com >> /root/.ssh/known_hosts 2>/dev/null || true
    ssh-keyscan -t ed25519,rsa bitbucket.org >> /root/.ssh/known_hosts 2>/dev/null || true

    # Display and export public key
    if [ -f "$pub_file" ]; then
        log_info "=============================================="
        log_info "SSH PUBLIC KEY (add this to your Git provider):"
        log_info "=============================================="
        cat "$pub_file"
        log_info "=============================================="

        # Copy to /share for easy access via File Editor
        cp "$pub_file" /share/git_backup_ssh_key.pub
        log_info "Public key also saved to: /share/git_backup_ssh_key.pub"
    fi
}

get_public_key() {
    local pub_file="$SSH_DIR/id_ed25519.pub"
    if [ -f "$pub_file" ]; then
        cat "$pub_file"
    else
        echo "No SSH key generated"
    fi
}

# ------------------------------------------------------------------------------
# Git Credential Setup (for HTTPS)
# ------------------------------------------------------------------------------
setup_git_credentials() {
    if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
        log_info "Setting up Git credentials for HTTPS..."

        git config --global credential.helper 'store --file=/data/.git-credentials'

        # Extract host from URL
        local host
        host=$(echo "$REPOSITORY_URL" | sed -E 's|https?://([^/]+).*|\1|')

        echo "https://${USERNAME}:${PASSWORD}@${host}" > /data/.git-credentials
        chmod 600 /data/.git-credentials

        log_info "Git credentials configured for $host"
    fi
}

# ------------------------------------------------------------------------------
# Repository Setup
# ------------------------------------------------------------------------------
setup_repository() {
    log_info "Setting up repository..."

    # Configure git user
    git config --global user.name "$COMMIT_USER_NAME"
    git config --global user.email "$COMMIT_USER_EMAIL"
    git config --global init.defaultBranch "$BRANCH"
    git config --global --add safe.directory "$REPO_DIR"

    if [ -d "$REPO_DIR/.git" ]; then
        log_info "Repository already exists, fetching updates..."
        cd "$REPO_DIR"
        git fetch origin "$BRANCH" 2>/dev/null || log_warn "Could not fetch from remote"
    else
        log_info "Cloning repository..."
        mkdir -p "$REPO_DIR"

        if git clone --branch "$BRANCH" --single-branch "$REPOSITORY_URL" "$REPO_DIR" 2>/dev/null; then
            log_info "Repository cloned successfully"
        else
            log_info "Could not clone (may be empty repo), initializing..."
            cd "$REPO_DIR"
            git init
            git checkout -b "$BRANCH"
            git remote add origin "$REPOSITORY_URL" 2>/dev/null || git remote set-url origin "$REPOSITORY_URL"
        fi
    fi

    cd "$REPO_DIR"
}

# ------------------------------------------------------------------------------
# Generate .gitignore
# ------------------------------------------------------------------------------
generate_gitignore() {
    cat > "$REPO_DIR/.gitignore" << 'EOF'
# Home Assistant Git Backup - Auto-generated .gitignore

# Database files
*.db
*.db-shm
*.db-wal

# Log files
*.log
home-assistant.log*
OZW_Log.txt

# Cache and temporary files
__pycache__/
*.py[cod]
.cache/
*.tmp

# Backups
backups/
backup/

# TTS cache
tts/

# Cloud connection data
.cloud/

# Restore state
.storage/core.restore_state

# Node-RED credentials
flows_cred.json

# ESPHome secrets
esphome/secrets.yaml

# Large media files
*.mp4
*.mp3
*.wav
*.avi
*.mkv

# IDE files
.vscode/
.idea/
*.swp
*.swo
*~

# OS files
.DS_Store
Thumbs.db
EOF

    # Add user-defined exclude patterns
    echo "" >> "$REPO_DIR/.gitignore"
    echo "# User-defined exclude patterns" >> "$REPO_DIR/.gitignore"
    while IFS= read -r pattern; do
        if [ -n "$pattern" ]; then
            echo "$pattern" >> "$REPO_DIR/.gitignore"
        fi
    done < <(get_config_array "exclude_patterns")
}

# ------------------------------------------------------------------------------
# Sync and Commit
# ------------------------------------------------------------------------------
do_backup() {
    local trigger_source="${1:-manual}"

    log_info "Starting backup (trigger: $trigger_source)..."
    update_status "running" "Backup in progress..."

    cd "$REPO_DIR"

    # Generate/update .gitignore
    generate_gitignore

    # Sync configuration files using rsync
    log_info "Syncing configuration from $HA_CONFIG..."

    rsync -av --delete \
        --exclude='.git/' \
        --exclude='*.db' \
        --exclude='*.db-shm' \
        --exclude='*.db-wal' \
        --exclude='*.log' \
        --exclude='home-assistant.log*' \
        --exclude='tts/' \
        --exclude='backups/' \
        --exclude='.cloud/' \
        --exclude='__pycache__/' \
        --exclude='.storage/core.restore_state' \
        --exclude='OZW_Log.txt' \
        "$HA_CONFIG/" "$REPO_DIR/" 2>/dev/null || {
            log_warn "rsync had warnings, continuing..."
        }

    # Stage all changes
    git add -A

    # Check if there are changes to commit
    if git diff --cached --quiet; then
        log_info "No changes to commit"
        update_status "idle" "No changes detected"
        return 0
    fi

    # Create commit message with date
    local date_str
    date_str=$(date '+%Y-%m-%d %H:%M:%S')
    local message
    message=$(echo "$COMMIT_MESSAGE" | sed "s/{date}/$date_str/g")

    # Commit
    log_info "Committing changes..."
    git commit -m "$message"

    # Push
    log_info "Pushing to remote..."
    if git push -u origin "$BRANCH" 2>&1; then
        local last_commit
        last_commit=$(git log -1 --oneline)
        log_info "Backup completed: $last_commit"
        update_status "success" "Backup successful" "$last_commit"
        return 0
    else
        log_error "Failed to push to remote"
        update_status "error" "Push failed"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# File Watcher (inotify)
# ------------------------------------------------------------------------------
start_file_watcher() {
    log_info "Starting file watcher with ${WATCH_DEBOUNCE}s debounce..."

    local last_trigger=0

    inotifywait -m -r -e modify,create,delete,move \
        --exclude '(\.git|\.db|\.log|__pycache__|\.tmp)' \
        "$HA_CONFIG" 2>/dev/null | while read -r directory event filename; do

        # Skip if file matches exclude patterns
        case "$filename" in
            *.db|*.db-shm|*.db-wal|*.log|*.tmp|*.pyc)
                continue
                ;;
        esac

        local now
        now=$(date +%s)
        local diff=$((now - last_trigger))

        if [ $diff -ge "$WATCH_DEBOUNCE" ]; then
            log_info "File change detected: $filename ($event)"
            last_trigger=$now

            # Run backup in background to not block watcher
            (sleep 2 && do_backup "inotify") &
        fi
    done
}

# ------------------------------------------------------------------------------
# Web UI Server
# ------------------------------------------------------------------------------
start_webui() {
    log_info "Starting Web UI on port 8099..."

    mkdir -p "$WEBUI_DIR"

    # Create the web UI Python script
    cat > "$WEBUI_DIR/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server
import json
import os
import subprocess
import urllib.parse

STATUS_FILE = "/data/status.json"
SSH_PUB_FILE = "/data/ssh/id_ed25519.pub"

class BackupHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Suppress logging

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path

        if path == "/" or path == "/index.html":
            self.serve_html()
        elif path == "/api/status":
            self.serve_status()
        elif path == "/api/ssh-key":
            self.serve_ssh_key()
        else:
            self.send_error(404)

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path

        if path == "/api/backup":
            self.trigger_backup()
        else:
            self.send_error(404)

    def serve_html(self):
        html = """<!DOCTYPE html>
<html>
<head>
    <title>Git Config Backup</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0; padding: 20px;
            background: #f5f5f5;
            color: #333;
        }
        .container { max-width: 800px; margin: 0 auto; }
        h1 { color: #1976d2; margin-bottom: 20px; }
        .card {
            background: white;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .card h2 { margin-top: 0; color: #333; font-size: 1.2em; }
        .status { display: flex; align-items: center; gap: 10px; margin-bottom: 10px; }
        .status-dot {
            width: 12px; height: 12px;
            border-radius: 50%;
            background: #ccc;
        }
        .status-dot.success { background: #4caf50; }
        .status-dot.error { background: #f44336; }
        .status-dot.running { background: #ff9800; animation: pulse 1s infinite; }
        .status-dot.idle { background: #2196f3; }
        @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
        .ssh-key {
            background: #263238;
            color: #aed581;
            padding: 15px;
            border-radius: 4px;
            font-family: 'Monaco', 'Menlo', monospace;
            font-size: 12px;
            word-break: break-all;
            white-space: pre-wrap;
            position: relative;
        }
        .copy-btn {
            position: absolute;
            top: 10px; right: 10px;
            background: #455a64;
            color: white;
            border: none;
            padding: 5px 10px;
            border-radius: 4px;
            cursor: pointer;
        }
        .copy-btn:hover { background: #546e7a; }
        button.primary {
            background: #1976d2;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
        }
        button.primary:hover { background: #1565c0; }
        button.primary:disabled { background: #ccc; cursor: not-allowed; }
        .info { color: #666; font-size: 0.9em; }
        .info code { background: #eee; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Git Config Backup</h1>

        <div class="card">
            <h2>Status</h2>
            <div class="status">
                <div class="status-dot" id="statusDot"></div>
                <span id="statusText">Loading...</span>
            </div>
            <div id="statusDetails" class="info"></div>
            <br>
            <button class="primary" id="backupBtn" onclick="triggerBackup()">
                Run Backup Now
            </button>
        </div>

        <div class="card">
            <h2>SSH Public Key</h2>
            <p class="info">Add this key to your Git provider (GitHub, GitLab, etc.) to enable SSH authentication:</p>
            <div class="ssh-key" id="sshKey">
                Loading...
                <button class="copy-btn" onclick="copyKey()">Copy</button>
            </div>
            <br>
            <p class="info">
                <strong>GitHub:</strong> Settings → SSH and GPG keys → New SSH key<br>
                <strong>GitLab:</strong> Preferences → SSH Keys → Add new key
            </p>
        </div>
    </div>

    <script>
        function updateStatus() {
            fetch('api/status')
                .then(r => r.json())
                .then(data => {
                    document.getElementById('statusDot').className = 'status-dot ' + data.status;
                    document.getElementById('statusText').textContent = data.message;
                    let details = '';
                    if (data.repository) details += 'Repository: ' + data.repository + '<br>';
                    if (data.branch) details += 'Branch: ' + data.branch + '<br>';
                    if (data.last_commit) details += 'Last commit: ' + data.last_commit + '<br>';
                    if (data.last_update) details += 'Updated: ' + new Date(data.last_update).toLocaleString();
                    document.getElementById('statusDetails').innerHTML = details;
                })
                .catch(() => {
                    document.getElementById('statusText').textContent = 'Unable to fetch status';
                });
        }

        function loadSSHKey() {
            fetch('api/ssh-key')
                .then(r => r.text())
                .then(key => {
                    document.getElementById('sshKey').innerHTML = key +
                        '<button class="copy-btn" onclick="copyKey()">Copy</button>';
                });
        }

        function copyKey() {
            const keyEl = document.getElementById('sshKey');
            const keyText = keyEl.textContent.replace('Copy', '').trim();

            // Try modern clipboard API first
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(keyText).then(() => {
                    showCopied();
                }).catch(() => {
                    fallbackCopy(keyText);
                });
            } else {
                fallbackCopy(keyText);
            }
        }

        function fallbackCopy(text) {
            // Fallback: create temporary textarea
            const ta = document.createElement('textarea');
            ta.value = text;
            ta.style.position = 'fixed';
            ta.style.left = '-9999px';
            document.body.appendChild(ta);
            ta.select();
            try {
                document.execCommand('copy');
                showCopied();
            } catch (e) {
                // Last resort: select the text for manual copy
                alert('Press Ctrl+C / Cmd+C to copy:\\n\\n' + text);
            }
            document.body.removeChild(ta);
        }

        function showCopied() {
            const btn = document.querySelector('.copy-btn');
            btn.textContent = 'Copied!';
            setTimeout(() => btn.textContent = 'Copy', 2000);
        }

        function triggerBackup() {
            const btn = document.getElementById('backupBtn');
            btn.disabled = true;
            btn.textContent = 'Running...';

            fetch('api/backup', { method: 'POST' })
                .then(r => r.json())
                .then(() => {
                    setTimeout(updateStatus, 2000);
                })
                .finally(() => {
                    btn.disabled = false;
                    btn.textContent = 'Run Backup Now';
                });
        }

        updateStatus();
        loadSSHKey();
        setInterval(updateStatus, 10000);
    </script>
</body>
</html>"""
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(html.encode())

    def serve_status(self):
        try:
            with open(STATUS_FILE, 'r') as f:
                status = f.read()
        except:
            status = '{"status": "unknown", "message": "Status not available"}'

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(status.encode())

    def serve_ssh_key(self):
        try:
            with open(SSH_PUB_FILE, 'r') as f:
                key = f.read().strip()
        except:
            key = "No SSH key generated. Enable 'auto_generate_ssh_key' in configuration."

        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(key.encode())

    def trigger_backup(self):
        # Signal the main process to run backup
        with open("/tmp/trigger_backup", "w") as f:
            f.write("1")

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"status": "triggered"}')

if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", 8099), BackupHandler)
    print("Web UI running on port 8099")
    server.serve_forever()
PYEOF

    chmod +x "$WEBUI_DIR/server.py"
    python3 "$WEBUI_DIR/server.py" &
}

# ------------------------------------------------------------------------------
# Check for manual trigger
# ------------------------------------------------------------------------------
check_manual_trigger() {
    if [ -f "/tmp/trigger_backup" ]; then
        rm -f "/tmp/trigger_backup"
        do_backup "manual_webui" || true
    fi
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
main() {
    log_info "=== Git Config Backup Add-on ==="
    log_info "Repository: ${REPOSITORY_URL:-not configured}"
    log_info "Branch: $BRANCH"

    # Initialize status
    update_status "starting" "Initializing..."

    # Setup SSH key
    setup_ssh_key

    # Start Web UI
    start_webui

    # Check if repository is configured
    if [ -z "$REPOSITORY_URL" ]; then
        log_warn "Repository URL not configured!"
        log_info "Please configure the add-on and add your SSH key to your Git provider."
        log_info "Access the Web UI to copy your SSH public key."
        update_status "idle" "Waiting for configuration - add SSH key to Git provider"

        # Keep running for Web UI access
        while true; do
            check_manual_trigger
            sleep 5
        done
    fi

    # Setup Git credentials
    setup_git_credentials

    # Setup repository
    setup_repository || {
        log_error "Failed to setup repository"
        update_status "error" "Repository setup failed"

        # Keep running for Web UI
        while true; do
            check_manual_trigger
            sleep 5
        done
    }

    # Backup on start if configured
    if [ "$BACKUP_ON_START" = "true" ]; then
        log_info "Performing initial backup..."
        do_backup "startup" || log_warn "Initial backup failed"
    fi

    # Start file watcher if enabled
    if [ "$WATCH_REALTIME" = "true" ]; then
        start_file_watcher &
        WATCHER_PID=$!
        log_info "File watcher started (PID: $WATCHER_PID)"
    fi

    # Main loop
    if [ "$BACKUP_INTERVAL" -gt 0 ]; then
        local interval_seconds=$((BACKUP_INTERVAL * 3600))
        log_info "Entering backup loop (interval: ${BACKUP_INTERVAL}h)..."

        while true; do
            # Check for manual trigger every 5 seconds
            for ((i=0; i<interval_seconds; i+=5)); do
                check_manual_trigger
                sleep 5
            done

            log_info "Scheduled backup triggered"
            do_backup "scheduled" || log_warn "Scheduled backup failed"
        done
    else
        log_info "Interval backup disabled, running in watch-only mode..."
        update_status "idle" "Watch mode active"

        while true; do
            check_manual_trigger
            sleep 5
        done
    fi
}

# Trap for cleanup
cleanup() {
    log_info "Shutting down..."
    [ -n "${WATCHER_PID:-}" ] && kill "$WATCHER_PID" 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT

# Run main
main
