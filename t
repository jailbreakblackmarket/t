# --- 0) Make sure your autologin user exists ---
id rebsijo >/dev/null 2>&1 || sudo adduser rebsijo
sudo usermod -aG sudo rebsijo

# --- 1) Ensure required packages + dbus are present ---
sudo apt update
sudo apt install -y --reinstall \
  lightdm lightdm-gtk-greeter \
  xfce4 xfce4-session xfdesktop4 xfwm4 \
  dbus dbus-x11 dbus-user-session xauth

sudo systemctl enable --now dbus

# --- 2) Fix the PAM rule: do NOT require nopasswdlogin for normal logins ---
# If you accidentally put the nopasswdlogin rule in /etc/pam.d/lightdm, comment it out.
if sudo grep -q "nopasswdlogin" /etc/pam.d/lightdm 2>/dev/null; then
  sudo cp /etc/pam.d/lightdm /etc/pam.d/lightdm.bak.$(date +%F_%H%M%S)
  sudo sed -i 's/^\(.*pam_succeed_if\.so.*nopasswdlogin.*\)$/# \1/' /etc/pam.d/lightdm
fi

# --- 3) Allow passwordless/autologin ONLY for members of nopasswdlogin ---
sudo groupadd -f nopasswdlogin
sudo usermod -aG nopasswdlogin rebsijo

# Put the rule in lightdm-autologin (correct place)
if [ -f /etc/pam.d/lightdm-autologin ] && ! sudo grep -q "nopasswdlogin" /etc/pam.d/lightdm-autologin; then
  sudo cp /etc/pam.d/lightdm-autologin /etc/pam.d/lightdm-autologin.bak.$(date +%F_%H%M%S)
  sudo sed -i '1iauth required pam_succeed_if.so user ingroup nopasswdlogin' /etc/pam.d/lightdm-autologin
fi

# --- 4) Configure LightDM autologin into Xfce ---
sudo mkdir -p /etc/lightdm/lightdm.conf.d
sudo tee /etc/lightdm/lightdm.conf.d/20-autologin.conf >/dev/null <<'EOF'
[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=xfce
autologin-user=rebsijo
autologin-user-timeout=0
EOF

# --- 5) Clear any broken Xfce session config for that user ---
sudo -iu rebsijo rm -rf ~/.cache/sessions ~/.cache/xfce4 ~/.config/xfce4 ~/.local/share/xfce4
sudo -iu rebsijo rm -f ~/.Xauthority ~/.ICEauthority ~/.xsession-errors

# --- 6) Ensure LightDM boots, then reboot ---
sudo systemctl set-default graphical.target
sudo systemctl unmask lightdm 2>/dev/null || true
sudo systemctl enable --now lightdm

sudo reboot
