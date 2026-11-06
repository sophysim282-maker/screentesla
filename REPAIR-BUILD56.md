# Build 56: bound partial connection responses

Build 55 compiled and passed hosted browser checks, but inspection found that CanvasShell.raw cleared its seven-second deadline after headers, before request/session JSON was consumed. A stalled body could hold joining or polling indefinitely, preventing recovery after an iPhone receiver restart.

The deadline now covers response JSON parsing. Both viewer discovery and authenticated state/privacy/report requests use this path. Media chunk requests already hold their timeout through arrayBuffer consumption and are unchanged. Automatic reconnection, back/forward restoration, no-recording default, optional manual PiP, Auto quality capped at 1080p including SD, inline buttons, and the original audio pipeline are retained.

Regression test simulates headers arriving followed by an incomplete body for discovery and health requests. The deadline must remain armed, abort the body, and release the request. Existing outage/reconnection, restored-page and abandoned-approval tests also pass locally. No hardware Tesla recovery claim or guaranteed iOS 30-minute grant is made. Widget registration remains unverified without the signed IPA.
