require 'formula'

class Redis < Formula
  homepage 'http://redis.io/'
  url 'http://redis.googlecode.com/files/redis-2.6.5.tar.gz'
  sha1 '420bbc789342cd82706f940f2d179f1676499887'

  head 'https://github.com/antirez/redis.git', :branch => 'unstable'

  fails_with :llvm do
    build 2334
    cause 'Fails with "reference out of range from _linenoise"'
  end

  def install
    # Architecture isn't detected correctly on 32bit Snow Leopard without help
    ENV["OBJARCH"] = MacOS.prefer_64_bit? ? "-arch x86_64" : "-arch i386"

    # Head and stable have different code layouts
    src = (buildpath/'src/Makefile').exist? ? buildpath/'src' : buildpath
    system "make", "-C", src, "CC=#{ENV.cc}"

    %w[benchmark cli server check-dump check-aof].each { |p| bin.install src/"redis-#{p}" }
    %w[run db/redis log].each { |p| (var+p).mkpath }

    # Fix up default conf file to match our paths
    inreplace "redis.conf" do |s|
      s.gsub! "/var/run/redis.pid", "#{var}/run/redis.pid"
      s.gsub! "dir ./", "dir #{var}/db/redis/"
      s.gsub! "\# bind 127.0.0.1", "bind 127.0.0.1"
    end

    # Fix redis upgrade from 2.4 to 2.6.
    if File.exists?(etc/'redis.conf') && File.readlines(etc/'redis.conf').grep(/^vm-enabled/)
      mv etc/'redis.conf', etc/'redis.conf.old'
      ohai "Your redis.conf will not work with 2.6; moved it to redis.conf.old"
    end

    etc.install 'redis.conf' unless (etc/'redis.conf').exist?
  end

  def caveats
    <<-EOS.undent
    If this is your first install, automatically load on login with:
        mkdir -p ~/Library/LaunchAgents
        cp #{plist_path} ~/Library/LaunchAgents/
        launchctl load -w ~/Library/LaunchAgents/#{plist_path.basename}

    If this is an upgrade and you already have the #{plist_path.basename} loaded:
        launchctl unload -w ~/Library/LaunchAgents/#{plist_path.basename}
        cp #{plist_path} ~/Library/LaunchAgents/
        launchctl load -w ~/Library/LaunchAgents/#{plist_path.basename}

      To start redis manually:
        redis-server #{etc}/redis.conf

      To access the server:
        redis-cli
    EOS
  end

  def startup_plist
    return <<-EOPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>KeepAlive</key>
    <true/>
    <key>Label</key>
    <string>#{plist_name}</string>
    <key>ProgramArguments</key>
    <array>
      <string>#{HOMEBREW_PREFIX}/bin/redis-server</string>
      <string>#{etc}/redis.conf</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>UserName</key>
    <string>#{`whoami`.chomp}</string>
    <key>WorkingDirectory</key>
    <string>#{var}</string>
    <key>StandardErrorPath</key>
    <string>#{var}/log/redis.log</string>
    <key>StandardOutPath</key>
    <string>#{var}/log/redis.log</string>
  </dict>
</plist>
    EOPLIST
  end
end
