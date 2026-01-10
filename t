sudo grep -nE "^\((EE)\)" /var/log/Xorg.0.log
sudo grep -nEi "fatal|no screens|segfault|failed|cannot open|permission denied" /var/log/Xorg.0.log | tail -n 80
