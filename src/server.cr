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
  parser.on("--cert=FILE", "Specify the certificate chain file") { |file| server_cert_chain = file }
  parser.on("--key=FILE", "Specify the private key file") { |file| server_private_key = file }

  parser.on("--help", "show this help") do
    command = :help
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

  puts("listening on gemini://#{server.address}:#{server.port}")
  server.listen
