require "colorize"
require "option_parser"
require "toml"
require "gemini"

class Crem::App
  getter config = Config.new
  getter redirects = Array(Crem::Redirect).new
  getter parser : OptionParser | String = ""
  getter static_dirs = Array(String).new
end

require "./server/*"

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

app = Crem::App.new
app.parse_env!
app.parse_cli!
app.parse_config!
app.organize_redirects!
app.organize_static_dirs!

MIME.register(".gmi", "text/gemini")

static_handlers = app.config.static_dirs.unwrap.map { |dir| Gemini::Server::StaticHandler.new(dir, true) }

server = Gemini::Server.new([
  Gemini::Server::LogHandler.new(STDOUT),
  Gemini::Server::InternalRedirectHandler.new(app.redirects.select(&.server_side?).map { |r| {r.from, r.to} }.to_h),
] + static_handlers)

server.certificate_chain = app.config.cert_chain.unwrap
server.private_key = app.config.private_key.unwrap

begin
  spawn { puts("listening on gemini://#{app.config.address.unwrap}:#{app.config.port.unwrap}") }
  server.listen(app.config.address.unwrap, app.config.port.unwrap)
rescue e : Gemini::Server::MissingCertificateChain
  puts("You must provide a certificate chain to serve Gemini content.".colorize(:red))
  puts("Use the --cert flag or the CREM_CERT environment variable to specify.".colorize(:yellow))
  puts()
  puts(app.parser)
rescue e : Gemini::Server::MissingPrivateKey
  puts("You must provide a private key to serve Gemini content.".colorize(:red))
  puts("Use the --key flag or the CREM_KEY environment variable to specify.".colorize(:yellow))
  puts()
  puts(app.parser)
end
