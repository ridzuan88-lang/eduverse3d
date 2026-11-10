#!/usr/bin/env bash
# Menyediakan Godot export templates + Android SDK/JDK + debug keystore dalam imej barichello/godot-ci
set -e
GV="${GODOT_VERSION:-4.3}"
mkdir -p ~/.local/share/godot/export_templates ~/.config/godot build
SRC="/root/.local/share/godot/export_templates/${GV}.stable"
DST="$HOME/.local/share/godot/export_templates/${GV}.stable"
if [ -d "$SRC" ] && [ "$SRC" != "$DST" ]; then cp -r "$SRC" "$DST"; fi
[ -d "$DST" ] || { echo "RALAT: export templates Godot ${GV} tiada"; exit 1; }

SDK=""
for c in "$ANDROID_HOME" "$ANDROID_SDK_ROOT" /usr/lib/android-sdk /opt/android-sdk /root/android-sdk /usr/local/lib/android/sdk; do
  if [ -n "$c" ] && [ -d "$c" ]; then SDK="$c"; break; fi
done
[ -n "$SDK" ] || { echo "RALAT: Android SDK tidak dijumpai dalam imej"; exit 1; }
if [ -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
  yes | "$SDK/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1 || true
  "$SDK/cmdline-tools/latest/bin/sdkmanager" "platform-tools" "build-tools;34.0.0" "platforms;android-34" || true
fi
JAVA="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(which javac)")")")}"
[ -d "$JAVA" ] || { echo "RALAT: JDK tidak dijumpai"; exit 1; }
[ -f build/debug.keystore ] || keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore build/debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
for f in editor_settings-4.tres editor_settings-4.3.tres; do
cat > ~/.config/godot/$f <<EOS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JAVA"
export/android/debug_keystore = "$PWD/build/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOS
done
echo "Persediaan CI siap. SDK=$SDK JAVA=$JAVA"
godot --headless --path . --import 2>&1 | tail -n 20 || true
godot --headless --path . --import 2>&1 | tail -n 5 || true
