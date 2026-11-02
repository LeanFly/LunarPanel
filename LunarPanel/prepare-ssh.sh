#!/bin/sh
KEY=/var/local/lunarpanel_dropbear_host_ed25519
OUT=/mnt/us/extensions/LunarPanel/ssh-setup.txt
umask 077
{
  echo 'Lunar Panel SSH host setup'
  date
  if [ ! -f "$KEY" ]; then
    /usr/bin/dropbearkey -t ed25519 -f "$KEY" || exit 1
  fi
  /usr/bin/dropbearkey -y -f "$KEY" || exit 1
  echo '--- complete ---'
} > "$OUT" 2>&1
