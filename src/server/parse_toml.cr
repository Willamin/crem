class Crem::App
  def parse_config!
    return unless config_file = @config.config_file.unwrap

    if File.exists?(config_file) && File.file?(config_file)
      raw_config_file = File.read(config_file)
      parsed_config = TOML.parse(raw_config_file)

      @config.cert_chain.config_option = parsed_config["certificate_chain"]?.try(&.as(String))
      @config.private_key.config_option = parsed_config["private_key"]?.try(&.as(String))

      @config.address.config_option = parsed_config["address"]?.try(&.as(String))
      @config.port.config_option = parsed_config["port"]?.try(&.as(Int64)).try(&.to_i32)

      @config.no_root.config_option = parsed_config["no_root"]?.try(&.as(Bool))

      all_redirects = parsed_config["redirect"].as(Array)
        .map(&.as(Hash))
        .map { |r| Crem::Redirect.new(r["from"].as(String), r["to"].as(String), r["status"].as(Int64)) }

      @config.redirects.config_option = all_redirects.select(&.server_side?)
    end
  end
end
