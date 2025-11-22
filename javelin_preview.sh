#!/bin/bash

# JAVELIN PREVIEW FIXER
# ---------------------
# Fixes package names for Devuan Excalibur/Trixie

if [ "$(id -u)" -ne 0 ]; then
   echo "Run as root: su -"
   exit 1
fi

echo ">>> [1/4] Updating Repos..."
apt-get update

echo ">>> [2/4] Installing Corrected Package List..."
# CHANGES:
# - Removed 'icewm-themes' (included in base now)
# - Replaced 'cpufrequtils' with 'linux-cpupower'
# - Replaced 'neofetch' with 'fastfetch'
# - Added '-y' to force install without asking

apt-get install -y \
    linux-image-liquorix-amd64 linux-headers-liquorix-amd64 \
    icewm icewm-common slim lxappearance nitrogen dunst numlockx \
    thunar thunar-volman thunar-archive-plugin gvfs-backends gvfs-fuse tumbler \
    kitty chromium chromium-l10n qbittorrent mpv viewnior geany gparted synaptic \
    linux-cpupower msr-tools lm-sensors htop fastfetch curl wget

# Check if install succeeded
if [ $? -ne 0 ]; then
    echo "!!! ERROR: Software installation failed again. Check your internet or repos."
    exit 1
fi

echo ">>> [3/4] Re-applying Configs..."

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

echo ">>> [4/4] Installing Optimization Script..."
# Updated to use 'cpupower' instead of 'cpufreq-set'
cat <<EOF > /usr/local/bin/javelin-opt.sh
#!/bin/sh
# JAVELIN CPU OPTIMIZER
# 1. Force Performance (using modern cpupower if available)
if command -v cpupower > /dev/null; then
    cpupower frequency-set -g performance
else
    # Fallback to sysfs
    if [ -d /sys/devices/system/cpu ]; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            [ -f "\$cpu" ] && echo "performance" > "\$cpu"
        done
    fi
fi

# 2. Network Tweaks (BBR)
sysctl -w net.core.default_qdisc=fq
sysctl -w net.ipv4.tcp_congestion_control=bbr
EOF
chmod +x /usr/local/bin/javelin-opt.sh

# Inject into rc.local
if [ ! -f /etc/rc.local ]; then
    echo '#!/bin/sh -e' > /etc/rc.local
    echo 'exit 0' >> /etc/rc.local
    chmod +x /etc/rc.local
fi
if ! grep -q "javelin-opt.sh" /etc/rc.local; then
    sed -i '/exit 0/i /usr/local/bin/javelin-opt.sh' /etc/rc.local
fi

echo "---------------------------------------------------"
echo "SUCCESS! Installation finished."
echo "Reboot now and select IceWM at the login screen."
echo "---------------------------------------------------"