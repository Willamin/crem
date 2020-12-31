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
