import Config

if config_env() == :test do
  config :stream_data,
    max_generation_size: 100
end
