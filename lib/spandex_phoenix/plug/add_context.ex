defmodule SpandexPhoenix.Plug.AddContext do
  @moduledoc false

  @behaviour Plug

  @default_opts [
    customize_metadata: &SpandexPhoenix.default_metadata/1,
    tracer: Application.get_env(:spandex_phoenix, :tracer)
  ]

  @impl Plug
  def init(opts), do: Keyword.merge(@default_opts, opts)

  @impl Plug
  def call(conn, opts) do
    tracer = opts[:tracer]

    if tracer.current_trace_id() do
      conn
      |> opts[:customize_metadata].()
      |> tracer.update_top_span()
    end

    conn
  end
end
