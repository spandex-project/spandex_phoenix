use Mix.Config

config :spandex_phoenix, tracer: MyApp.Tracer

import_config "#{Mix.env()}.exs"
