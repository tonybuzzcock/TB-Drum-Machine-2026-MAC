#!/bin/bash
# Builds "TB Drum Machine.app" (stand-alone) for current Macs: universal
# (Apple Silicon arm64 + Intel x86_64), macOS 11 and later, ad-hoc signed.
# Fails unless both architectures are in the binary and it declares macOS 11.0.
#
#   scripts/build_app_mac.sh   -> "build/TB Drum Machine.app", build/TB-Drum-Machine-mac.zip

set -euo pipefail

cd "$(dirname "$0")/.."
OUT=build
NAME="TB Drum Machine"
EXE=TBDrumMachine
ZIP=TB-Drum-Machine-mac.zip
BUNDLE="$OUT/$NAME.app"
MIN_OS=11.0

rm -rf "$BUNDLE" "$OUT/$ZIP" "$OUT/package"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
printf 'APPLTBdm' > "$BUNDLE/Contents/PkgInfo"
if [ -f "$OUT/TBDrumMachine.icns" ]; then cp "$OUT/TBDrumMachine.icns" "$BUNDLE/Contents/Resources/"; fi

echo "== Toolchain"
xcrun clang++ --version | head -1
echo "SDK $(xcrun --show-sdk-version) at $(xcrun --show-sdk-path)"

echo "== Compiling (universal arm64 + x86_64, minimum macOS $MIN_OS)"
xcrun clang++ -arch arm64 -arch x86_64 -mmacosx-version-min=$MIN_OS \
    -std=c++17 -stdlib=libc++ -O2 -Wall -Wextra -Wno-deprecated-declarations \
    -fno-objc-arc -Werror=unguarded-availability -Werror=unguarded-availability-new \
    -framework Cocoa -framework AudioUnit -framework AudioToolbox -framework CoreAudio -framework CoreMIDI \
    Source/Engine/Engine.cpp Source/Engine/Wav.cpp Source/Engine/Export.cpp Source/Engine/Master.cpp \
    Source/App/MainView.mm Source/App/main.mm \
    -o "$BUNDLE/Contents/MacOS/$EXE"

BIN="$BUNDLE/Contents/MacOS/$EXE"

echo "== Verifying"
lipo -info "$BIN"
ARCHS=$(lipo -archs "$BIN")
for a in arm64 x86_64; do
    if ! echo "$ARCHS" | grep -qw "$a"; then echo "::error::$a slice missing (have: $ARCHS)"; exit 1; fi
done
for a in arm64 x86_64; do
    M=$(vtool -arch "$a" -show-build "$BIN" 2>/dev/null | awk '/minos/{print $2; exit}')
    echo "$a minos: ${M:-unknown}"
    if [ "$M" != "$MIN_OS" ]; then echo "::error::$a declares minimum macOS '${M:-unknown}', expected $MIN_OS"; exit 1; fi
done
echo "::notice::$NAME.app is universal (arm64 + x86_64), minimum macOS $MIN_OS"
otool -L "$BIN" | tail -n +2

echo "== Signing (ad-hoc: no Apple Developer account)"
codesign --force --deep --sign - "$BUNDLE"
codesign -v --deep --strict "$BUNDLE"
codesign -dv "$BUNDLE" 2>&1 | head -5

echo "== Packaging"
mkdir -p "$OUT/package/TB-Drum-Machine-mac"
ditto "$BUNDLE" "$OUT/package/TB-Drum-Machine-mac/$NAME.app"
cp INSTALL.txt "$OUT/package/TB-Drum-Machine-mac/"
(cd "$OUT/package" && ditto -c -k --keepParent "TB-Drum-Machine-mac" "../$ZIP")
ls -la "$OUT"
echo "Built $BUNDLE"
