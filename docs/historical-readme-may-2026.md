> Historical May 2026 prototype documentation. Not the current API or compatibility guide.

# spnl-web

[matz/spinel](https://github.com/matz/spinel) 用 Web フレームワークの最小ライブラリ群。
HTTP サーバや非同期処理を Sinatra 風に書くための **11 モジュール (~250 行)**。

[gorin9/spinel-packer](https://github.com/gorin9/spinel-packer) で vendor する想定。

## モジュール一覧

| ファイル | 役割 | Tier (Web libs roadmap) |
|---|---|---|
| `web/scheduler.rb` | Fiber + epoll の核 (FB / Scheduler / nb_accept / nb_recv / nb_send_all / signal_watch) | — (基盤) |
| `web/date.rb`      | RFC 3339 / 2822 / HTTP-date format (pure Spinel) | 2 #12 |
| `web/logger.rb`    | JSON Lines 構造化ログ (stderr) | 2 #11 |
| `web/mime.rb`      | 拡張子 → Content-Type ルックアップ | 2 #8 |
| `web/session.rb`   | HMAC-SHA256 cookie session | 2 #10 |
| `web/csrf.rb`      | CSRF トークン生成・検証 | 3 #15 |
| `web/bcrypt.rb`    | bcrypt hash / verify | 3 #14 |
| `web/multipart.rb` | multipart/form-data 簡易 parser | 2 #9 |
| `web/websocket.rb` | RFC 6455 echo サーバ (handshake + frame) | 3 #16 |
| `web/smtp.rb`      | SMTP client | 3 #19 |
| `web/tls.rb`       | TLS init (sketch) | 3 #13 |

## 設計

- **Ruby のみ**: FFI 実装 (`helper.c`) は本ライブラリに含めない。
  → アプリケーション側で C ヘルパを用意し、`H` モジュールに FFI 宣言を書く前提。
- **トップレベル定数 / メソッド**: Spinel 制約 (class instance var の GC バグ) のため、
  ライブラリ内のクラスは最小限。
- **`require_relative` で順次ロード**: 利用者が明示的に依存順を制御できる。

## 使い方

### 1. spinel-packer で取得

```sh
$ spinel-packer install gorin9/spnl-web
  resolving gorin9/spnl-web@main ...
  resolved → <sha>
  fetched gorin9/spnl-web into vendor/gorin9__spnl-web (13 files)
  Spinelfile + Spinelfile.lock updated
done.
```

これで `Spinelfile`, `Spinelfile.lock`, `vendor/gorin9__spnl-web/` が
全部生成される。`vendor/` は `.gitignore` で除外、`Spinelfile.lock`
はコミット推奨 (`spinel-packer install` (引数なし) で再現可能になる)。

### 2. アプリで require_relative

`web/logger.rb` は `iso_now` を `web/date.rb` から使う等、内部依存あり。
推奨する require 順:

```ruby
# app.rb
# 1. FFI モジュール定義 (H, C, SQL) — 利用者責務
module H
  ffi_lib "spinelhelper"     # → helper.c の .a
  ffi_lib "crypto"            # OpenSSL libcrypto (HMAC/SHA)
  ffi_lib "ssl"               # OpenSSL libssl (TLS)
  ffi_lib "z"                 # zlib (gzip)
  ffi_lib "crypt"             # libxcrypt (bcrypt)
  ffi_cflags "-L/opt/spinel-helper"

  # date
  ffi_func :sp_unix_ms,      [],                       :long
  ffi_func :sp_gmtime_str,   [:long],                  :str
  # logger
  ffi_func :sp_log,          [:str],                   :int
  # session / csrf
  ffi_func :sp_hmac_sha256_hex, [:str, :str],          :str
  ffi_func :sp_consttime_eq, [:str, :str],             :int
  ffi_func :sp_uuid_v4,      [],                       :str
  # bcrypt
  ffi_func :sp_bcrypt_hash,  [:str, :int],             :str
  ffi_func :sp_bcrypt_verify,[:str, :str],             :int
  # scheduler (大量のため省略、helper.c 参照)
  # ...
end

# 2. ライブラリを順次 require
require_relative "vendor/gorin9__spnl-web/web/date"
require_relative "vendor/gorin9__spnl-web/web/logger"
require_relative "vendor/gorin9__spnl-web/web/session"
require_relative "vendor/gorin9__spnl-web/web/mime"
require_relative "vendor/gorin9__spnl-web/web/multipart"
require_relative "vendor/gorin9__spnl-web/web/csrf"
require_relative "vendor/gorin9__spnl-web/web/bcrypt"
require_relative "vendor/gorin9__spnl-web/web/websocket"
require_relative "vendor/gorin9__spnl-web/web/smtp"
require_relative "vendor/gorin9__spnl-web/web/tls"
require_relative "vendor/gorin9__spnl-web/web/scheduler"

# 3. 自分のロジック
class App
  # ...
end
```

### 3. helper.c (C 実装)

本ライブラリの Ruby コードは `H.sp_*` 経由で C 実装を呼ぶ前提。  
完全な `helper.c` の例は **[gorin9/spinel-demo](https://github.com/gorin9/spinel-demo)** を参照。

最小限のヘルパが必要な関数:
- syscall ラッパ: `sp_epoll_*`, `sp_set_nonblock`, `sp_accept_nb`, `sp_recv_nb`, `sp_send_nb`
- 時刻: `sp_unix_ms`, `sp_gmtime_str`
- 暗号: `sp_hmac_sha256_hex`, `sp_sha256_hex`, `sp_consttime_eq`, `sp_uuid_v4`, `sp_uuid_v7`, `sp_sha1_b64`
- bcrypt: `sp_bcrypt_hash`, `sp_bcrypt_verify`
- TCP/TLS/WS/SMTP 個別の helpers (詳細は spinel-demo)

## Spinel との互換性

- **Spinel master 時点で動作確認** (1276 commits 時点)
- Spinel 制約 13 件を回避済 (詳細は spinel-demo の `docs/spinel-async-impl.md`)
- 主な制約対応:
  - 未使用 def は削除済 (型推論汚染回避)
  - `Fiber.new(&block)` 不使用 (メソッド経由で wrap)
  - トップレベル定数で `:str` 保持 (class ivar 経由は避ける)
  - `arr.index(v)` 戻り値 `< 0` で判定

## ベンチマーク

`gorin9/spinel-demo` で本ライブラリを使った httpd_async.rb の実測:

| 並行度 | Spinel async 4p ka | Go net/http ka |
|---|---|---|
| c=100 | **25,865 rps** | 13,965 rps |

詳細: [spinel-demo](https://github.com/gorin9/spinel-demo) の README 参照。

## 関連プロジェクト

- [matz/spinel](https://github.com/matz/spinel) — 本家 Spinel コンパイラ
- [gorin9/spinel-packer](https://github.com/gorin9/spinel-packer) — install / upgrade / lock / check / pack ツール
- [gorin9/spinel-demo](https://github.com/gorin9/spinel-demo) — 本ライブラリを使った動作デモ

## ライセンス

MIT
