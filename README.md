# README #

### What is this repository for? ###

Subler is an Mac OS X app created to mux and tag mp4 files. The main features includes:

* Creation of tx3g subtitles tracks, compatible with all Apple's devices (iPod, AppleTV, iPhone, QuickTime?).
* Mux video, audio, chapters, subtitles and closed captions tracks from mov, mp4 and mkv.
* Raw formats: H.264 Elementary streams (.h264, .264), AAC (.aac), AC3 (.ac3), Scenarist (.scc), VobSub? (.idx).
* metadata editing and TMDb, TVDB and iTunes Store support.

### Build and run

Clone the repository and include all submodules
```
git clone --recurse-submodules https://github.com/SublerApp/Subler.git
```
If you already cloned without submodules and need to add the submodules manually, `cd` into the `./Subler` directory and clone the dependency submodules with 
```
git submodule update --init --recursive
```
Open `Subler.xcodeproj` in XCode

Build and run the project by selecting the 'Subler' scheme (`Product` -> `Scheme` -> `Subler`) and clicking the 'Run' button in Xcode’s toolbar.


