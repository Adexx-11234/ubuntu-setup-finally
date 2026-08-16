#!/bin/bash
set -e

# ── VNC password from env ──────────────────────────────────────────────────
VNC_PASSWORD="${VNC_PASSWORD:-changeme}"
mkdir -p /root/.vnc

VNCPASSWD_BIN=$(command -v vncpasswd || command -v tigervncpasswd || \
    find /usr -name "vncpasswd" 2>/dev/null | head -1 || \
    find /usr -name "tigervncpasswd" 2>/dev/null | head -1 || true)

if [[ -n "$VNCPASSWD_BIN" ]]; then
    echo "$VNC_PASSWORD" | "$VNCPASSWD_BIN" -f > /root/.vnc/passwd
else
    # Fallback: use python3 to write VNC DES-obfuscated passwd file
    python3 -c "
import struct
pw = ('${VNC_PASSWORD}'[:8]).encode().ljust(8, b'\x00')
key = bytes([23,82,107,6,35,78,88,7])
enc = bytes([p ^ k for p,k in zip(pw, key)])
import sys; sys.stdout.buffer.write(enc)
" > /root/.vnc/passwd
fi
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

# ── Start VNC (blocks) ────────────────────────────────────────────────────
exec vncserver :1 -geometry 1280x720 -depth 24 -fg
