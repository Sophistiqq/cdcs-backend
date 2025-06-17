#!/bin/sh

# Check for -f flag
show_files_only=false
if [ "$1" = "-f" ]; then
    show_files_only=true
fi

CLIPBOARD_URL="https://cdcs-clipboard-production.up.railway.app/clipboard"
FILES_URL="https://cdcs-clipboard-production.up.railway.app/files"
DOWNLOAD_DIR="$HOME/Downloads/cdcs"

mkdir -p "$DOWNLOAD_DIR"

if [ "$show_files_only" = true ]; then
    # Only show files
    files=$(curl -s "$FILES_URL" 2>/dev/null || echo "[]")
    files_count=$(echo "$files" | jq 'length // 0' 2>/dev/null || echo "0")
    
    if [ "$files_count" -eq 0 ]; then
        echo "❌ No files found."
        exit 1
    fi
    
    # Format file entries
    formatted_files=$(echo "$files" | jq -r '.[] | "[File] \(.name)"' 2>/dev/null)
    
    if [ -z "$formatted_files" ]; then
        echo "❌ No valid files found."
        exit 1
    fi
    
    # Select file
    selected=$(echo "$formatted_files" | fzf --prompt="📁 Select file: " --height=50%)
    
    if [ -z "$selected" ]; then
        echo "❌ Cancelled."
        exit 1
    fi
    
    # Download file
    filename=$(echo "$selected" | sed 's/\[File\] //')
    url="https://cdcs-clipboard-production.up.railway.app/files/$filename"
    
    echo "📥 Downloading $filename..."
    echo "🔗 URL: $url"
    echo "📂 Destination: $DOWNLOAD_DIR/$filename"
    
    # First check if the URL is accessible
    if ! curl -s --head "$url" >/dev/null 2>&1; then
        echo "❌ Cannot reach $url - check if the server is running"
        exit 1
    fi
    
    # Download with verbose error reporting
    if curl -L --fail -o "$DOWNLOAD_DIR/$filename" "$url" 2>/dev/null; then
        if [ -f "$DOWNLOAD_DIR/$filename" ] && [ -s "$DOWNLOAD_DIR/$filename" ]; then
            echo "📁 Downloaded to $DOWNLOAD_DIR/$filename"
        else
            echo "❌ File was created but appears to be empty"
            exit 1
        fi
    else
        echo "❌ Failed to download $filename"
        echo "🔍 Debugging info:"
        echo "   - Check if server is running: curl -I https://cdcs-backend.onrender.com"
        echo "   - Test URL directly: curl -v '$url'"
        exit 1
    fi
    
else
    # Only show clipboard texts with preview
    clipboard=$(curl -s "$CLIPBOARD_URL" 2>/dev/null || echo "[]")
    clipboard_count=$(echo "$clipboard" | jq 'length // 0' 2>/dev/null || echo "0")
    
    if [ "$clipboard_count" -eq 0 ]; then
        echo "❌ No clipboard entries found."
        exit 1
    fi
    
    # Format clipboard entries with preview
    formatted_clipboard=$(echo "$clipboard" | jq -r '
        .[] | select(.text) | 
        "[Clipboard] \(.time | todateiso8601) | \(.text | gsub("\n"; " ") | .[0:60])..."
    ' 2>/dev/null)
    
    if [ -z "$formatted_clipboard" ]; then
        echo "❌ No valid clipboard entries found."
        exit 1
    fi
    
    # Select clipboard entry with preview
    selected=$(echo "$formatted_clipboard" | fzf \
        --prompt="📋 Select clipboard entry: " \
        --preview='
            timestamp=$(echo {} | cut -d"|" -f2 | cut -d"|" -f1 | xargs)
            echo "📋 CLIPBOARD PREVIEW"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🕒 Time: $timestamp"
            echo ""
            echo "📝 Full text:"
            echo "'"$clipboard"'" | jq -r --arg ts "$timestamp" ".[] | select((.time | todateiso8601) == \$ts) | .text // \"Preview not available\""
        ' \
        --preview-window="right:60%:wrap" \
        --height=80%)
    
    if [ -z "$selected" ]; then
        echo "❌ Cancelled."
        exit 1
    fi
    
    # Copy to clipboard
    timestamp=$(echo "$selected" | cut -d'|' -f2 | cut -d'|' -f1 | xargs)
    text=$(echo "$clipboard" | jq -r --arg ts "$timestamp" '.[] | select((.time | todateiso8601) == $ts) | .text')
    
    if command -v wl-copy >/dev/null 2>&1; then
        echo -n "$text" | wl-copy
        echo "📋 Copied to clipboard using wl-copy!"
    elif command -v xclip >/dev/null 2>&1; then
        echo -n "$text" | xclip -selection clipboard
        echo "📋 Copied to clipboard using xclip!"
    elif command -v pbcopy >/dev/null 2>&1; then
        echo -n "$text" | pbcopy
        echo "📋 Copied to clipboard using pbcopy!"
    else
        echo "📋 Text retrieved:"
        echo "$text"
        echo ""
        echo "⚠️  No clipboard utility found (wl-copy, xclip, or pbcopy)"
    fi
fi
