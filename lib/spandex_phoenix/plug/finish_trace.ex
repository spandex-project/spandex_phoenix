defmodule SpandexPhoenix.Plug.FinishTrace do
  @moduledoc false

  @behaviour Plug

  @init_opts Optimal.schema(
               opts: [
                 tracer: :atom,
                 finish_trace?: :boolean
               ],
               defaults: [
                 tracer: Application.get_env(:spandex_phoenix, :tracer),
                 finish_trace?: Application.get_env(:spandex_phoenix, :finish_trace?, true)
               ],
               describe: [
                 tracer: "The tracing module to be used to start the trace.",
                 finish_trace?:
                   "If we should finish traces, set to false if you're tracing your tests since your test middleware should finish the test trace."
               ]
             )

  @doc false
  def __schema__, do: @init_opts

  @impl Plug
  def init(opts), do: Optimal.validate!(opts, @init_opts)

  @impl Plug
  def call(conn, opts) do
    tracer = opts[:tracer]
    finish_trace? = opts[:finish_trace?]

    if tracer.current_trace_id() && finish_trace? do
      tracer.finish_trace()
    end

    conn
  end
end
