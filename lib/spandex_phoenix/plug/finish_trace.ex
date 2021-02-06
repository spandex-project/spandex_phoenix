defmodule SpandexPhoenix.Plug.FinishTrace do
  @moduledoc false

  @behaviour Plug

  @default_opts [
    tracer: Application.get_env(:spandex_phoenix, :tracer)
  ]

  @impl Plug
  def init(opts), do: Keyword.merge(@default_opts, opts)

  @impl Plug
  def call(conn, opts) do
    tracer = opts[:tracer]

    if tracer.current_trace_id() do
      tracer.finish_trace()
    end

    conn
  end
end
