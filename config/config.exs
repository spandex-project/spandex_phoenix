use Mix.Config

config :spandex_phoenix, tracer: TestTracer

config :spandex_phoenix, TestTracer,
  adapter: TestAdapter,
  service: :spandex_phoenix,
  type: :web

config :phoenix, :json_library, Jason

import_config "#{Mix.env()}.exs"
