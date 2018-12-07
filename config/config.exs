use Mix.Config

config :logger,
  backends: [:console, {LoggerFileBackend, :info}],
  level: :info

if File.exists?("config/#{Mix.env}.exs") do
  import_config "#{Mix.env}.exs"
end
