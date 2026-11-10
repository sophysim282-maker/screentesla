# Build 103 (0.20.66)

Continues build 102. A third person asked (through the user) to show the next turn on an
"Orbit Cube" (ESP32-S3) over Bluetooth Low Energy. The user approved this version only
("arrow, distance, road name, minutes"; touch nothing else). An earlier Wi-Fi picture sender for
the same cube was written without approval, never built or sent, and is removed here.

- Maps/CubeLink.swift (new): CoreBluetooth central. Finds the peripheral named "Orbit Cube"
  (or advertising service 1AD64E14-72BE-418D-8C36-08B4F2100F10), connects, and writes with
  response to characteristic …0F13. Packet (little-endian): version 1, maneuver code, uint32
  metres to the turn, uint16 minutes left (0xFFFF unknown), road name UTF-8 up to 32 bytes.
  Sent on every change and at least every 2 s while guiding; code 0 once when guidance stops or
  the switch is turned off. One write at a time. Reconnects by itself. iOS shows the PIN prompt
  on the first encrypted write.
- Maneuver codes from Google Routes names: slight/normal/sharp left 2/3/4, right 5/6/7, U-turn 8,
  roundabout 9, ramp or fork left 10 / right 11, merge 12, arrive 13, everything else 1.
- Road name: Google gives a sentence; the text after "onto" / "on" / "toward" is used when
  present, otherwise the sentence, cut to 32 bytes on a letter boundary. On arrival: the place name.
- Maps Settings: section "Orbit Cube (Bluetooth)" with the switch, status and steps. Off by
  default (UserDefaults `cubeBluetoothOn`). Bluetooth permission is only asked when switched on.
- project.yml: NSBluetoothAlwaysUsageDescription and background mode bluetooth-central.
- Nothing else changed: video, car page and car map are as in build 102 (version label only).
- Not tested with a real cube. The road line the user wants needs a new characteristic on the
  cube (proposal given to the user: version, N points, int8 x/y, 3 m units, heading up).
