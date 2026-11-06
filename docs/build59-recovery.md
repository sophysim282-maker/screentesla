# Build 59 recovery work

Baseline: restored 0.20.20 build 57, tree 0921957674183f4098955b686eb168bf480877cd.
This work is in the original repository's feature/youtube-airplay-010 branch.
Build 58 is abandoned; no placeholder video, silent audio or ReplayKit fallback
is introduced for YouTube. Existing explicit Maps broadcast remains separate.

## Findings and limits
The observed DNS error -65569 is DefunctConnection, distinct from PolicyDenied
(-65570). Previously the callback logged it without invalidating/replacing the
handles; foreground recovery only restarted a timed session. Discovery now
replaces failed DNS handles on its main queue, deferring work out of callbacks.
Queued retries are generation-scoped and limited to three. A foreground return
allows a new recovery attempt. Healthy identical profiles remain untouched;
viewer credentials, local listeners and AirPlay connections are not stopped.

PiP listens for real-media stalls, failed-to-end and audio interruptions. It can
retry real media twice per epoch only while PiP is active and source playback
is still wanted. A dismissed window clears the pending PiP intent. No automatic
reopening occurs. The app cannot promise indefinite iOS background execution.

Canvas decoders already use separate audio/video lanes. Video now discards
decoded frames behind the audio clock, catches up from a new keyframe when
encoded video is over 750 ms late, and abandons a video decoder queue stalled
over 1.5 seconds or a flush stalled over 2 seconds. Recovery touches only the
video decoder/frames; audio decoder, nodes, PCM, sample clock, request generation
and quality choice are retained. Old decoder callbacks cannot enter a new
decoder/seek epoch. Audio errors still surface normally. Quality is not forced
lower. These are bounded queue deadlines, not a proven diagnosis of the user's
random freeze.

The HLS resource registry formerly rejected all new entries forever after 4096,
misreporting capacity as unsupported URLs. Rewrite admission is now transactional
and keeps the 4096 bound, 64 playlist/snapshot metadata bounds, in-flight requests,
complete selected playlist seek references and recent snapshot grace. Invalid
URI (422), stale epoch (410) and capacity (503) have distinct diagnostics without
signed URL/token content. UUID paths and token/range checks are unchanged.

## Validation and delivery
Cloud tests inject defunct DNS callbacks, stale retry generations, stop/restart,
daemon unavailability and policy-denied errors; exercise more than 4096 unique
HLS resources; and play real 1080p HLS with audio while forcing a delayed video
decoder, reordered frame callbacks and recovery. Existing native/browser tests
and iOS packaging remain required. PiP UIKit behavior and iPhone/Tesla endurance
still require device testing.

Public CI outputs are GENERIC-NO-HTTPS and are not ready for the user's website.
Final personalized IPA must be assembled in the private packaging repository
using the existing working-build57 identity, then verified for exact build59
payload/extension consistency, trusted hostname/key/certificate and actual app
TLS context/handshake. Never commit or print private identity contents.
