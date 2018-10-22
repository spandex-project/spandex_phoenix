# SpandexPhoenix
[![CircleCI](https://circleci.com/gh/spandex-project/spandex_phoenix.svg?style=svg)](https://circleci.com/gh/spandex-project/spandex_phoenix)
[![Inline docs](http://inch-ci.org/github/spandex-project/spandex_phoenix.svg)](http://inch-ci.org/github/spandex-project/spandex_phoenix)
[![Coverage Status](https://coveralls.io/repos/github/spandex-project/spandex_phoenix/badge.svg)](https://coveralls.io/github/spandex-project/spandex_phoenix)
[![Hex pm](http://img.shields.io/hexpm/v/spandex_phoenix.svg?style=flat)](https://hex.pm/packages/spandex_phoenix)
[![Ebert](https://ebertapp.io/github/spandex-project/spandex_phoenix.svg)](https://ebertapp.io/github/spandex-project/spandex_phoenix)

Phoenix integration for the
[Spandex](https://github.com/spandex-project/spandex) tracing library.

By configuring `SpandexPhoenix.Instrumenter` in your Phoenix `instrumenters`
list, you will automatically get spans created for `Phoenix.Controller` and
`Phoenix.View` timing, with the `resource` set to the name of the controller
action or view name.

Note that this should be used in addition to the `Spandex.Plug` plugs to start
the trace and top-level span, as this instrumenter only creates child spans,
assuming that the trace will already have been created.

## Usage

Add `spandex_phoenix` to your dendencies in `mix.exs`:

```elixir
def deps do
  [
    {:spandex_phoenix, "~> 0.1.1"}
  ]
end
```

Configure it to use your desired `Spandex.Tracer` module in `config.exs`:

```elixir
config :spandex_phoenix, tracer: MyApp.Tracer
```

Configure your Phoenix `Endpoint` to use this library as an `instrumenter`:

```elixir
config :my_app, MyAppWeb.Endpoint,
  # ... existing config ...
  instrumenters: [SpandexPhoenix.Instrumenter]
```

The docs can be found at
[https://hexdocs.pm/spandex_phoenix](https://hexdocs.pm/spandex_phoenix).
