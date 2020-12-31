require "colorize"
require "option_parser"
require "toml"
require "gemini"

class Object
  def ipp
    pp(self)
    self
  end
end

class String
  def to_loose_bool
    %w(y yes t true).includes?(self.downcase)
  end
end

class Crem::Redirect
  enum Status
    Success
    RedirectTemporary
    RedirectPermanent
  end

  property from : String
  property to : String
  property status : Status

  def initialize(@from, @to, @status : Status); end

  def initialize(@from, @to, status : Int)
    @status =
      case status
      when 20 then Status::Success
      when 30 then Status::RedirectTemporary
      when 31 then Status::RedirectPermanent
      else         raise ArgumentError.new("Status integer must be either 20, 30, or 31 for redirects")
      end
  end

  def server_side?
    @status.success?
  end

  def client_side?
    @status.redirect_temporary? || @status.redirect_permanent?
  end
end

class Cascading(Value)
  property default : Value
  property config_option : Value?
  property cli_flag : Value?
  property env_var : Value?

  def initialize(@default); end

  def unwrap : Value
    @env_var || @cli_flag || @config_option || @default
  end
end

struct Config
  property address = Cascading(String).new("0.0.0.0")
  property port = Cascading(Int32).new(1965)
  property cert_chain = Cascading(String?).new(nil)
  property private_key = Cascading(String?).new(nil)

  property root = Cascading(String).new("index.gmi")
  property no_root = Cascading(Bool).new(false)
  property static_dir = Cascading(String).new(".")

  property redirects = Cascading(Array(Crem::Redirect)).new([] of Crem::Redirect)

  property config_file = Cascading(String?).new(nil)
end

config = Config.new

config.address.env_var = ENV["CREM_ADDRESS"]?
config.port.env_var = ENV["CREM_PORT"]?.try(&.to_i32?)
config.cert_chain.env_var = ENV["CREM_CERT"]?
config.private_key.env_var = ENV["CREM_KEY"]?

config.root.env_var = ENV["CREM_ROOT"]?
config.no_root.env_var = ENV["CREM_NOROOT"]?.try(&.to_loose_bool)
config.static_dir.env_var = ENV["CREM_STATIC_DIR"]?
config.config_file.env_var = ENV["CREM_CONFIG"]?

parser = OptionParser.new do |parser|
  parser.banner = "Usage: crem-server [options]"
  parser.on("--help", "show this help") { puts(parser); exit(0) }

  parser.separator

  parser.on("--address=ADDR", "Specify the address to bind") { |addr| config.address.cli_flag = addr }
  parser.on("--port=PORT", "Specify the port to bind") { |port| config.port.cli_flag = port.to_i32 }
  parser.on("--cert=FILE", "Specify the certificate chain file") { |file| config.cert_chain.cli_flag = file }
  parser.on("--key=FILE", "Specify the private key file") { |file| config.private_key.cli_flag = file }

  parser.separator

  parser.on("--root=PATH", "Specify the default root redirect path") { |path| config.root.cli_flag = path }
  parser.on("--no-root", "Override the default so that root isn't redirected automatically") { |flag| config.no_root.cli_flag = flag.to_loose_bool }
  parser.on("--static-dir=DIR", "Specify the directory to serve statically") { |dir| config.static_dir.cli_flag = dir }

  parser.separator

  parser.on("--config=FILE", "Specify a TOML-formatted file for configuration") { |file| config.config_file.cli_flag = file }
end

parser.parse

if config_file = config.config_file.unwrap
  if File.exists?(config_file) && File.file?(config_file)
    raw_config_file = File.read(config_file)
    parsed_config = TOML.parse(raw_config_file)

    config.cert_chain.config_option = parsed_config["certificate_chain"]?.try(&.as(String))
    config.private_key.config_option = parsed_config["private_key"]?.try(&.as(String))

    config.address.config_option = parsed_config["address"]?.try(&.as(String))
    config.port.config_option = parsed_config["port"]?.try(&.as(Int64)).try(&.to_i32)

    config.no_root.config_option = parsed_config["no_root"]?.try(&.as(Bool))

    all_redirects = parsed_config["redirect"].as(Array)
      .map(&.as(Hash))
      .map { |r| Crem::Redirect.new(r["from"].as(String), r["to"].as(String), r["status"].as(Int64)) }

    config.redirects.config_option = all_redirects.select(&.server_side?)
  end
end

MIME.register(".gmi", "text/gemini")

redirects = Array(Crem::Redirect).new

unless config.no_root.unwrap
  redirects << Crem::Redirect.new("", config.root.unwrap, Crem::Redirect::Status::Success)
  redirects << Crem::Redirect.new("/", config.root.unwrap, Crem::Redirect::Status::Success)
end

redirects = redirects + config.redirects.unwrap

duplicates = redirects.map(&.from).tally.select { |k, v| v > 1 }

unless duplicates.empty?
  longest = duplicates.map(&.[0]).max_by(&.size).size
  puts("You have duplicate redirects defined:".colorize(:red))
  duplicates.each do |dup, q|
    tos = redirects.select(&.from.==(dup)).map(&.to)
    puts("  '#{dup}' #{" " * (longest - dup.size)}-> #{tos.join(", ")}".colorize(:yellow))
  end

  unless config.no_root.unwrap
    if duplicates.keys.includes?("") || duplicates.keys.includes?("/")
      puts
      puts("It looks like you may have a conflict with the default root helper.".colorize(:yellow))
      puts("If you're defining root redirects in your config file, you probably want to set the no_root option to true.".colorize(:yellow))
    end
  end

  exit(1)
end

server = Gemini::Server.new([
  Gemini::Server::LogHandler.new(STDOUT),
  Gemini::Server::InternalRedirectHandler.new(redirects.select(&.server_side?).map { |r| {r.from, r.to} }.to_h),
  Gemini::Server::StaticHandler.new(config.static_dir.unwrap),
])

server.certificate_chain = config.cert_chain.unwrap
server.private_key = config.private_key.unwrap

begin
  spawn { puts("listening on gemini://#{config.address.unwrap}:#{config.port.unwrap}") }
  server.listen(config.address.unwrap, config.port.unwrap)
rescue e : Gemini::Server::MissingCertificateChain
  puts("You must provide a certificate chain to serve Gemini content.".colorize(:red))
  puts("Use the --cert flag or the CREM_CERT environment variable to specify.".colorize(:yellow))
  puts()
  puts(parser)
rescue e : Gemini::Server::MissingPrivateKey
  puts("You must provide a private key to serve Gemini content.".colorize(:red))
  puts("Use the --key flag or the CREM_KEY environment variable to specify.".colorize(:yellow))
  puts()
  puts(parser)
end
