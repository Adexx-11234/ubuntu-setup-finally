#!/bin/bash
set -e

# ── VNC password from env ──────────────────────────────────────────────────
VNC_PASSWORD="${VNC_PASSWORD:-changeme}"
mkdir -p /root/.vnc

# Write passwd file using tigervnc's own tool
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
