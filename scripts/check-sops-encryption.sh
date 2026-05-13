#!/bin/bash
set -euo pipefail

EXIT_CODE=0

for file in "$@"; do
  # Skip non-existent files (deleted files)
  if [ ! -f "$file" ]; then
    continue
  fi

  # Check if the file should be encrypted (matches secret-related patterns)
  if echo "$file" | grep -qiE '(secret|credential|token|key|password)'; then
    # Check if the file contains SOPS metadata
    if ! grep -q "sops:" "$file" || ! grep -q "ENC\[AES256_GCM" "$file"; then
      echo "ERROR: $file appears to contain secrets but is not SOPS-encrypted!"
      echo "       Run: sops --encrypt --in-place $file"
      EXIT_CODE=1
    fi
  fi
done

exit $EXIT_CODE
