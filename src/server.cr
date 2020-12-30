require "colorize"
require "option_parser"
require "gemini"

server_address = "0.0.0.0"
server_port = 1965
server_cert_chain = nil
server_private_key = nil

if env_value = ENV["CREM_ADDRESS"]?
  server_address = env_value
end
if env_value = ENV["CREM_PORT"]?.try(&.to_i32)
  server_port = env_value
end
if env_value = ENV["CREM_CERT"]?
  server_cert_chain = env_value
end
if env_value = ENV["CREM_KEY"]?
  server_private_key = env_value
end

parser = OptionParser.new do |parser|
parser.banner = "Usage: crem-server [options]"
  parser.on("--address=ADDR", "Specify the address to bind") { |addr| server_address = addr }
  parser.on("--port=PORT", "Specify the port to bind") { |port| server_port = port.to_i32 }
  parser.on("--cert=FILE", "Specify the certificate chain file") { |file| server_cert_chain = file }
  parser.on("--key=FILE", "Specify the private key file") { |file| server_private_key = file }

  parser.on("--help", "show this help") do
    puts(parser)
    exit(0)
  end
end

parser.parse

MIME.register(".gmi", "text/gemini")

server = Gemini::Server.new([
  Gemini::Server::InternalRedirectHandler.new({
    "" => "gemini.gmi",
    "/" => "gemini.gmi",
  }),
  Gemini::Server::StaticHandler.new("."),
])

server.certificate_chain = server_cert_chain
server.private_key = server_private_key

begin
  spawn { puts("listening on gemini://#{server.address}:#{server.port}") }
  server.listen
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

