#!/bin/sh
# gts7 masaustu kisayollarini olusturur (~/Desktop). Kullanici olarak calistir.
D="$HOME/Desktop"; mkdir -p "$D"
mklaunch(){ f="$D/$1.desktop"; cat > "$f" <<DESK
[Desktop Entry]
Version=1.0
Type=Application
Name=$2
Comment=$3
Exec=$4
Icon=$5
Terminal=false
Categories=System;Security;Network;
DESK
chmod +x "$f"; }
mklaunch "sec-toolkit"   "Guvenlik Toolkit"    "Tum guvenlik araclari + menu" \
  "xfce4-terminal --title=Guvenlik-Toolkit -e \"$HOME/.local/bin/sec-toolkit.sh\"" "security-high"
mklaunch "sec-nmap"      "Nmap Tarama"         "Ag/port tarama (nmap)" \
  "xfce4-terminal --title=nmap -e \"bash -c 'echo Ornek: sudo nmap -sS -sV 192.168.1.0/24; nmap --version; exec bash'\"" "network-workgroup"
mklaunch "sec-bettercap" "Bettercap (LAN/BLE)" "LAN MITM + Bluetooth LE kesif" \
  "xfce4-terminal --title=bettercap -e \"bash -c 'echo LAN: sudo bettercap -iface wlan0; exec bash'\"" "network-wired"
mklaunch "sec-wireshark" "Wireshark"           "Paket yakalama/analiz (GUI)" "wireshark" "wireshark"
mklaunch "sec-wavemon"   "WiFi Monitor"        "WiFi sinyal/kanal izleme" \
  "xfce4-terminal --title=wavemon -e \"wavemon\"" "network-wireless"
mklaunch "sec-bluetooth" "Bluetooth Tara"      "BLE/Bluetooth cihaz tarama" \
  "xfce4-terminal --title=bluetooth -e \"bash -c 'bluetoothctl; exec bash'\"" "bluetooth"
mklaunch "perfmode"      "Performans Modu"     "CPU/GPU performans ac/kapa/durum" \
  "xfce4-terminal --title=Performans-Modu -e \"bash -c 'echo [1]AC [2]KAPA [3]DURUM; read -p Secim: s; case \\$s in 1) $HOME/.local/bin/perfmode.sh on;; 2) $HOME/.local/bin/perfmode.sh off;; *) $HOME/.local/bin/perfmode.sh status;; esac; exec bash'\"" "cpu"
mklaunch "GUVENLIK-REHBERI" "Guvenlik & Tweak Rehberi" "Turkce kullanim rehberi" \
  "exo-open $HOME/Desktop/GUVENLIK-REHBERI.html" "text-html"
echo "kisayollar olusturuldu: $D"
