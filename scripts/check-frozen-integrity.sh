#!/bin/bash
# Run before/after any CAIPE work to confirm frozen areas untouched

set -e
LATEST_FROZEN=$(ls -t ~/idp-backstage-frozen-*.tar.gz | head -1)
echo "Comparing against: $LATEST_FROZEN"
echo ""

echo "=== Tracked repo: uncommitted changes ==="
git status --short
echo ""

echo "=== Backstage runtime: file list diff vs frozen snapshot ==="
diff <(tar -tzf "$LATEST_FROZEN" | sort) \
     <(cd infrastructure/backstage && find . -type f 2>/dev/null | sed 's|^\./|infrastructure/backstage/|' | sort) \
  && echo "✅ No files added/removed in infrastructure/backstage since freeze" \
  || echo "⚠️  File list differs — review above output"
echo ""

echo "=== Specific critical files: content diff ==="
for f in app-config.yaml packages/backend/src/plugins/permission-policy.ts; do
  echo "--- $f ---"
  diff <(tar -xzf "$LATEST_FROZEN" "infrastructure/backstage/$f" -O 2>/dev/null) \
       "infrastructure/backstage/$f" \
    && echo "✅ unchanged" || echo "⚠️  CHANGED — review diff above"
done
