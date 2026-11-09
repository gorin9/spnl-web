# spnl-web

Reusable web building blocks for Ruby and Spinel, using standard Thread, socket,
Time, Logger, JSON, SecureRandom, OpenSSL and net/smtp APIs.

```toml
[dependencies]
spnl_web = { git = "https://github.com/gorin9/spnl-web", ref = "modernize-spinel-2026" }
```

```ruby
require "spnl_web"
session = SpnlWeb::Session.new(ENV.fetch("SPNL_SESSION_SECRET"))
cookie = session.sign("alice", Time.now.to_i + 3600)
raise "invalid" unless session.verify(cookie) == "alice"
```

Session secrets must have at least 32 bytes. Legacy session_sign/session_verify helpers
require SPNL_SESSION_SECRET; there is no embedded production default. Signatures use
HMAC-SHA256, optional expiry, and previous secrets for rotation. Old unversioned cookies
are invalidated by the format change. Cookies are signed, not encrypted.
CSRF helpers compare a submitted token with the expected token; the application must
bind that expected token to its authenticated session and enforce it on unsafe methods.

SpnlWeb::Server accepts bounded connections (default 128), runs each handler in a
standard Thread, releases finished sockets, and exposes stop/drain. Configure a handler
timeout as the demo does. It replaces the prototype Scheduler/FB/epoll API; old code is
archived under legacy/ and must not be combined with the new Thread server.

Multipart.parse handles bounded in-memory multiple parts including binary NULs; it is
not a streaming upload API. WebSocket supports masked client text/binary frames,
fragmentation, extended lengths up to 1 MiB, ping/pong and close. The HTTP application
must validate Upgrade, Connection, version and key before constructing it.

`require "spnl_web/tls"` provides TLS.context/server over standard OpenSSL.
`require "spnl_web/smtp"` provides the standard SMTP wrapper. Configure delivery,
authentication and TLS policy explicitly; the library never sends mail at load time.
The pinned standard SecureRandom lacks uuid_v7. SpnlWeb::UUID.v7 implements the
RFC 9562 timestamp/version/variant layout over standard SecureRandom bytes. It has
random ordering within the same millisecond and keeps no shared monotonic counter.

Native code is limited to constant-time comparison and reentrant bcrypt on Linux
(libcrypto + libcrypt). spin.toml explicitly declares native/*.c; users supply no
helper.c. bcrypt rejects NULs/passwords over 72 bytes and costs outside 4..16; failure
raises rather than silently returning a bad hash. Thread-local C output is copied
at the FFI boundary. Other platforms require a compatible libxcrypt or an alternative.

Historical top-level date/log/session/CSRF/bcrypt helpers remain. Integer-fd helpers,
H modules and the old Scheduler API are not part of the current interface.

## Compatibility and verification

Supported baseline: Spinel `2026.10.25` (Linux) and CRuby 3.1+. CI also checks the
reference master commit `60c0273261415d2b5edd6480667a705a68addbd2`; this is a pinned
comparison, not an assertion about every future master build. Check CHANGELOG before upgrading.
No performance or binary-size claim is inherited from the May prototype.

Run `rake test`. Runtime packages additionally use `spin test`; generator repositories
use `ruby scripts/verify_runtime.rb` to compile their generated code and compare with CRuby.
See CONTRIBUTING.md. Original notes are in `docs/historical-readme-may-2026.md`.

MIT licensed. Development version; no gem or package-index release is published automatically.
