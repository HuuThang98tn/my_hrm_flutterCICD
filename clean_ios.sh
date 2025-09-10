echo "Cleaning Flutter & iOS build environment..."
flutter clean

rm -rf ios/Pods
rm -rf ios/Podfile.lock

# Xóa DerivedData của Xcode
rm -rf ~/Library/Developer/Xcode/DerivedData

flutter pub get

cd ios || exit
pod install
cd ..

echo "Clean completed! Now try: flutter run"

#//./clean_ios.sh
