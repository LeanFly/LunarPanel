#!/bin/sh
OUT=/mnt/us/extensions/LunarPanel/remote-check.txt
{
  echo 'Remote access diagnostics'
  date
  echo '--- network addresses ---'
  /sbin/ifconfig wlan0 2>&1 || :
  echo '--- SSH and transfer tools ---'
  for tool in dropbear dropbearkey sshd ssh scp sftp-server busybox iptables; do
    command -v "$tool" 2>/dev/null || :
  done
  for file in /usr/sbin/dropbear /usr/bin/dropbear /usr/sbin/sshd /usr/libexec/sftp-server /mnt/us/usbnet/bin/dropbear; do
    [ ! -f "$file" ] || ls -l "$file"
  done
  echo '--- current listeners ---'
  netstat -lnt 2>&1 || :
  echo '--- complete ---'
} > "$OUT" 2>&1
