# SmartSkate

IoT capstone project, SNU 2026-2.

A camera stand and wrist controller for practicing figure skating alone. The iPhone sits on a motorized stand that turns to keep me in frame, and a wristband with buttons controls my practice music. The video keeps recording the whole time, and the app logs every music change so I can replay any attempt with the music I was actually hearing.

## Parts

- iPhone 16 Pro Max: camera, tracking (Apple Vision), recording, music to AirPods
- ESP32-S3: drives the pan motor, talks to the phone over BLE
- Wristband: small BLE board with buttons
- HUSKYLENS PRO + SG90 servo: bench prototype only, to test the sensor to motor chain early

## Folders

```
ios-app/              iPhone app (Xcode)
firmware/
  huskylens-serial/   week 1: read HUSKYLENS on the ESP32
  servo-follow/       week 2: servo follows the HUSKYLENS target
  ble-range-test/     week 2: BLE beacon for the rink range test
docs/                 project plan, decision gates
logs/                 one file per test
```

## Status

Weeks 1-2 in progress. See the project board.

## Test logs

Every test gets its own file in `logs/`, named like `2026-11-24-ios-record-music.md`, using `logs/TEMPLATE.md`. Failed tests get logged too.
