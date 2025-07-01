#!/bin/bash
set -e

ARCH="armeabi-v7a"
APK_NAME="iceraven-latest.apk"
PATCHED_APK="iceraven-patched.apk"
SIGNED_APK="iceraven-patched-signed.apk"

echo "[+] Downloading latest Iceraven release for $ARCH..."

# Fetch latest release info & get APK URL matching armeabi-v7a
APK_URL=$(curl -s https://api.github.com/repos/fork-maintainers/iceraven-browser/releases/latest \
  | jq -r '.assets[] | select(.name | endswith("-'"$ARCH"'-forkRelease.apk")) | .browser_download_url')

echo "APK URL: $APK_URL"

wget -q "$APK_URL" -O "$APK_NAME"

echo "[+] Downloading apktool..."
wget -q https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_2.11.1.jar -O apktool.jar

echo "[+] Cleaning previous build..."
rm -rf iceraven-patched "$PATCHED_APK" "$SIGNED_APK"

echo "[+] Decompiling APK..."
java -jar apktool.jar d "$APK_NAME" -o iceraven-patched
rm -rf iceraven-patched/META-INF

echo "[+] Patching colors..."
sed -i 's/<color name="fx_mobile_layer_color_1">.*/<color name="fx_mobile_layer_color_1">#ff000000<\/color>/g' iceraven-patched/res/values-night/colors.xml
sed -i 's/<color name="fx_mobile_layer_color_2">.*/<color name="fx_mobile_layer_color_2">@color\/photonDarkGrey90<\/color>/g' iceraven-patched/res/values-night/colors.xml
sed -i 's/<color name="fx_mobile_action_color_secondary">.*/<color name="fx_mobile_action_color_secondary">#ff25242b<\/color>/g' iceraven-patched/res/values-night/colors.xml
sed -i 's/<color name="button_material_dark">.*/<color name="button_material_dark">#ff25242b<\/color>/g' iceraven-patched/res/values/colors.xml
sed -i 's/1c1b22/000000/g' iceraven-patched/assets/extensions/readerview/readerview.css
sed -i 's/eeeeee/e3e3e3/g' iceraven-patched/assets/extensions/readerview/readerview.css

echo "[+] Patching smali colors..."
sed -i 's/ff1c1b22/ff000000/g' iceraven-patched/smali*/mozilla/components/ui/colors/PhotonColors.smali || true
sed -i 's/ff2b2a33/ff000000/g' iceraven-patched/smali*/mozilla/components/ui/colors/PhotonColors.smali || true
sed -i 's/ff42414d/ff15141a/g' iceraven-patched/smali*/mozilla/components/ui/colors/PhotonColors.smali || true
sed -i 's/ff52525e/ff25232e/g' iceraven-patched/smali*/mozilla/components/ui/colors/PhotonColors.smali || true
sed -i 's/ff5b5b66/ff2d2b38/g' iceraven-patched/smali*/mozilla/components/ui/colors/PhotonColors.smali || true

echo "[+] Rebuilding patched APK..."
java -jar apktool.jar b iceraven-patched -o "$PATCHED_APK" --use-aapt2

echo "[+] Aligning APK..."
zipalign -f 4 "$PATCHED_APK" "$SIGNED_APK"

# Sign with debug key
if [ ! -f ../debug.keystore ]; then
  echo "[+] Generating debug keystore..."
  keytool -genkey -v -keystore ../debug.keystore -storepass android -alias androiddebugkey -keypass android \
    -dname "CN=Android Debug,O=Android,C=US" -keyalg RSA -keysize 2048 -validity 10000
fi

echo "[+] Signing APK..."
apksigner sign --ks ../debug.keystore --ks-pass pass:android "$SIGNED_APK"

echo "[✅] Done! Final APK: $SIGNED_APK"
