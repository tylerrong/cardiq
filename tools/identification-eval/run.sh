#!/bin/bash
# Offline card-identification eval: runs real card images through the app's
# actual OCR + matching pipeline (compiled from the app sources) against the
# shipped catalog seeds, and reports top-1 accuracy.
#
# Usage: ./run.sh   (from this directory; macOS with Xcode CLT)
set -euo pipefail
cd "$(dirname "$0")"
REPO="$(cd ../.. && pwd)"

mkdir -p /tmp/cardiq-eval
cp manifest.json /tmp/cardiq-eval/
python3 - <<'PY'
import json, subprocess, os
m = json.load(open("/tmp/cardiq-eval/manifest.json"))
for c in m:
    out = f"/tmp/cardiq-eval/{c['id'].replace('/','_')}.png"
    if not os.path.exists(out):
        subprocess.run(["curl", "-sf", "--max-time", "30", "-o", out, c["url"]], check=True)
print("images ready:", len(m))
PY

swiftc -parse-as-library -O -o /tmp/cardiq-eval/cardiq-eval \
  "$REPO/CardIQ/Core/CIQError.swift" \
  "$REPO/CardIQ/Models/CardModels.swift" \
  "$REPO/CardIQ/Models/MarketModels.swift" \
  "$REPO/CardIQ/Services/Live/PokemonTCGCardIdentificationService.swift" \
  "$REPO/CardIQ/Services/Live/CardCatalogStore.swift" \
  shim.swift eval-main.swift

/tmp/cardiq-eval/cardiq-eval
