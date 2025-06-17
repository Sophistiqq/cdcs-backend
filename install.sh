#!/bin/bash

TARGET="/usr/local/bin/cdcs"

mkdir -p "$(dirname "$TARGET")"
cp src/cli/cdcs.sh "$TARGET"
chmod +x "$TARGET"

echo "✅ Installed 'cdcs' to $TARGET"
echo "ℹ️  Make sure ~/.local/bin is in your PATH"
