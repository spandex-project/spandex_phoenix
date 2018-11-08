defmodule SpandexPhoenix.Plug.AddContext do
  @moduledoc false

  @behaviour Plug

  @init_opts Optimal.schema(
               opts: [
                 customize_metadata: {:function, 1},
                 tracer: :atom
               ],
               defaults: [
                 customize_metadata: &SpandexPhoenix.default_metadata/1,
                 tracer: Application.get_env(:spandex_phoenix, :tracer)
               ],
               describe: [
                 customize_metadata: """
                 A function that takes the Plug.Conn for the current request
                 and returns the desired span options to apply to the top-level
                 span in the trace. The Plug.Conn is normally evaluated just
                 before the response is sent to the client, to ensure that the
                 most-accurate metadata can be collected. In cases where there
                 is an unhandled error, it may only represent the initial
                 request without any response information.
                 """,
                 tracer: "The tracing module to be used to start the trace."
               ]
             )

  @doc false
  def __schema__, do: @init_opts

  @impl Plug
  def init(opts), do: Optimal.validate!(opts, @init_opts)

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
