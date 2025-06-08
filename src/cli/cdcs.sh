#!/bin/bash

SERVER_URL="https://cdcs-backend.onrender.com/clipboard"

# Fetch clipboard entries
response=$(curl -s "$SERVER_URL")
count=$(echo "$response" | jq 'length')

if [ "$count" -eq 0 ]; then
  echo "❌ No clipboard entries found."
  exit 1
fi

# Parse flags
latest=false
search_query=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --latest) latest=true ;;
    --search) shift; search_query="$1" ;;
  esac
  shift
done

# Handle --latest
if [ "$latest" = true ]; then
  text=$(echo "$response" | jq -r '.[0].text')
  echo -n "$text" | wl-copy
  echo "📋 Copied latest entry!"
  exit 0
fi

# Filter if --search is used
if [ -n "$search_query" ]; then
response=$(echo "$response" | jq '[.[] | select(has("text") and (.text | type == "string"))]')
fi

# Format entries with timestamp for display
formatted=$(echo "$response" | jq -r '.[] | "\(.time | todateiso8601) | \(.text | gsub("\n"; " ") | .[0:80])"')

# Select with fzf
selected_line=$(echo "$formatted" | fzf --prompt="Select clipboard: ")

[ -z "$selected_line" ] && echo "❌ Cancelled." && exit 1

# Extract original text by matching timestamp
selected_timestamp=$(echo "$selected_line" | cut -d'|' -f1 | xargs)
text=$(echo "$response" | jq -r --arg ts "$selected_timestamp" '.[] | select((.time | todateiso8601) == $ts) | .text')

# Copy to clipboard
echo -n "$text" | wl-copy
echo "📋 Copied!"
