#!/bin/bash

CLIPBOARD_URL="http://localhost:3000/clipboard"
FILES_URL="http://localhost:3000/files"
DOWNLOAD_DIR="$HOME/Downloads/cdcs"

mkdir -p "$DOWNLOAD_DIR"

# Fetch clipboard and files
clipboard=$(curl -s "$CLIPBOARD_URL")
files=$(curl -s "$FILES_URL")

clipboard="${clipboard:-[]}"
files="${files:-[]}"

clipboard_count=$(echo "$clipboard" | jq 'length // 0')
files_count=$(echo "$files" | jq 'length // 0')

if [ "$clipboard_count" -eq 0 ] && [ "$files_count" -eq 0 ]; then
  echo "❌ No data found."
  exit 1
fi

# Format clipboard entries
formatted_clipboard=$(echo "$clipboard" | jq -r '
  .[] | select(.text) | "[Clipboard] \(.time | todateiso8601) | \(.text | gsub("\n"; " ") | .[0:80])"
')

# Format file entries
formatted_files=$(echo "$files" | jq -r '
  .[] | "[File] \(.name)"
')

# Combine
combined=$(printf "%s\n%s" "$formatted_clipboard" "$formatted_files")

# Select
selected=$(echo "$combined" | fzf --prompt="Select item: ")

[ -z "$selected" ] && echo "❌ Cancelled." && exit 1

# Handle clipboard
if [[ "$selected" == "[Clipboard]"* ]]; then
  timestamp=$(echo "$selected" | cut -d'|' -f1 | sed 's/\[Clipboard\] //g' | xargs)
  text=$(echo "$clipboard" | jq -r --arg ts "$timestamp" '.[] | select((.time | todateiso8601) == $ts) | .text')
  echo -n "$text" | wl-copy
  echo "📋 Copied clipboard text!"
fi

# Handle file
if [[ "$selected" == "[File]"* ]]; then
  filename=$(echo "$selected" | sed 's/\[File\] //')
  url="${FILES_URL%/}/$filename"
  curl -s "$url" -o "$DOWNLOAD_DIR/$filename"
  echo "📁 Downloaded to $DOWNLOAD_DIR/$filename"
fi
