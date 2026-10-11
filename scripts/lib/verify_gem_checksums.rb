# frozen_string_literal: true

# scripts/verify-gem-checksums から、アプリのディレクトリで（そのアプリの Ruby で）呼ぶ。
# vendor/bundle/ruby/<ABI の版>/cache の .gem の SHA-256 を、rubygems.org の API の sha と比べる。
# Bundler 2.4 までの lock には checksum がないので、落とした .gem やコピーした .gem は、入れるときに照らし合わされない
# （docs/upgrade/TIPS.md の「Ruby を上げる」）。名前・版・プラットフォームは .gem の中の gemspec から読む。
#
# 使い方: ruby verify_gem_checksums.rb [<比べる元の git の ref>]
#   ref を渡すと、lock でその ref から増えた・変わった gem だけを照合する

# Rails アプリの外で動くスクリプトなので、標準出力への出力と exit を使う
# rubocop:disable Rails/Output, Rails/Exit

require 'bundler'
require 'digest'
require 'json'
require 'net/http'
require 'open3'
require 'rubygems/package'

base_ref = ARGV[0]
cache_dir = File.join('vendor', 'bundle', 'ruby', RbConfig::CONFIG['ruby_version'], 'cache')
abort "キャッシュがない: #{cache_dir}" unless Dir.exist?(cache_dir)

files = Dir.glob(File.join(cache_dir, '*.gem')).sort
if base_ref
  base_lock, status = Open3.capture2('git', 'show', "#{base_ref}:./Gemfile.lock")
  abort "#{base_ref} の Gemfile.lock を読めない" unless status.success?

  key = ->(spec) { [spec.name, spec.version.to_s, spec.platform.to_s] }
  base = Bundler::LockfileParser.new(base_lock).specs.map(&key)
  current = Bundler::LockfileParser.new(File.read('Gemfile.lock')).specs.map(&key)
  changed = current - base
  wanted = changed.map do |name, version, platform|
    platform == 'ruby' ? "#{name}-#{version}" : "#{name}-#{version}-#{platform}"
  end
  puts "#{base_ref} から lock で増えた・変わった gem: #{changed.size}"
  missing = wanted.reject { |name| File.exist?(File.join(cache_dir, "#{name}.gem")) }
  missing.each { |name| puts "キャッシュにない: #{name}（default gem や、このプラットフォームでは使わない gem）" }
  files = (wanted - missing).map { |name| File.join(cache_dir, "#{name}.gem") }
end

http = Net::HTTP.new('rubygems.org', 443)
http.use_ssl = true
mismatched = 0
errors = 0
http.start do
  files.each do |file|
    spec = Gem::Package.new(file).spec
    # プラットフォームを渡さないと、java 版などのある gem では、別のプラットフォームの版の sha が返る
    response = http.get("/api/v2/rubygems/#{spec.name}/versions/#{spec.version}.json?platform=#{spec.platform}")
    unless response.is_a?(Net::HTTPSuccess)
      puts "取れない: #{File.basename(file)}（HTTP #{response.code}）"
      errors += 1
      next
    end
    expected = JSON.parse(response.body)['sha']
    actual = Digest::SHA256.file(file).hexdigest
    if expected == actual
      puts "一致: #{File.basename(file)}"
    else
      puts "不一致: #{File.basename(file)}（手元 #{actual}、rubygems.org #{expected}）"
      mismatched += 1
    end
  end
end

puts "== #{files.size} 個のうち、不一致 #{mismatched}、取れない #{errors}"
exit 1 if mismatched.positive? || errors.positive?
# rubocop:enable Rails/Output, Rails/Exit
