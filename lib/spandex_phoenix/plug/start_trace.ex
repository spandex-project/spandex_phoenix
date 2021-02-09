defmodule SpandexPhoenix.Plug.StartTrace do
  @moduledoc false

  @behaviour Plug

  alias Spandex.SpanContext

  @default_opts [
    filter_traces: &SpandexPhoenix.trace_all_requests/1,
    span_name: "request",
    tracer: Application.get_env(:spandex_phoenix, :tracer)
  ]

  @impl Plug
  def init(opts), do: Keyword.merge(@default_opts, opts)

  @impl Plug
  def call(conn, opts) do
    if opts[:filter_traces].(conn) do
      begin_tracing(conn, opts)
    else
      conn
    end
  end

  # for backwards compatibility
  @doc false
  defdelegate trace_all_requests(conn), to: SpandexPhoenix

  # Private Helpers

  defp begin_tracing(conn, opts) do
    tracer = opts[:tracer]

    case tracer.distributed_context(conn) do
      {:ok, %SpanContext{} = span_context} ->
        tracer.continue_trace(opts[:span_name], span_context)

      {:error, _} ->
        tracer.start_trace(opts[:span_name])
    end

    conn
  end
end
