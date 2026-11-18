# Build 152 (0.21.15): approval popup on Home + map survives a lost video

User: approve the car viewer from Home (not Developer); and when YouTube/the video is lost, keep the map live
(pointer, location) from the phone.

1. Approval popup (`App/main.m`): `probeBroadcast` already reads the LocalViewerApproval pending state every
   2 s. New `updateApprovalPopup:requestID:` shows an Allow / Not now UIAlertController on Home when a viewer is
   pending (app active), calling the existing approveLocalViewer/rejectLocalViewer; it dismisses itself when the
   viewer is approved/rejected/gone. The Developer buttons are unchanged.
2. Map survives a lost video (`App/CanvasShell.js` videoBudget): a player that is "running" but has drawn no new
   picture for 8 s (lost/stalled, common on weak car Wi-Fi where the video eats the link and the map squares
   "wait") now returns budget 3, so tileMap.pump / mapFrameLoop run and the car map keeps updating. Normal
   playback is unchanged; budget resets the moment the video draws again. Phone navigation was already
   independent of the car video.
