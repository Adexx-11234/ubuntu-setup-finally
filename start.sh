#!/bin/bash
set -e

# ── Swap (512MB) to prevent Firefox OOM crashes ───────────────────────────
if [ ! -f /swapfile ]; then
    dd if=/dev/zero of=/swapfile bs=1M count=512 status=none
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "Swap enabled (512MB)"
fi

# ── VNC password from env ──────────────────────────────────────────────────
VNC_PASSWORD="${VNC_PASSWORD:-changeme}"
mkdir -p /root/.vnc

printf '%s\n%s\n\n' "$VNC_PASSWORD" "$VNC_PASSWORD" | vncpasswd /root/.vnc/passwd
chmod 600 /root/.vnc/passwd

# ── VNC xstartup ──────────────────────────────────────────────────────────
cat > /root/.vnc/xstartup <<'EOF'
#!/bin/bash
export DISPLAY=:1
export XDG_SESSION_TYPE=x11
unset DBUS_SESSION_BUS_ADDRESS
eval $(dbus-launch --sh-syntax)
export DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
chmod +x /root/.vnc/xstartup

# ── Firefox low-memory profile ────────────────────────────────────────────
mkdir -p /root/.firefox-vnc-profile
if [ ! -f /root/.firefox-vnc-profile/places.sqlite ]; then
    cat > /root/.firefox-vnc-profile/user.js <<'EOF'
// Cache — memory only, no disk
user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.memory.enable", true);
user_pref("browser.cache.memory.capacity", 524288);
user_pref("browser.cache.offline.enable", false);

// Session restore
user_pref("browser.startup.page", 3);
user_pref("browser.sessionstore.interval", 15000);
user_pref("browser.sessionstore.resume_from_crash", true);
user_pref("browser.sessionstore.max_resumed_crashes", -1);
user_pref("browser.sessionstore.max_tabs_undo", 0);
user_pref("browser.sessionstore.max_windows_undo", 0);
user_pref("browser.sessionstore.upgradeBackup.maxUpgradeBackups", 0);

// Single process — saves significant RAM
user_pref("dom.ipc.processCount", 1);
user_pref("browser.tabs.remote.autostart", false);

// Performance
user_pref("gfx.webrender.all", true);
user_pref("gfx.webrender.enabled", true);
user_pref("media.hardware-video-decoding.enabled", false);
user_pref("browser.tabs.unloadOnLowMemory", true);
user_pref("ui.prefersReducedMotion", 1);
user_pref("toolkit.cosmeticAnimations.enabled", false);
user_pref("toolkit.storage.synchronous", 0);
user_pref("network.http.max-connections", 900);
user_pref("network.http.max-connections-per-server", 30);

// Silence
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("startup.homepage_override_url", "");
user_pref("startup.homepage_welcome_url", "");
user_pref("extensions.autoDisableScopes", 0);
user_pref("extensions.enabledScopes", 15);
EOF
fi

# ── Root password (for SSH login) ─────────────────────────────────────────
ROOT_PASSWORD="${ROOT_PASSWORD:-changeme}"
echo "root:$ROOT_PASSWORD" | chpasswd

# ── SSH ───────────────────────────────────────────────────────────────────
mkdir -p /var/run/sshd
/usr/sbin/sshd

# ── Kill any stale VNC locks ──────────────────────────────────────────────
pkill Xtigervnc 2>/dev/null || true
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

# ── Start VNC ─────────────────────────────────────────────────────────────
vncserver :1 -geometry 1280x720 -depth 24
echo "VNC started on :5901"

# ── Start noVNC on port 8080 ──────────────────────────────────────────────
NOVNC_PATH=$(find /usr/share -name "vnc.html" 2>/dev/null | head -1 | xargs dirname || echo "/usr/share/novnc")
websockify --web="$NOVNC_PATH" 8080 localhost:5901 &
echo "noVNC started on :8080 → vnc.html"

# ── Block ──────────────────────────────────────────────────────────────────
tail -f /dev/null
