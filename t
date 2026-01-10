sudo groupadd -f nopasswdlogin
sudo usermod -aG nopasswdlogin rebsijo
sudo systemctl restart lightdm
