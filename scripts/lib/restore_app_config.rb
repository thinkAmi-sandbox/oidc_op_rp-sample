# frozen_string_literal: true

# scripts/restore-app-config から、アプリのディレクトリで呼ぶ。`bin/rails app:update` が雛形で上書きしたファイルに、
# HEAD（app:update の前のコミット）にあったアプリの独自設定を戻し、使わない機能のマイグレーションを消す。
# 戻す設定の一覧は下の「戻す設定」。どれも、雛形に合わせずに残すと人間が決めたもの（docs/upgrade/defaults/ の DEF-7.0-10・14、
# LOG.md の Step 1）。一覧にないものは戻さないので、最後に出す差分を人間が確かめる。

# Rails アプリの外で動くスクリプトなので、標準出力への出力と exit を使う
# rubocop:disable Rails/Output, Rails/Exit

require 'open3'

failures = []

head_file = lambda do |path|
  content, status = Open3.capture2('git', 'show', "HEAD:./#{path}")
  # git の出力は環境の既定の文字コードで読まれるので、日本語のコメントがあると比べられない
  status.success? ? content.force_encoding(Encoding::UTF_8) : nil
end

# 設定の行と、その直前に続くコメントの行（理由）を 1 つのまとまりとして探す
setting_block = lambda do |lines, pattern|
  index = lines.index { |line| line.match?(pattern) }
  next nil unless index

  first = index
  first -= 1 while first.positive? && lines[first - 1].match?(/^\s*#/)
  first..index
end

# 1. test.rb の deprecation（雛形は :stderr。アップグレード中は :raise にして、非推奨の警告を見落とさない）
restore_setting = lambda do |path, pattern|
  head = head_file.call(path)
  next puts("#{path}: HEAD にない（飛ばす）") unless head

  head_lines = head.lines
  current_lines = File.read(path, encoding: 'UTF-8').lines
  head_range = setting_block.call(head_lines, pattern)
  current_range = setting_block.call(current_lines, pattern)
  next puts("#{path}: HEAD に #{pattern.source} がない（飛ばす）") unless head_range
  next failures << "#{path}: 雛形に #{pattern.source} がない" unless current_range

  wanted = head_lines[head_range]
  next puts("#{path}: #{pattern.source} は HEAD と同じ") if current_lines[current_range] == wanted

  current_lines[current_range] = wanted
  File.write(path, current_lines.join)
  puts "#{path}: #{pattern.source} とその上のコメントを HEAD のものに戻した"
end
restore_setting.call('config/environments/test.rb', /^\s*config\.active_support\.deprecation\s*=/)

# 2. filter_parameter_logging.rb（:code と、伏せる対象の理由のコメント。DEF-7.0-10）
#    配列は、このリポジトリが足した要素（CUSTOM_FILTER_ELEMENTS）のうち、雛形にないものを末尾に足す。HEAD にあって雛形にない
#    ほかの要素は、雛形が消したものとして戻さずに知らせる（雛形への追随なので、残すなら一覧に足す）。
#    コメントは、雛形のコメントの後に、HEAD でこのリポジトリが足した行（日本語を含む行。雛形のコメントは英語）を入れる
CUSTOM_FILTER_ELEMENTS = [':code'].freeze
filter_path = 'config/initializers/filter_parameter_logging.rb'
filter_head = head_file.call(filter_path)
if filter_head
  statement = /^Rails\.application\.config\.filter_parameters \+= \[\n(.*?)\n\]/m
  current = File.read(filter_path, encoding: 'UTF-8')
  head_match = filter_head.match(statement)
  current_match = current.match(statement)
  if head_match.nil? || current_match.nil?
    failures << "#{filter_path}: filter_parameters の配列が見つからない"
  else
    elements = ->(text) { text.split(',').map(&:strip).reject(&:empty?) }
    head_only = elements.call(head_match[1]) - elements.call(current_match[1])
    missing = head_only & CUSTOM_FILTER_ELEMENTS
    dropped = head_only - CUSTOM_FILTER_ELEMENTS
    head_lines = filter_head[0...head_match.begin(0)].lines
    custom_comments = []
    custom_comments.unshift(head_lines.pop) while head_lines.last&.match?(/^#/)
    custom_comments.select! { |line| line.match?(/[^\x00-\x7F]/) }
    custom_comments.reject! { |line| current.include?(line) }
    replaced = current_match[0]
    replaced = replaced.sub(/\n\]\z/, ", #{missing.join(', ')}\n]") if missing.any?
    current = current.sub(current_match[0]) { "#{custom_comments.join}#{replaced}" }
    File.write(filter_path, current)
    puts "#{filter_path}: 足した要素 #{missing.inspect}、戻したコメント #{custom_comments.size} 行"
    puts "#{filter_path}: 雛形で消えた要素 #{dropped.inspect}（戻していない。差分で確かめる）" if dropped.any?
  end
else
  puts "#{filter_path}: HEAD にない（飛ばす）"
end

# 3. config/application.rb の、最後の end の後の行（Step 1 の前の RP の session_store の serializer。
#    今の 3 アプリにはないが、app:update はこの行も消すので、あれば戻す）
app_path = 'config/application.rb'
app_head = head_file.call(app_path)
if app_head
  last_end = app_head.rindex(/^end$/)
  trailing = last_end ? app_head[(last_end + 3)..].sub(/\A\n/, '') : ''
  if trailing.strip.empty?
    puts "#{app_path}: 最後の end の後の行は HEAD にない"
  else
    current = File.read(app_path, encoding: 'UTF-8')
    if current.end_with?(trailing)
      puts "#{app_path}: 最後の end の後の行は HEAD と同じ"
    else
      File.write(app_path, current + trailing)
      puts "#{app_path}: 最後の end の後の #{trailing.lines.size} 行を戻した"
    end
  end
end

# 4. app:update が足した Active Storage のマイグレーション（3 アプリとも Active Storage を使わない。DEF-7.0-14）
untracked, = Open3.capture2('git', 'ls-files', '--others', '--exclude-standard', '--', 'db/migrate')
untracked.lines.map(&:chomp).grep(/\.active_storage\.rb\z/).each do |path|
  File.delete(path)
  puts "#{path}: 消した"
end
Dir.rmdir('db/migrate') if Dir.exist?('db/migrate') && Dir.empty?('db/migrate')

unless failures.empty?
  puts '== 戻せなかったもの（雛形が変わった。手で戻し、このスクリプトの一覧を直す）'
  puts failures
  exit 1
end
# rubocop:enable Rails/Output, Rails/Exit
