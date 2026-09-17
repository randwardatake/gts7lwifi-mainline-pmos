#!/bin/sh
clear
cat <<'BANNER'
============================================================
  gts7 GUVENLIK TOOLKIT
  ! SADECE kendi aginda / yazili izinli sistemlerde kullan !
============================================================
 Ag tarama    : nmap  arp-scan  masscan
 Trafik       : wireshark  tshark  tcpdump
 LAN MITM     : bettercap  ettercap
 Bluetooth/BLE: bluetoothctl  hcitool  (bettercap ble.recon)
 WiFi izleme  : wavemon  iw
 Sifre/hash   : hashcat  john  hydra
 Yardimci     : macchanger  nftables
------------------------------------------------------------
 Ornekler icin: masaustundeki  GUVENLIK-REHBERI.html
 Deauth/injection: dahili ath11k YAPAMAZ (harici AR9271 gerekir)
============================================================
BANNER
exec bash
