#!/bin/sh

# First install the server iso as you would normally do, don't select any additional packages besides perhaps ssh. Also make sure to not use "encrypted home directory" cause this render the simple systemd service unusable. After installation continue with the following steps:
/usr/bin/apt update
/usr/bin/apt install -y software-properties-common xorg xserver-xorg-legacy alsa-utils mesa-utils git-core librtmp1 libmad0 lm-sensors libmpeg2-4 avahi-daemon libnfs11 libva2 vainfo i965-va-driver linux-firmware dbus-x11 udisks2 openbox pastebinit udisks2 xserver-xorg-video-intel
/usr/bin/apt -y dist-upgrade

# Allow "everyone" to start the Xserver
/usr/sbin/dpkg-reconfigure xserver-xorg-legacy

# Now edit /etc/X11/Xwrapper.config and add the following into a new line at the end of the file:
/bin/echo >> /etc/X11/Xwrapper.config
/bin/echo "needs_root_rights=yes" >> /etc/X11/Xwrapper.config

# Make sure we use the intel xorg driver (This is only needed on version newer than 16.04, 16.04 uses intel driver by default):
/bin/mkdir -p /etc/X11/xorg.conf.d
/bin/ln -s /usr/share/doc/xserver-xorg-video-intel/xorg.conf /etc/X11/xorg.conf.d/10-intel.conf

# Create the kodi user and it add it the relevant groups. If you have created the kodi user during installation only do the usermod part.
/usr/sbin/adduser kodi
/usr/sbin/usermod -a -G cdrom,audio,video,plugdev,users,dialout,dip,input kodi

# Now we give the permission to shutdown, suspend the computer, therefore create the file /etc/polkit-1/localauthority/50-local.d/custom-actions.pkla with the following content (don't introduce line breaks, especially the Action= line must be exactly one line (especially no linebreaks or auto ".." in freedesktop.login1.*), verify this) - btw. udisks2 will start to work the very moment the PR adding udisks2 support gets merged:
/usr/bin/touch /etc/polkit-1/localauthority/50-local.d/custom-actions.pkla
/bin/cat <<EOT >> /etc/polkit-1/localauthority/50-local.d/custom-actions.pkla
[Actions for kodi user]
Identity=unix-user:kodi
Action=org.freedesktop.login1.*;org.freedesktop.udisks2.*
ResultAny=yes
ResultInactive=yes
ResultActive=yes

[Untrusted Upgrade]
Identity=unix-user:kodi
Action=org.debian.apt.upgrade-packages;org.debian.apt.update-cache
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOT

# We need a simple systemd service file (this one actively waits on network connection, see: network-online.target remove that if you don't need to wait) Create the following file and put the listing into it: /etc/systemd/system/kodi.service
/usr/bin/touch /etc/systemd/system/kodi.service
/bin/cat <<EOT >> /etc/systemd/system/kodi.service
[Unit]
Description = kodi-standalone using xinit
Requires = dbus.service
After = systemd-user-sessions.service sound.target network-online.target

[Service]
User = kodi
Group = kodi
Type = simple
PAMName=login
ExecStart = /usr/bin/xinit /usr/bin/dbus-launch --exit-with-session /usr/bin/openbox-session -- :0 -nolisten tcp vt7
Restart = on-abort

[Install]
WantedBy = multi-user.target
EOT

# edit /etc/security/limits.conf and add before the end. remember kodi is the username, not the application. This will allow your user to get the audio thread a bit more priority.
/bin/echo >> /etc/security/limits.conf
/bin/echo "kodi             -       nice            -1" >> /etc/security/limits.conf

# Fake display-manager.service to not make plymouth or something else complain.
/bin/ln -s /etc/systemd/system/kodi.service /etc/systemd/system/display-manager.service

# Now we install the final Krypton v18 stable version:
/usr/bin/apt-add-repository -y ppa:team-xbmc/ppa
/usr/bin/apt update
/usr/bin/apt -y dist-upgrade
/usr/bin/apt install -y kodi kodi-x11

# As we use openbox as our display manager, we need to auto start kodi, therefore create:
/bin/mkdir -p /home/kodi/.config/openbox
/usr/bin/touch /home/kodi/.config/openbox/autostart
/bin/chown kodi:kodi /home/kodi/.config -R

# now we write the following into the created /home/kodi/.config/openbox/autostart file, this will automatically switch your TV to full range (please copy the lines, don't try to type the '` and so on, this code only works for one (1) connected TV, if you have multiple devices extend it to a loop):
/usr/bin/touch /home/kodi/.config/openbox/autostart
/bin/cat <<EOT >> /home/kodi/.config/openbox/autostart
OUTPUT=`xrandr -display :0 -q | sed '/ connected/!d;s/ .*//;q'`
xrandr -display :0 --output $OUTPUT --set "Broadcast RGB" "Full"
xsetroot #000000
xset s off -dpms
 /usr/bin/kodi --standalone
while [ $? -ne 0 ]; do
 /usr/bin/kodi --standalone
done
openbox --exit
EOT

# Now, we can start kodi:
/bin/systemctl start kodi
