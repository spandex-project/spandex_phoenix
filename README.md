# SpandexPhoenix

[![Hex Version](https://img.shields.io/hexpm/v/spandex_phoenix.svg)](https://hex.pm/packages/spandex_phoenix)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/spandex_phoenix/)
[![Total Downloads](https://img.shields.io/hexpm/dt/spandex_phoenix.svg)](https://hex.pm/packages/spandex_phoenix)
[![License](https://img.shields.io/hexpm/l/spandex_phoenix.svg)](https://github.com/spandex-project/spandex_phoenix/blob/master/LICENSE)

Phoenix and Plug integrations for the [Spandex] tracing library.

[Spandex]: https://github.com/spandex-project/spandex

## Usage

Add `:spandex_phoenix` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:spandex_phoenix, "~> 1.0"}
  ]
end
```

Configure it to use your desired `Spandex.Tracer` module in `config.exs`:

```elixir
config :spandex_phoenix, tracer: MyApp.Tracer
```

### Usage: Phx >= 1.5 (Telemetry)

**Upgrade Note**: *If you're updating your SpandexPhoenix code from using it with previous versions of Pheonix,
you must first remove all the code detailed in `Usage: Plug & Phx < 1.5` before following
telemetry installation instructions below.*


SpandexPhoenix supports using Phoenix 1.5's Telemetry events to create spans for
`Phoenix.Controller` timing, with the `resource` name set to the controller action.

To attach `Spandex.Telemetry`'s event handlers, call `Spandex.Telemetry.install/{0,1}`
during your application's startup:

```elixir
defmodule MyApp.Application do
  def start(_, _) do
    # ...
    SpandexPhoenix.Telemetry.install()
    # ...
  end
end
```

See `Spandex.Telemetry.install/1` documentation for event handler options.

### Usage: Plug & Phx < 1.5

Add `use SpandexPhoenix` to the appropriate module. This will "wrap" the
module with tracing and error-reporting via Spandex.

Phoenix integration:

```elixir
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app
  use SpandexPhoenix

  # ...
end
```

If you use Phoenix, you don't need to use the following integration most likely, otherwise, you get the error messages like

```
[error] Tried to start a trace over top of another trace
```

Plug integration:

```elixir
defmodule MyApp.Router do
  use Plug.Router
  use SpandexPhoenix

  # ...
end
```

#### Customizing Traces

Traces can be customized and filtered by passing options to the `use SpandexPhoenix` macro.
See the [documentation for SpandexPhoenix] for more information.

#### Integrating with Phoenix Instrumentation

If you are using Phoenix and you configure `SpandexPhoenix.Instrumenter` in
your Phoenix `instrumenters` list, you will automatically get spans created for
`Phoenix.Controller` and `Phoenix.View` timing, with the `resource` set to the
name of the controller action or view name.

Note that this should be used in addition to the `use SpandexPhoenix`
macro to start the trace and top-level span, as the instrumenter only creates
child spans, assuming that the trace will already have been created.

Configure your Phoenix `Endpoint` to use this library as one of its
`instrumenters`:

```elixir
config :my_app, MyAppWeb.Endpoint,
  # ... existing config ...
  instrumenters: [SpandexPhoenix.Instrumenter]
```

More details can also be found in the docs on [Hexdocs].

## Copyright and License

Copyright (c) 2021 Zachary Daniel & Greg Mefford

Released under the MIT License, which can be found in [LICENSE.md](./LICENSE.md).

[Hexdocs]: https://hexdocs.pm/spandex_phoenix
[documentation for SpandexPhoenix]: https://hexdocs.pm/spandex_phoenix/SpandexPhoenix.html
