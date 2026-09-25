#!/usr/bin/env bash
# ============================================================================
# rebuild_apks.sh — régénère les 3 APK pays (CIV, TUN, SEN) après une modif.
# Usage : bash rebuild_apks.sh   (depuis le dossier du projet civapk)
#   - flutter clean OBLIGATOIRE (bug de cache incrémental Flutter connu)
#   - build les 3 flavors en release
#   - copie + renomme dans un dossier de livraison daté + SHA256SUMS
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"

OUT="build/app/outputs/flutter-apk"
DIST="$HOME/Travail/netconsulting/apk-livraison-$(date +%Y%m%d)"
mkdir -p "$DIST"

echo "== flutter clean + pub get =="
flutter clean
flutter pub get

# flavor -> nom de fichier livrable
names_cotedivoire="CoteIvoire"; names_tunisie="Tunisie"; names_senegal="Senegal"

for f in cotedivoire tunisie senegal; do
  echo "== build $f =="
  flutter build apk --flavor "$f" -t "lib/main_$f.dart" --release
  var="names_$f"; nice="${!var}"
  cp "$OUT/app-$f-release.apk" "$DIST/Codeonline-$nice-1.0.1.apk"
done

cd "$DIST"
shasum -a 256 *.apk | tee SHA256SUMS.txt
echo ""
echo "✅ 3 APK régénérés dans : $DIST"
