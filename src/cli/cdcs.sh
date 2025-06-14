#!/bin/sh

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
formatted_clipboard=""
if [ "$clipboard_count" -gt 0 ]; then
  formatted_clipboard=$(echo "$clipboard" | jq -r '
    .[] | select(.text) | "[Clipboard] \(.time | todateiso8601) | \(.text | gsub("\n"; " ") | .[0:80])"
  ')
fi

# Format file entries - fix the structure based on your API response
formatted_files=""
if [ "$files_count" -gt 0 ] && [ "$files" != "[]" ]; then
  formatted_files=$(echo "$files" | jq -r '
    .[] | "[File] \(.name)"
  ')
fi

# Combine (handle empty strings properly)
combined=""
if [ -n "$formatted_clipboard" ] && [ -n "$formatted_files" ]; then
  combined=$(printf "%s\n%s" "$formatted_clipboard" "$formatted_files")
elif [ -n "$formatted_clipboard" ]; then
  combined="$formatted_clipboard"
elif [ -n "$formatted_files" ]; then
  combined="$formatted_files"
fi

if [ -z "$combined" ]; then
  echo "❌ No valid entries found."
  exit 1
fi

# Create a better UI with two panes using fzf preview
selected=$(echo "$combined" | fzf \
  --prompt="📋 Select item: " \
  --header="📁 Files | 📋 Clipboard" \
  --preview-window="right:50%:wrap" \
  --preview='
    if echo {} | grep -q "^\[File\]"; then
      filename=$(echo {} | sed "s/\[File\] //")
      echo "📁 FILE: $filename"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "📊 File information will be downloaded to:"
      echo "   ~/Downloads/cdcs/$filename"
      echo ""
      echo "💡 Press ENTER to download this file"
    else
      timestamp=$(echo {} | cut -d"|" -f1 | sed "s/\[Clipboard\] //g" | tr -d " ")
      echo "📋 CLIPBOARD ENTRY"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "🕒 Time: $timestamp"
      echo ""
      echo "📝 Full text:"
      echo "'"$clipboard"'" | jq -r --arg ts "$timestamp" ".[] | select((.time | todateiso8601) == \$ts) | .text // \"Preview not available\""
      echo ""
      echo "💡 Press ENTER to copy to clipboard"
    fi
  ' \
  --border=rounded \
  --height=80% \
  --color="header:bold:blue,prompt:bold:cyan,border:dim:white"
)

[ -z "$selected" ] && echo "❌ Cancelled." && exit 1

# Handle clipboard
if echo "$selected" | grep -q "^\[Clipboard\]"; then
  timestamp=$(echo "$selected" | cut -d'|' -f1 | sed 's/\[Clipboard\] //g' | xargs)
  text=$(echo "$clipboard" | jq -r --arg ts "$timestamp" '.[] | select((.time | todateiso8601) == $ts) | .text')
  echo -n "$text" | wl-copy
  echo "📋 Copied clipboard text!"
fi

# Handle file - fix the download URL
if echo "$selected" | grep -q "^\[File\]"; then
  filename=$(echo "$selected" | sed 's/\[File\] //')
  # Remove the trailing slash issue and construct proper URL
  url="http://localhost:3000/files/$filename"
  
  echo "📥 Downloading $filename..."
  if curl -s "$url" -o "$DOWNLOAD_DIR/$filename"; then
    echo "📁 Downloaded to $DOWNLOAD_DIR/$filename"
  else
    echo "❌ Failed to download $filename"
    exit 1
  fi
fi
