#!/bin/bash

echo "🔍 Scanning node_modules for suspicious patterns..."

TARGET_DIR="node_modules"

if [ ! -d "$TARGET_DIR" ]; then
  echo "❌ node_modules not found!"
  exit 1
fi

echo "----------------------------------------"
echo "1. Searching for eval + base64 patterns..."
grep -RIn --exclude-dir=.bin "eval(Buffer.from" $TARGET_DIR

echo "----------------------------------------"
echo "2. Searching for suspicious postinstall scripts..."
grep -RIn "postinstall" $TARGET_DIR/*/package.json

echo "----------------------------------------"
echo "3. Searching for obfuscated long strings..."
#grep -RInE '[A-Za-z0-9+/]{200,}={0,2}' $TARGET_DIR | head -n 20

echo "----------------------------------------"
echo "4. Searching for external network calls..."
grep -RInE "http://|https://|fetch\(|axios\(" $TARGET_DIR | grep -v "node_modules/.bin" | head -n 30

echo "----------------------------------------"
echo "5. Searching for suspicious unicode/invisible chars..."
#grep -RInP "[\x{200B}-\x{200F}\x{202A}-\x{202E}]" $TARGET_DIR

echo "----------------------------------------"
echo "6. Recently modified files (last 7 days)..."
find $TARGET_DIR -type f -mtime -7

echo "----------------------------------------"
echo "✅ Scan complete. Review findings carefully."
root@ip-172-31-94-34:/home/admin#