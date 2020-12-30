require "colorize"
require "option_parser"
require "gemini"

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
  property static_dir = Cascading(String).new(".")
end

config = Config.new

config.address.env_var = ENV["CREM_ADDRESS"]?
config.port.env_var = ENV["CREM_PORT"]?.try(&.to_i32?)
config.cert_chain.env_var = ENV["CREM_CERT"]?
config.private_key.env_var = ENV["CREM_KEY"]?

config.root.env_var = ENV["CREM_ROOT"]?
config.static_dir.env_var = ENV["CREM_STATIC_DIR"]?

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
  parser.on("--static-dir=DIR", "Specify the directory to serve statically") { |dir| config.static_dir.cli_flag = dir }
end

parser.parse

MIME.register(".gmi", "text/gemini")

server = Gemini::Server.new([
  Gemini::Server::InternalRedirectHandler.new({
    ""  => config.root.unwrap,
    "/" => config.root.unwrap,
  }),
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
