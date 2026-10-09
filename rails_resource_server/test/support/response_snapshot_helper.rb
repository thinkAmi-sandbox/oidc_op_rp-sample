# frozen_string_literal: true

# 応答（ステータス・ヘッダー・本文）を、実行ごとに変わる値だけを伏せて、test/snapshots/responses/ のファイルと比べる。
# Rails や gem を上げたときの応答の変化を、スナップショットの差分として見るためのもの（docs/upgrade/PLAN.md の Step 1-b-2）。
# 伏せる値は、ヘッダー名・クエリのパラメーター名・hidden field の名前・JSON のキーで決め、文字列の形では伏せない。
# 知らない値が毎回変わるようになったときは、伏せずに落ちて気づけるようにするため。
# 3 アプリで同じ内容のファイルにしている。作り直すときは UPDATE_SNAPSHOTS=1 を付けて流す（docs/upgrade/TIPS.md）
module ResponseSnapshotHelper
  SNAPSHOT_DIR = Rails.root.join('test/snapshots/responses')

  # 値を比べないヘッダー（あるかどうかは比べる）。X-Request-Id・X-Runtime は毎回変わり、ETag・Content-Length は本文から決まる
  MASKED_HEADERS = {
    'content-length' => '<CONTENT_LENGTH>', 'etag' => '<ETAG>',
    'x-request-id' => '<REQUEST_ID>', 'x-runtime' => '<RUNTIME>'
  }.freeze

  # URL のクエリと hidden field で、毎回作られる値（doorkeeper の認可コード、omniauth の state・nonce・PKCE）
  MASKED_PARAMS = {
    'code' => '<AUTH_CODE>', 'state' => '<STATE>', 'nonce' => '<NONCE>', 'code_challenge' => '<CODE_CHALLENGE>'
  }.freeze

  # JSON のキー。トークンは毎回作られる。
  # E2E のスナップショット（e2e/support/baseline.ts）と同じく、元の値の型を残す（例: <ACCESS_TOKEN:string>）
  MASKED_JSON_KEYS = {
    'access_token' => '<ACCESS_TOKEN>', 'refresh_token' => '<REFRESH_TOKEN>', 'id_token' => '<ID_TOKEN>'
  }.freeze

  # JWKS（{"keys": [...]}）の鍵の項目。署名鍵（手元と CI で違う）から決まる。ほかの JSON の同じ名前のキーは伏せない
  MASKED_JWK_KEYS = { 'n' => '<MODULUS>', 'kid' => '<KID>' }.freeze

  PARAM_NAMES = MASKED_PARAMS.keys.sort_by { |name| -name.size }.map { |name| Regexp.escape(name) }.join('|')
  # ?code=... / &code=... / HTML の &amp;code=...
  QUERY_PARAM = /(?<=[?&;])(#{PARAM_NAMES})=[^&#"'\s<]*/
  # hidden field は属性の並びによらず、<input> のタグごとに name と value を見る
  INPUT_TAG = /<input\b[^>]*>/
  HIDDEN_FIELD_NAME = /\bname="(#{PARAM_NAMES})"/

  def assert_response_snapshot(name)
    path = SNAPSHOT_DIR.join("#{name}.txt")
    actual = response_snapshot
    write_snapshot(path, actual) if ENV['UPDATE_SNAPSHOTS']

    assert_path_exists path, "スナップショット #{path.relative_path_from(Rails.root)} がない。" \
                             '作るときは UPDATE_SNAPSHOTS=1 を付けて流す'
    assert_equal File.read(path, encoding: 'UTF-8'), actual,
                 '応答がスナップショットと違う。変わった理由を確かめ、意図したものなら UPDATE_SNAPSHOTS=1 で作り直す'
  end

  private

  def write_snapshot(path, content)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, content, encoding: 'UTF-8')
  end

  def response_snapshot
    lines = ["HTTP #{response.status}"]
    snapshot_headers.each { |key, value| lines << "#{key}: #{value}" }
    "#{lines.join("\n")}\n\n#{snapshot_body}\n"
  end

  # 名前を小文字にして並べる（HTTP のヘッダー名は大文字小文字を区別しない）。Set-Cookie は 1 つずつ別の行にする
  def snapshot_headers
    response.headers.to_h.flat_map do |key, value|
      name = key.downcase
      # Rack 2 は複数の Set-Cookie を改行でつなぎ、Rack 3 は配列で持つ
      Array(value).flat_map { |item| item.to_s.split("\n") }.map { |line| [name, mask_header(name, line)] }
    end.sort
  end

  def mask_header(name, value)
    return MASKED_HEADERS[name] if MASKED_HEADERS.key?(name)
    return value.sub(/\A([^=;]+)=[^;]*/, '\1=<COOKIE>') if name == 'set-cookie'
    return mask_params(value) if name == 'location'

    value
  end

  def snapshot_body
    body = response.body.to_s.dup.force_encoding('UTF-8')
    return json_snapshot(body) if json_body?(body)

    mask_params(body.gsub(INPUT_TAG) { |tag| mask_hidden_field(tag) })
  end

  def json_body?(body)
    media_type = response.media_type.to_s
    (media_type == 'application/json' || media_type.end_with?('+json')) && body.present?
  end

  # 空の {}・[] は json の版で整形が変わる（json 2.6.1 は {} を 2 行にする）ので、1 行にそろえる
  def json_snapshot(body)
    JSON.pretty_generate(mask_json(JSON.parse(body))).gsub(/\{\n\s*\}/, '{}').gsub(/\[\n\s*\]/, '[]')
  end

  def mask_hidden_field(tag)
    name = tag[HIDDEN_FIELD_NAME, 1]
    return tag unless name && tag.include?('type="hidden"')

    tag.sub(/\bvalue="[^"]*"/, %(value="#{MASKED_PARAMS[name]}"))
  end

  def mask_params(text)
    text.gsub(QUERY_PARAM) { "#{Regexp.last_match(1)}=#{MASKED_PARAMS[Regexp.last_match(1)]}" }
  end

  def mask_json(value, masks = MASKED_JSON_KEYS)
    case value
    when Hash then value.to_h { |key, child| [key, mask_json_value(key, child, masks)] }
    when Array then value.map { |child| mask_json(child, masks) }
    else value
    end
  end

  def mask_json_value(key, child, masks)
    return typed(masks[key], child) if masks.key?(key)
    # JWKS の鍵の配列の中だけ、n・kid も伏せる
    return mask_json(child, MASKED_JSON_KEYS.merge(MASKED_JWK_KEYS)) if key == 'keys' && child.is_a?(Array)

    mask_json(child)
  end

  # <ACCESS_TOKEN> を <ACCESS_TOKEN:string> のように、元の値の JSON の型を付けた形にする
  def typed(placeholder, value)
    type = case value
           when String then 'string'
           when Integer, Float then 'number'
           when true, false then 'boolean'
           when nil then 'null'
           when Array then 'array'
           else 'object'
           end
    placeholder.sub(/>\z/, ":#{type}>")
  end
end
