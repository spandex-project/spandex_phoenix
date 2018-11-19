defmodule SpandexPhoenix.Plug.StartTrace do
  @moduledoc false

  @behaviour Plug

  alias Spandex.SpanContext

  @init_opts Optimal.schema(
               opts: [
                 filter_traces: {:function, 1},
                 span_name: :string,
                 tracer: :atom
               ],
               defaults: [
                 filter_traces: &__MODULE__.trace_all_requests/1,
                 span_name: "request",
                 tracer: Application.get_env(:spandex_phoenix, :tracer)
               ],
               describe: [
                 filter_traces: "A function that takes a Plug.Conn and returns true for requests to be traced.",
                 span_name: "The name to be used for the top level span.",
                 tracer: "The tracing module to be used to start the trace."
               ]
             )

  @doc false
  def __schema__, do: @init_opts

  @impl Plug
  def init(opts), do: Optimal.validate!(opts, @init_opts)

  @impl Plug
  def call(conn, opts) do
    if opts[:filter_traces].(conn) do
      begin_tracing(conn, opts)
    else
      conn
    end
  end

  @spec trace_all_requests(Plug.Conn.t()) :: true
  @doc "Default implementation of the filter_traces function"
  def trace_all_requests(_conn), do: true

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
