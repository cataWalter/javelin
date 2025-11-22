#!/bin/bash

# JAVELIN PREVIEW (ULTRA LEAN EDITION)
# ------------------------------------
# Installs Javelin without "Recommended" bloat.
# Target: Devuan Excalibur

if [ "$(id -u)" -ne 0 ]; then
   echo "Run as root: su -"
   exit 1
fi

echo ">>> [1/4] Updating Repos..."
apt-get update

echo ">>> [2/4] Installing Minimal Package List..."
# --no-install-recommends : The magic flag for minimalism
# dbus-x11 : Required for IPC in minimal window managers
# ca-certificates : Required for SSL/HTTPS (sometimes missed in minimal installs)

apt-get install -y --no-install-recommends \
    linux-image-liquorix-amd64 linux-headers-liquorix-amd64 \
    icewm icewm-common slim lxappearance nitrogen dunst numlockx \
    thunar thunar-volman thunar-archive-plugin gvfs-backends gvfs-fuse tumbler \
    kitty chromium chromium-l10n qbittorrent mpv viewnior geany gparted synaptic \
    linux-cpupower msr-tools lm-sensors htop fastfetch curl wget \
    dbus-x11 ca-certificates xorg xserver-xorg-video-all

if [ $? -ne 0 ]; then
    echo "!!! ERROR: Installation failed."
    exit 1
fi

echo ">>> [3/4] Cleaning up Bloat..."
# This attempts to remove packages that were auto-installed previously
# but are no longer strictly needed.
apt-get autoremove -y

echo ">>> [4/4] Applying Configs..."

# 1. Configure Kitty
mkdir -p /etc/xdg/kitty
cat <<EOF > /etc/xdg/kitty/kitty.conf
font_family monospace
font_size 11.0
background #101010
foreground #00ff00
selection_background #00aa00
selection_foreground #000000
repaint_delay 8
sync_to_monitor yes
EOF

# 2. Configure IceWM Startup
mkdir -p /etc/icewm
cat <<EOF > /etc/icewm/startup
#!/bin/sh
nm-applet &
pavucontrol &
thunar --daemon &
nitrogen --restore &
numlockx on &
EOF
chmod +x /etc/icewm/startup

# 3. Set Defaults
update-alternatives --set x-terminal-emulator /usr/bin/kitty
update-alternatives --set x-www-browser /usr/bin/chromium
update-alternatives --set gnome-www-browser /usr/bin/chromium

# 4. Optimization Script
cat <<EOF > /usr/local/bin/javelin-opt.sh
#!/bin/sh
if command -v cpupower > /dev/null; then
    cpupower frequency-set -g performance
else
    if [ -d /sys/devices/system/cpu ]; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            [ -f "\$cpu" ] && echo "performance" > "\$cpu"
        done
    fi
fi
sysctl -w net.core.default_qdisc=fq
sysctl -w net.ipv4.tcp_congestion_control=bbr
EOF
chmod +x /usr/local/bin/javelin-opt.sh

# 5. Inject into rc.local
if [ ! -f /etc/rc.local ]; then
    echo '#!/bin/sh -e' > /etc/rc.local
    echo 'exit 0' >> /etc/rc.local
    chmod +x /etc/rc.local
fi
if ! grep -q "javelin-opt.sh" /etc/rc.local; then
    sed -i '/exit 0/i /usr/local/bin/javelin-opt.sh' /etc/rc.local
fi

echo "---------------------------------------------------"
echo "DONE. Reboot and enjoy the Lean Javelin."
echo "---------------------------------------------------"