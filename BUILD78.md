# ScreenLink build 78 — quality cap by picture size

Car log (build 76): after start-up it played well; every freeze matched a 7–10 s period where nothing
arrived from the car (`WEBSITE SILENT`, 0 handshake failures, 0 busy) — the hotspot Wi-Fi link
stalled. The video was ultra-wide `2560x1072`: Auto allowed it because its height is ≤1080, but it
carries ~1.4x the data of 1920x1080, so the 20 s read-ahead could not fill.

Build 78: Auto and 1080p choose the largest variant within 1920x1088 pixels; 720p within 1280x720.
Normal 16:9 videos are unchanged. Includes build 77 (VPN answers car.tesla4khmer.com) and build 76
(20 s read-ahead).
