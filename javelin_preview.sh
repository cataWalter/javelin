#!/bin/bash

# JAVELIN PREVIEW (AUTO-LOGIN & KERNEL SELECT EDITION)
# ----------------------------------------------------
# 1. Installs Javelin (Lean).
# 2. Sets Auto-Login for the main user.
# 3. Forces Liquorix Kernel at boot.

# --- CHECK ROOT ---
if [ "$(id -u)" -ne 0 ]; then
   echo "Run as root: su -"
   exit 1
fi

# --- DETECT REAL USER ---
# We assume the first user in /home is your main user (e.g., walter)
TARGET_USER=$(ls /home | head -n 1)
if [ -z "$TARGET_USER" ]; then
    echo "Could not detect a user in /home. Exiting."
    exit 1
fi
echo ">>> Target User Detected: $TARGET_USER"

echo ">>> [1/5] Updating Repos..."
apt-get update

echo ">>> [2/5] Installing Minimal Package List..."
# Added grub-common to ensure we can manage boot settings
apt-get install -y --no-install-recommends \
    linux-image-liquorix-amd64 linux-headers-liquorix-amd64 \
    icewm icewm-common slim lxappearance nitrogen dunst numlockx \
    thunar thunar-volman thunar-archive-plugin gvfs-backends gvfs-fuse tumbler \
    kitty chromium chromium-l10n qbittorrent mpv viewnior geany gparted synaptic \
    linux-cpupower msr-tools lm-sensors htop fastfetch curl wget \
    dbus-x11 ca-certificates xorg xserver-xorg-video-all grub-common

if [ $? -ne 0 ]; then
    echo "!!! ERROR: Installation failed."
    exit 1
fi

echo ">>> [3/5] Configuring Auto-Login (Slim & IceWM)..."

# 1. Configure Slim for Auto-Login
# Back up original config
cp /etc/slim.conf /etc/slim.conf.bak
# Set default user
sed -i "s/^#default_user.*/default_user        $TARGET_USER/" /etc/slim.conf
# Enable auto_login
sed -i "s/^#auto_login.*/auto_login          yes/" /etc/slim.conf

# 2. Force IceWM Session for the user
# We create a .xinitrc file which tells the system "Start IceWM immediately"
echo "exec icewm-session" > /home/$TARGET_USER/.xinitrc
chown $TARGET_USER:$TARGET_USER /home/$TARGET_USER/.xinitrc

echo ">>> [4/5] Configuring Bootloader (Force Liquorix)..."

# 1. Update GRUB to see the new kernel
update-grub

# 2. Find the specific GRUB Entry ID for Liquorix
# We look for the menu entry that contains "liquorix"
LIQUORIX_ENTRY=$(grep -m1 "with Linux .*liquorix" /boot/grub/grub.cfg | awk -F"'" '{print $2}')

if [ -n "$LIQUORIX_ENTRY" ]; then
    echo "Found Liquorix Entry: $LIQUORIX_ENTRY"
    
    # 3. Configure /etc/default/grub to allow saving the default
    sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/' /etc/default/grub
    if ! grep -q "GRUB_SAVEDEFAULT=true" /etc/default/grub; then
        echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
    fi
    
    # 4. Apply changes and set the default
    update-grub
    grub-set-default "$LIQUORIX_ENTRY"
    echo ">>> Bootloader locked to Liquorix Kernel."
else
    echo "!!! WARNING: Could not find Liquorix kernel in GRUB. It will default to the newest installed kernel."
fi

echo ">>> [5/5] Applying Visuals & Optimization..."

# Visuals (Kitty, etc)
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

# Defaults
update-alternatives --set x-terminal-emulator /usr/bin/kitty
update-alternatives --set x-www-browser /usr/bin/chromium
update-alternatives --set gnome-www-browser /usr/bin/chromium

# Optimization Script
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
echo "DONE. When you reboot:"
echo "1. It will auto-boot the Liquorix Kernel."
echo "2. It will auto-login user '$TARGET_USER' into IceWM."
echo "---------------------------------------------------"