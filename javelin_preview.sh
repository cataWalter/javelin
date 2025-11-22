#!/bin/bash

# JAVELIN PREVIEW INSTALLER
# -------------------------
# Installs the Javelin environment on the CURRENT system
# so you can test the look/feel immediately.

if [ "$(id -u)" -ne 0 ]; then
   echo "Run as root: su -"
   exit 1
fi

echo ">>> [1/5] Adding Liquorix Kernel Repo..."
echo "deb [arch=amd64] https://liquorix.net/debian trixie main" > /etc/apt/sources.list.d/liquorix.list
curl 'https://liquorix.net/liquorix-keyring.gpg' | gpg --dearmor > /etc/apt/trusted.gpg.d/liquorix.gpg
apt-get update

echo ">>> [2/5] Installing Javelin Software..."
# We install the apps, drivers, and desktop (Skipping runit-init for safety on a live VM)
apt-get install -y \
    linux-image-liquorix-amd64 linux-headers-liquorix-amd64 \
    icewm icewm-themes slim lxappearance nitrogen dunst numlockx \
    thunar thunar-volman thunar-archive-plugin gvfs-backends gvfs-fuse tumbler \
    kitty chromium chromium-l10n qbittorrent mpv viewnior geany gparted synaptic \
    cpufrequtils msr-tools lm-sensors htop neofetch curl wget

echo ">>> [3/5] Applying Visual Configs..."

# 1. Configure Kitty (Green Hacker Theme)
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
# Restore wallpaper (requires user to pick one first)
nitrogen --restore &
numlockx on &
EOF
chmod +x /etc/icewm/startup

# 3. Set Defaults
update-alternatives --set x-terminal-emulator /usr/bin/kitty
update-alternatives --set x-www-browser /usr/bin/chromium
update-alternatives --set gnome-www-browser /usr/bin/chromium

echo ">>> [4/5] Installing Optimization Script..."
cat <<EOF > /usr/local/bin/javelin-opt.sh
#!/bin/sh
# JAVELIN CPU OPTIMIZER
if [ -d /sys/devices/system/cpu ]; then
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -f "\$cpu" ] && echo "performance" > "\$cpu"
    done
fi
# Network Tweaks (BBR)
sysctl -w net.core.default_qdisc=fq
sysctl -w net.ipv4.tcp_congestion_control=bbr
EOF
chmod +x /usr/local/bin/javelin-opt.sh

# Inject into rc.local for boot
if [ ! -f /etc/rc.local ]; then
    echo '#!/bin/sh -e' > /etc/rc.local
    echo 'exit 0' >> /etc/rc.local
    chmod +x /etc/rc.local
fi
if ! grep -q "javelin-opt.sh" /etc/rc.local; then
    sed -i '/exit 0/i /usr/local/bin/javelin-opt.sh' /etc/rc.local
fi

echo ">>> [5/5] Installation Complete."
echo "---------------------------------------------------"
echo "WHAT TO DO NEXT:"
echo "1. Reboot your VM."
echo "2. On the Login Screen (Slim or LightDM), press F1 or select 'IceWM'."
echo "3. Login."
echo "4. Open Kitty (Ctrl+Alt+T isn't bound yet, find it in the menu)."
echo "---------------------------------------------------"