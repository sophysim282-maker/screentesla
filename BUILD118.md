# Build 118 (0.20.81) - unstick video downloads

User report on 117: the video stops and does not come back; the app must be closed and opened again.
Log: car `buffer-empty` at 57 s, then WEBSITE SILENT with 4 connections open; no APP PAUSED line.
Cause NOT proven. Theory: downloads from the video site hung and held the phone's download places.

## Changes (phone only)
- `App/BoundedDownload.m`: idle timeout 12 s -> 5 s; on a transport error retry on a new session,
  up to 3 tries while under 14 s. Answer carries `ms`, `tries`, `why`.
- `App/MediaCast.m`: log `MEDIA PIECE SLOW / RECOVERED / FAILED` (internet -> phone).
- `App/Receiver.m`: log `MEDIA PIECE TO CAR SLOW / NOT DELIVERED` (phone -> car) and `MEDIA PIECE REFUSED`.
- Car page: version label only. The four entrance pictures are still added at packaging (BUILD117.md).

## Not proven
Whether this stops the freeze. The next car log will show which side was slow.
