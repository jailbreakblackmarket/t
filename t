sudo mkdir -p /etc/lightdm/lightdm.conf.d
sudo tee /etc/lightdm/lightdm.conf.d/20-autologin.conf >/dev/null <<'EOF'
[Seat:*]
autologin-user=rebsijo
autologin-user-timeout=0
user-session=xfce
EOF

sudo systemctl restart lightdm
