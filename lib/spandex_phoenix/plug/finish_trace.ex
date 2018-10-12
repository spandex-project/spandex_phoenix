defmodule SpandexPhoenix.Plug.FinishTrace do
  @moduledoc false

  @behaviour Plug

  @init_opts Optimal.schema(
               opts: [
                 tracer: :atom
               ],
               defaults: [
                 tracer: Application.get_env(:spandex_phoenix, :tracer)
               ],
               describe: [
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
      tracer.finish_trace()
    end

    conn
  end
end
