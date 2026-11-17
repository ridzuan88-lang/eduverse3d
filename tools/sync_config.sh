#!/usr/bin/env bash
# Salin konfigurasi kongsi (klien -> pelayan). Jalankan selepas ubah data/config/*.json
set -e
cd "$(dirname "$0")/.."
mkdir -p server/config
for f in economy safety catalog; do cp "data/config/$f.json" "server/config/$f.json"; done
echo "Konfigurasi disalin ke server/config/"
