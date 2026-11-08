# ScreenLink build 74 — WebCodecs decoder stall fallback

Version 0.20.37 / build 74 = build 73 (WebCodecs canvas player is the default) + one player change.

Symptom: after ~30 s the picture stopped while sound continued, then jumped back. The player's
watchdog showed the hardware VideoDecoder stopped producing pictures while encoded video was ready
(`output-stall` / `queue-timeout`), then restarted it at the next keyframe.

Build 74: if that happens twice within 60 s, the rest of the session decodes video with the
browser's software decoder (`hardwareAcceleration: prefer-software`). Still WebCodecs + canvas +
Web Audio. Ordinary resets (seek, quality change) never switch.

- `?decoder=software` — software decoding from the start.
- `?decoder=hardware` — never switch (build 64-73 behaviour).
- Developer performance panel and Copy playback diagnostics show `videoDecoder` and
  `softwareDecoderFallback`.

Not yet verified on the real screen. If 1080p is heavy in software, choose 720p.
