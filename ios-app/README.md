# iOS app

## What it does so far

- Pick your program music and set sections (A, B, C...) at the points you want to jump to.
- Record one continuous video. Play, pause, repeat or jump to a section while recording; every change is logged.
- Press Mark right after an element. Each mark becomes a short clip (5 s before to 1 s after).
- After practice: watch the session with the music rebuilt from the log.

Coming next: labeling moments, highlights, the element library, wrist buttons, tracking and the motor.

## One-time setup on the Mac

1. Install Xcode from the Mac App Store. It's big, so give it time.
2. Install Homebrew from brew.sh if you don't have it, then run this in Terminal:
   `brew install xcodegen`
3. Get the code:
   `git clone https://github.com/5jseung/smartskate.git`

## Build and run on the iPhone

1. In Terminal:
   ```
   cd smartskate/ios-app
   xcodegen
   open SmartSkate.xcodeproj
   ```
2. In Xcode, click SmartSkate in the left sidebar, open Signing & Capabilities, and choose your Apple ID under Team. If the list is empty, use Add Account.
3. Plug in the iPhone and pick it at the top of the Xcode window. Press Run.
4. The first time only: on the iPhone, turn on Developer Mode (Settings > Privacy & Security > Developer Mode, it restarts), then trust your developer profile (Settings > General > VPN & Device Management).

With a free Apple ID the app stops opening after 7 days. Just press Run again.

Run `xcodegen` again whenever new files are added to the app.

## Week 1 test (#2)

1. Add a song (Songs > +). Put an MP3 or WAV in the Files app first, from AirDrop or iCloud Drive.
2. Add 2 or 3 sections.
3. Connect AirPods, hold the phone sideways (camera on the left), Start practice > Record.
4. Record for 10 minutes. Change the music at least 10 times: pause, play, sections, repeat. Press Mark a few times.
5. Stop. Check that:
   - the recording didn't stop or freeze
   - the music stayed in the AirPods the whole time
   - in the review, the music matches what you heard at each point
   - the video files show up in the Files app under On My iPhone > SmartSkate

Log the result in `logs/` using the template.
