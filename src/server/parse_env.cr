class Crem::App
  def parse_env!
    @config.address.env_var = ENV["CREM_ADDRESS"]?
    @config.port.env_var = ENV["CREM_PORT"]?.try(&.to_i32?)
    @config.cert_chain.env_var = ENV["CREM_CERT"]?
    @config.private_key.env_var = ENV["CREM_KEY"]?

    @config.root.env_var = ENV["CREM_ROOT"]?
    @config.no_root.env_var = ENV["CREM_NOROOT"]?.try(&.to_loose_bool)
    @config.static_dirs.env_var = ENV["CREM_STATIC_DIR"]?.try { |dir| [dir] }
    @config.config_file.env_var = ENV["CREM_CONFIG"]?
  end
end
