# Lifecycle fixtures

These files are synthetic, authored for offline tests on 2026-09-12. They are
not Slack recordings and contain no live credentials. The verification token is
an unused placeholder. Tests sign the body with a synthetic local secret.

- `app_uninstalled.json` follows the wrapper and authorization shape in the
  [official uninstall example](https://docs.slack.dev/reference/events/app_uninstalled/).
- `tokens_revoked.json` follows the
  [official revocation example](https://docs.slack.dev/reference/events/tokens_revoked/),
  including its absent authorization list and absent inner timestamp.
- `bot_revoked.json` combines that documented token-list shape with a synthetic
  authorization entry. It omits `oauth` to check one-kind revocation.

Both official pages were checked online on 2026-09-12. IDs and timestamps were
replaced with deterministic test values. Specs derive malformed, ambiguous,
organization, and multiple-user variants locally. No fixture claims to identify
an installation generation or to prove live delivery behavior.
