# Documentation: https://docs.brew.sh/Formula-Cookbook.html
#                http://www.rubydoc.info/github/Homebrew/brew/master/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!

class ElasticsearchAT234 < Formula
  desc "Distributed search & analytics engine"
  homepage "https://www.elastic.co/products/elasticsearch"
  url "https://download.elasticsearch.org/elasticsearch/release/org/elasticsearch/distribution/tar/elasticsearch/2.3.4/elasticsearch-2.3.4.tar.gz"
  sha256 "371e0c5f4ded0a8548f1cce55faff3efebcfd5f895c2c816f220146521f6f06e"

  bottle :unneeded

  keg_only :versioned_formula

  depends_on :java => "1.7+"

  def cluster_name
    "elasticsearch_#{ENV["USER"]}"
  end

  def install
    # Remove Windows files
    rm_f Dir["bin/*.bat"]
    rm_f Dir["bin/*.exe"]

    # Install everything else into package directory
    libexec.install "bin", "config", "lib", "modules"

    # Set up Elasticsearch for local development:
    inreplace "#{libexec}/config/elasticsearch.yml" do |s|
      # 1. Give the cluster a unique name
      s.gsub!(/#\s*cluster\.name\: .*/, "cluster.name: #{cluster_name}")

      # 2. Configure paths
      s.sub!(%r{#\s*path\.data: /path/to.+$}, "path.data: #{var}/elasticsearch/")
      s.sub!(%r{#\s*path\.logs: /path/to.+$}, "path.logs: #{var}/log/elasticsearch/")
    end

    inreplace "#{libexec}/bin/elasticsearch.in.sh" do |s|
      # Configure ES_HOME
      s.sub!(%r{#\!/bin/sh\n}, "#!/bin/sh\n\nES_HOME=#{libexec}")
    end

    inreplace "#{libexec}/bin/plugin" do |s|
      # Add the proper ES_CLASSPATH configuration
      s.sub!(/SCRIPT="\$0"/, %Q(SCRIPT="$0"\nES_CLASSPATH=#{libexec}/lib))
      # Replace paths to use libexec instead of lib
      s.gsub!(%r{\$ES_HOME/lib/}, "$ES_CLASSPATH/")
    end

    # Move config files into etc
    (etc/"elasticsearch").install Dir[libexec/"config/*"]
    (etc/"elasticsearch/scripts").mkpath
    (libexec/"config").rmtree

    bin.write_exec_script Dir[libexec/"bin/elasticsearch"]
  end

  def post_install
    # Make sure runtime directories exist
    (var/"elasticsearch/#{cluster_name}").mkpath
    (var/"log/elasticsearch").mkpath
    ln_s etc/"elasticsearch", libexec/"config"
    (libexec/"plugins").mkdir
  end

  def caveats; <<~EOS
    Data:    #{var}/elasticsearch/#{cluster_name}/
    Logs:    #{var}/log/elasticsearch/#{cluster_name}.log
    Plugins: #{libexec}/plugins/
    Config:  #{etc}/elasticsearch/
    plugin script: #{libexec}/bin/plugin
    EOS
  end

  plist_options :manual => "elasticsearch"

  def plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>KeepAlive</key>
          <false/>
          <key>Label</key>
          <string>#{plist_name}</string>
          <key>ProgramArguments</key>
          <array>
            <string>#{opt_bin}/elasticsearch</string>
          </array>
          <key>EnvironmentVariables</key>
          <dict>
          </dict>
          <key>RunAtLoad</key>
          <true/>
          <key>WorkingDirectory</key>
          <string>#{var}</string>
          <key>StandardErrorPath</key>
          <string>#{var}/log/#{name}.log</string>
          <key>StandardOutPath</key>
          <string>#{var}/log/#{name}.log</string>
        </dict>
      </plist>
    EOS
  end

  test do
    system "#{libexec}/bin/plugin", "list"
    pid = "#{testpath}/pid"
    begin
      mkdir testpath/"config"
      system "#{bin}/elasticsearch", "-d", "-p", pid, "--path.home", testpath
      sleep 10
      system "curl", "-XGET", "localhost:9200/"
    ensure
      Process.kill(9, File.read(pid).to_i)
    end
  end
end
