#!/bin/sh
OUT=/mnt/us/extensions/LunarPanel/diagnostics.txt
{
  echo 'Lunar Panel diagnostics v1'
  date
  echo '--- screen ---'
  /mnt/us/libkh/bin/fbink -e 2>&1
  echo '--- fbink features ---'
  /mnt/us/libkh/bin/fbink --help 2>&1
  echo '--- tools ---'
  for tool in curl wget python python3 lua luajit jq eips lipc-set-prop; do
    command -v "$tool" 2>/dev/null || :
  done
  echo '--- fonts ---'
  ls /usr/java/lib/fonts/*[Cc][Jj][Kk]* /usr/java/lib/fonts/*[Cc]hinese* /mnt/us/fonts/* 2>/dev/null || :
  echo '--- complete ---'
} > "$OUT" 2>&1
