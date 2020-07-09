defmodule SpandexPhoenix.Plug.StartTrace do
  @moduledoc false

  @behaviour Plug

  @init_opts Optimal.schema(
               opts: [
                 filter_traces: {:function, 1},
                 span_name: :string,
                 tracer: :atom
               ],
               defaults: [
                 filter_traces: &SpandexPhoenix.trace_all_requests/1,
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
    SpandexPhoenix.trace_request(conn, opts)
  end

  # for backwards compatibility
  @doc false
  defdelegate trace_all_requests(conn), to: SpandexPhoenix
end
