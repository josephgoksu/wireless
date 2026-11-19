# Releasing

`NOTARY_PROFILE=markwise-notary PUBLISH=1 make release` (the profile is the Reaktif team's notary key, shared by every app in that team). Bump `MARKETING_VERSION` in `project.yml` first; the tag is `v<version>`.

| Gotcha | Fix |
|---|---|
| Notary returns `Invalid: get-task-allow` | A plain `xcodebuild build` injects it. The script passes `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` and checks for it before uploading |
| Notary returns 403 "required agreement" | The account holder must accept the new Program License Agreement at developer.apple.com/account. It took about 5 minutes to reach the notary service (2026-11-19) |
| README button | Points at `releases/latest/download/Wireless.dmg`, so the asset name must stay `Wireless.dmg` |
