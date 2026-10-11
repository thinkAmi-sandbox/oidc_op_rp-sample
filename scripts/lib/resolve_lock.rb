# frozen_string_literal: true

# scripts/resolve-lock から、アプリのディレクトリで（そのアプリの Ruby と Bundler で）呼ぶ。
# Gemfile と Gemfile.lock を出力先にコピーし、lock のすべての gem を Gemfile で `= 版` に固定したうえで、
# 指定した gem だけを外して `bundle lock` し、lock で動いた gem を出す。アプリのファイルは書かない。
#
# 引数（scripts/resolve-lock が組み立てる）:
#   ruby resolve_lock.rb <出力先> <要件の JSON> <外す gem の JSON> <追加で固定する gem の JSON>
#     要件: {"rails" => "~> 7.0.10"} のように、Gemfile の要件を書き換える gem（固定もしない）
#     外す gem: 固定しない gem の名前の配列（Rails の構成 gem など）
#     追加で固定する gem: {"benchmark" => "0.3.0"} のように、lock の版の代わりに固定する版

# Rails アプリの外で動くスクリプトなので、標準出力への出力と exit を使う
# rubocop:disable Rails/Output, Rails/Exit

require 'bundler'
require 'fileutils'
require 'json'
require 'open3'

out_dir, requirements_json, unpin_json, pins_json = ARGV
requirements = JSON.parse(requirements_json)
unpin = JSON.parse(unpin_json)
pins = JSON.parse(pins_json)

gemfile = File.read('Gemfile', encoding: 'UTF-8')
lock_text = File.read('Gemfile.lock', encoding: 'UTF-8')
old_lock = Bundler::LockfileParser.new(lock_text)

versions = old_lock.specs.to_h { |spec| [spec.name, spec.version.to_s] }.merge(pins)
free = requirements.keys + unpin

gem_line = ->(name) { /^(\s*gem\s+['"]#{Regexp.escape(name)}['"])((?:\s*,\s*['"][^'"]*['"])*)/ }

requirements.each do |name, requirement|
  abort "Gemfile に gem '#{name}' の行がない" unless gemfile.match?(gem_line.call(name))
  gemfile = gemfile.sub(gem_line.call(name)) { "#{Regexp.last_match(1)}, '#{requirement}'" }
end

appended = []
versions.sort.each do |name, version|
  next if free.include?(name)

  if gemfile.match?(gem_line.call(name))
    # 既にある要件はそのまま残し、`= 版` を足す（Bundler は要件をすべて満たす版を選ぶ）
    gemfile = gemfile.sub(gem_line.call(name)) { "#{Regexp.last_match(1)}, '= #{version}'#{Regexp.last_match(2)}" }
  else
    appended << "gem '#{name}', '= #{version}'"
  end
end

FileUtils.mkdir_p(out_dir)
File.write(File.join(out_dir, 'Gemfile'), "#{gemfile}\n# resolve-lock が固定した gem\n#{appended.join("\n")}\n")
File.write(File.join(out_dir, 'Gemfile.lock'), lock_text)

env = { 'BUNDLE_GEMFILE' => File.join(out_dir, 'Gemfile') }
output, status = Open3.capture2e(env, 'bundle', 'lock')
unless status.success?
  puts '解決できなかった。Bundler のエラーに出た gem を --unpin で外して繰り返す'
  puts output.lines.grep_v(/^(Fetching|Resolving)/).join
  exit 1
end

new_lock = Bundler::LockfileParser.new(File.read(File.join(out_dir, 'Gemfile.lock'), encoding: 'UTF-8'))
by_name = lambda do |lock|
  lock.specs.group_by(&:name).transform_values { |specs| specs.map(&:version).uniq.sort.map(&:to_s) }
end
before = by_name.call(old_lock)
after = by_name.call(new_lock)
default_gems = Gem::Specification.select(&:default_gem?).to_h { |spec| [spec.name, spec.version.to_s] }
note = ->(name) { default_gems[name] ? "（この Ruby の default gem は #{default_gems[name]}）" : '' }

puts "== 解決した lock: #{File.join(out_dir, 'Gemfile.lock')}"
puts '== 版が変わった gem'
(before.keys & after.keys).sort.each do |name|
  next if before[name] == after[name]

  puts "#{name} #{before[name].join(', ')} -> #{after[name].join(', ')}#{note.call(name)}"
end
puts '== 増えた gem'
(after.keys - before.keys).sort.each { |name| puts "#{name} #{after[name].join(', ')}#{note.call(name)}" }
puts '== 消えた gem'
(before.keys - after.keys).sort.each { |name| puts "#{name} #{before[name].join(', ')}" }
['RUBY VERSION', 'BUNDLED WITH'].each do |section|
  old_value = lock_text[/^#{section}\n\s+(.+)$/, 1]
  new_value = File.read(File.join(out_dir, 'Gemfile.lock'))[/^#{section}\n\s+(.+)$/, 1]
  puts "== #{section}: #{old_value} -> #{new_value}" if old_value != new_value
end
# rubocop:enable Rails/Output, Rails/Exit
