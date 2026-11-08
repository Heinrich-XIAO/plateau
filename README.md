# video-grey

Turns the macOS greyscale color filter on while video is playing, and off shortly after it stops. Audio-only playback is ignored.

## Install

    ./install.sh

Runs at login as a LaunchAgent (`com.user.video-grey`). Remove with `./install.sh uninstall`.

## How it works

Video players hold a `PreventUserIdleDisplaySleep` power assertion during playback; audio-only playback holds only system-sleep assertions. The daemon polls those assertions once a second and toggles the greyscale category of `MediaAccessibility` (`MADisplayFilterPrefSetCategoryEnabled`, category 1).
