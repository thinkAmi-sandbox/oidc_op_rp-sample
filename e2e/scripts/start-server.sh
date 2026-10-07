#!/usr/bin/env bash
# E2E 用にアプリを 1 つ起動する。playwright.config.ts の webServer から呼ぶ。
# 使い方: scripts/start-server.sh <op|rp|rs>
#
# development 環境のまま、DATABASE_URL で E2E 専用の DB（各アプリの db/e2e.sqlite3）に切り替える。
# 起動のたびに DB を作り直すので、手動確認用の development DB には触れない。
set -euo pipefail

case "${1:-}" in
  op) app=rails_open_id_provider; port=3780 ;;
  rp) app=rails_relying_party_of_backend; port=3781 ;;
  rs) app=rails_resource_server; port=3782 ;;
  *) echo "usage: $0 <op|rp|rs>" >&2; exit 1 ;;
esac

# DATABASE_URL は playwright.config.ts から渡す。E2E 用の DB を指していなければ、db:drop の前に止める
case "${DATABASE_URL:-}" in
  *e2e*) ;;
  *) echo "DATABASE_URL must point to the E2E database (got: '${DATABASE_URL:-}')" >&2; exit 1 ;;
esac

export RAILS_ENV=development

cd "$(dirname "$0")/../../$app"

case "$app" in
  rails_open_id_provider)
    # ID トークンの署名鍵。手動確認用の鍵と共用し、なければ作る（秘密鍵は gitignore 対象で、コミットしない）
    if [ ! -f jwtRS256.key ]; then
      mise exec -- ruby -ropenssl -e 'File.write("jwtRS256.key", OpenSSL::PKey::RSA.new(4096).to_pem, perm: 0o600)'
    fi
    mise exec -- bin/rails db:drop db:setup
    ;;
  rails_relying_party_of_backend)
    mise exec -- bin/rails db:drop db:setup
    ;;
  rails_resource_server)
    # RS は DB を使わず、schema.rb もないので db:setup はできない。空の DB だけ作る
    mise exec -- bin/rails db:drop db:create
    ;;
esac

# pid ファイルを分け、手動確認用のサーバーの pid ファイルが残っていても起動できるようにする
exec mise exec -- bin/rails server -p "$port" -P tmp/pids/e2e_server.pid
