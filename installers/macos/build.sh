security find-identity -p codesigning

codesign --force --sign "ABCDE_IDENTITY" --deep build/macos/Build/Products/Release/whistle.app

codesign --force --sign  --deep build/macos/Build/Products/Release/whistle.app
 
 appdmg ./installers/macos/config.json ./build/macos/Whistle.dmg
 