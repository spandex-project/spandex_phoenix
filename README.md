# SpandexPhoenix
[![CircleCI](https://circleci.com/gh/spandex-project/spandex_phoenix.svg?style=svg)](https://circleci.com/gh/spandex-project/spandex_phoenix)
[![Inline docs](http://inch-ci.org/github/spandex-project/spandex_phoenix.svg)](http://inch-ci.org/github/spandex-project/spandex_phoenix)
[![Coverage Status](https://coveralls.io/repos/github/spandex-project/spandex_phoenix/badge.svg)](https://coveralls.io/github/spandex-project/spandex_phoenix)
[![Hex pm](http://img.shields.io/hexpm/v/spandex_phoenix.svg?style=flat)](https://hex.pm/packages/spandex_phoenix)
[![Ebert](https://ebertapp.io/github/spandex-project/spandex_phoenix.svg)](https://ebertapp.io/github/spandex-project/spandex_phoenix)

Phoenix and Plug integrations for the
[Spandex](https://github.com/spandex-project/spandex) tracing library.

## Usage

Add `spandex_phoenix` to your dendencies in `mix.exs`:

```elixir
def deps do
  [
    {:spandex_phoenix, "~> 0.4.1"}
  ]
end
```

Configure it to use your desired `Spandex.Tracer` module in `config.exs`:

```elixir
config :spandex_phoenix, tracer: MyApp.Tracer
```

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

Plug integration:
```elixir
defmodule MyApp.Router do
  use Plug.Router
  use SpandexPhoenix

  # ...
end
```

### Customizing Traces

Traces can be customized and filtered by passing options to the `use SpandexPhoenix` macro. 
See the [documentation for SpandexPhoenix] for more information.

## Integrating with Phoenix Instrumentation

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

[Hexdocs]: https://hexdocs.pm/spandex_phoenix
[documentation for SpandexPhoenix]: https://hexdocs.pm/spandex_phoenix/SpandexPhoenix.html
