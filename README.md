
## Casnic Control

Casnic Control is a hybrid application written in the [Brace](https://github.com/bitsii/beBase) programming language licensed under the [Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/2.0/) - open source license which provides a application for controlling [Brace Embedded](https://github.com/bitsii/beEmb) devices.

Hybrid Mobile Apps are available in the Google Play Store [Casnic Android App](https://play.google.com/store/apps/details?id=casnic.control&gl=US) and the Apple App Store [CasCon IOS App](https://apps.apple.com/us/app/cascon/id6458984046).

Instructions for using the application with your devices are available [here](https://gitlab.com/bitsii/CasCon/-/wikis/home).

## Getting Started

First - quick Getting Started! (more about Casnic Control below...)

Follow Getting Started for beApp recursively :-)  https://gitlab.com/bitsii/beApp

Then (from your shell / git shell on Windows)

git clone https://gitlab.com/bitsii/CasCon.git
cd CasCon
./scripts/devprep.sh

you must checkout in the same parent directory that contains beBase and beApp

### Building on desktop

Should work on Linux, Windows, and Mac.  Really only tested on Linux.

from in the project directory (CasCon) command line in a shell (git shell windows) run

../beApp/scripts/bldrunwajv.sh

(runs it too)

that's it

### Building for IPhone

To build on a mac with XCode 15 installed, from your shell in the CasCon directory, run
../beApp/scripts/bldbaapwk.sh

which will create and generate code into ios/CasCon/ directory.  The first time around, you'll need to copy
the two .swift files from system/ios to ios/CasCon/CasCon

Then follow this recipe to get your IOS app dev env going

ios new app (Xcode 15)
   new project
   ios (default) App
   Storyboard
   Swift
   Project name CasCon
   Directory to create the project is the dev dir (CasCon) /ios
   target ios ver 13.0 (for now)

   For the below "Appname" is CasCon
 in project navigator (folder) right click second level down Appname and choose "add files to Appname" leave the create groups et all defaults navigate up to the ios/Appname/resources dir and pick the App dir to add and let it go, should result in App added to project at that level with the Appname inside it
   bring over AppDelegate.swift and ViewController.swift from system/ios
   Add files to Appname (one level down from top), uncheck copy files, change to folder reference, navigate up and down to resources, choose app folder inside resources.
   copy over info.plist contents from system/ios into your info.plist (maybe the file itself will work)

Then build it and run.  It will run in the simulator but isn't very useful there, recommendation is to test and run on a physical device.

### Building for Android phone

On a machine with Android Studio Squirrel installed (tested on Ubuntu 22.04, should work on others/Windows/Mac too)

android new app (squirril)
    New project, empty activity
    give it a name and package name - high level proj . appname
    Workspace/appname/android/appname (with directory empty)
    java (not kotlin)
    min sdk 21 target sdk 33
    not sure about legacy support, didn't check it
    finish
    authless stuff
    android system webview must be updated

bring over settings/contents of the files in system/android into the versions of the files in your project.  MainActivity.java should replace the generated one, match up settings from the android manifest and build.gradle into the generated ones.

from in the project directory (CasCon) command line in a shell (git shell windows) run

../beApp/scripts/bldbajvad.sh

then build the project in your android studio, run on device (likely won't work in emulator)

## End of Getting Started!

## Be Careful

Use of this information and the software is entirely at your own risk.  As with any interaction between software and something "acting in the real world" or "running electricity around", be sure system failure or unexpected behavior cannot result in harm or injury to anyone.

## Credits

The official list of Casnic Control Authors:

Craig Welch <bitsiiway@gmail.com>
