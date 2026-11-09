# ScreenLink build 91 — opening the map no longer drops AirPlay

User report (build 90): tapping Navigation map lost the YouTube AirPlay video.

Cause: Car Maps' NavModel set the shared AVAudioSession to `.playback` / `.voicePrompt` /
`.duckOthers` as soon as the map opened, and voice search set `.record`. ScreenLink's PiP and AirPlay
receiver use `.playback` / `.moviePlayback` / `.mixWithOthers` (YouTubePiP.m); changing it interrupted
PiP and YouTube dropped AirPlay.

Build 91: map voice directions keep ScreenLink's session (playback, moviePlayback, mixWithOthers)
and only set it when different; voice search records with `.playAndRecord` + `.mixWithOthers` so
playback continues, then restores ScreenLink's session. Video player unchanged.
