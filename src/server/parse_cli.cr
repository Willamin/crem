class Crem::App
  def parse_cli!
    @parser = OptionParser.new do |parser|
      parser.banner = "Usage: crem-server [options]"
      parser.on("--help", "show this help") { puts(parser); exit(0) }

      parser.separator

      parser.on("--address=ADDR", "Specify the address to bind") { |addr| @config.address.cli_flag = addr }
      parser.on("--port=PORT", "Specify the port to bind") { |port| @config.port.cli_flag = port.to_i32 }
      parser.on("--cert=FILE", "Specify the certificate chain file") { |file| @config.cert_chain.cli_flag = file }
      parser.on("--key=FILE", "Specify the private key file") { |file| @config.private_key.cli_flag = file }

      parser.separator

      parser.on("--root=PATH", "Specify the default root redirect path") { |path| @config.root.cli_flag = path }
      parser.on("--no-root", "Override the default so that root isn't redirected automatically") { |flag| @config.no_root.cli_flag = flag.to_loose_bool }
      parser.on("--static-dir=DIR", "Specify the directory to serve statically") { |dir| @config.static_dir.cli_flag = dir }

      parser.separator

      parser.on("--config=FILE", "Specify a TOML-formatted file for configuration") { |file| @config.config_file.cli_flag = file }
    end

    @parser.as?(OptionParser).try(&.parse)
  end
end
