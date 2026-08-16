FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Base packages + XFCE4 + TigerVNC + noVNC + SSH
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    tigervnc-standalone-server \
    tigervnc-tools \
    novnc \
    websockify \
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    dbus-x11 \
    x11-xserver-utils \
    curl \
    wget \
    ca-certificates \
    tzdata \
    python3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Firefox — Mozilla official APT repo (non-snap)
RUN apt-get remove -y firefox 2>/dev/null || true && \
    apt-get purge  -y firefox 2>/dev/null || true && \
    install -d -m 0755 /etc/apt/keyrings && \
    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- \
        | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null && \
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
        | tee /etc/apt/sources.list.d/mozilla.list > /dev/null && \
    printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' \
        > /etc/apt/preferences.d/mozilla && \
    apt-get update && \
    apt-get install -y firefox && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# SSH setup
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes"        >> /etc/ssh/sshd_config

# Pre-create 512MB swap
RUN dd if=/dev/zero of=/swapfile bs=1M count=512 && \
    chmod 600 /swapfile && \
    mkswap /swapfile

COPY start.sh /start.sh
RUN chmod +x /start.sh

# noVNC served on 8080 (Railway public HTTP), VNC on 5901, SSH on 22
EXPOSE 22
EXPOSE 8080

CMD ["/start.sh"]
