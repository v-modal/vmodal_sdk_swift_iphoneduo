# StarterIOS

Open `StarterIOS.xcodeproj` with Xcode 26.6. The app consumes the local
`VModalSDK` package, supports compact and split layouts, and keeps each upload
task in its scene-owned `AppSession` so geometry changes cannot duplicate it.

Use `bash build.sh example_ios` for a generic simulator build and
`bash test.sh ios` for the available iPhone simulator acceptance gate.

<!-- FUTURE_IPHONE_DUO_XCODE_27_1
Use `bash build.sh duo_example` for the exact installed iPhone Duo destination.
-->
