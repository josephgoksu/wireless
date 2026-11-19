# BBC endpoints (tested 2026-11-19, from a GB IP)

| Need | Endpoint | Notes |
|---|---|---|
| Live audio, UK | `a.files.bbci.co.uk/ms6/live/3441A116-B12E-4D2F-ACA8-C1984642FA4B/audio/simulcast/hls/uk/pc_hd_abr_v2/aks/<id>.m3u8` | Master playlist → current `as-hls-uk-live.akamaized.net/pool_N/...` at 320k. Use `aks` (https), not `ak` (http) |
| Live audio, abroad | same with `nonuk` | 96k |
| Now on | `rms.api.bbc.co.uk/v2/broadcasts/latest?service=<id>&on_air=now` | `titles.secondary` is sometimes only a date, so prefer `synopses.short` |
| Track | `rms.api.bbc.co.uk/v2/services/<id>/segments/latest?limit=1` | Trust it only when `offset.now_playing == true`. Speech stations return none |

Dead ends, don't retry:

- Hardcoded `as-hls-*-live.akamaized.net/pool_N` URLs: the BBC rotates pool IDs (Radio 4's `pool_904` returns 410). The `ms6` master above hides this.
- `open.live.bbc.co.uk/mediaselector/6/.../vpid/<id>`: returns `selectionunavailable` for domestic stations; only World Service resolves.
- `lsn.lv` resolver: behind a bot challenge.
- The LMS plugin's DASH path needs a signed-in BBC account and JWT.
