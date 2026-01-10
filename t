sudo adduser rebsijo
sudo usermod -aG sudo rebsijo
sudo -iu rebsijo bash -lc '
vncserver >/dev/null 2>&1
vncserver -kill :1 >/dev/null 2>&1
mkdir -p ~/.vnc
cat > ~/.vnc/xstartup <<EOF
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
chmod +x ~/.vnc/xstartup
vncserver :1
'
