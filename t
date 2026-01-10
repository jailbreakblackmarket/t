sudo systemctl set-default graphical.target
sudo systemctl unmask lightdm 2>/dev/null || true
sudo systemctl enable --now lightdm
