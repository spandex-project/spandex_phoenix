defmodule SpandexPhoenix.Telemetry do
  @moduledoc """
  Defines the `:telemetry` handlers to attach tracing to Phoenix Telemetry.
  """

  @doc """
  Installs `:telemetry` event handlers for Phoenix Telemetry events.

  ### Options

  * `:tracer` (`Atom`)

      The tracing module to be used for traces in your Endpoint.

      Default: `Application.get_env(:spandex_phoenix, :tracer)`
  """
  def install(opts \\ []) do
    tracer =
      Keyword.get_lazy(opts, :tracer, fn ->
        Application.get_env(:spandex_phoenix, :tracer)
      end)

    unless tracer do
      raise ArgumentError, ":tracer option must be provided or configured in :spandex_phoenix"
    end

    filter_traces = Keyword.get(opts, :filter_traces, fn _ -> true end)
    customize_metadata = Keyword.get(opts, :customize_metadata, &Spandex.default_metadata/1)
    span_name = Keyword.get(opts, :span_name, "request")

    opts = %{tracer: tracer, filter_traces: filter_traces, customize_metadata: customize_metadata, span_name: span_name}

    events = [
      [:phoenix, :router_dispatch, :start],
      [:phoenix, :router_dispatch, :stop],
      # Phx 1.5.3 switched to exception; it was failure before that
      [:phoenix, :router_dispatch, :exception],
      [:phoenix, :router_dispatch, :failure]
    ]
 
    :telemetry.attach_many("spandex-phoenix-telemetry", events, &__MODULE__.handle_event/4, opts)
  end

  def handle_event([:phoenix, :router_dispatch, :start], _, meta, config) do
    %{tracer: tracer, filter_traces: filter_traces, span_name: span_name} = config
    # It's possible the router handed this request to a non-controller plug;
    # we only handle controller actions though, which is what the `is_atom` clauses are testing for
    if is_atom(meta[:plug]) and is_atom(meta[:plug_opts]) and filter_traces.(conn) do
      tracer.start_span(span_name, resource: "#{meta.plug}.#{meta.plug_opts}")
    end
  end

  def handle_event([:phoenix, :router_dispatch, :stop], _, meta, %{tracer: tracer} = config) do
    if tracer.current_trace_id() do
      tracer.finish_span()
    end
  end

  def handle_event([:phoenix, :router_dispatch, _exception], _, meta, %{tracer: tracer} = config) do
    if tracer.current_trace_id() do
      tracer.span_error(meta.error, meta.stacktrace)
      tracer.update_span(error: [error?: true])
      tracer.finish_trace()
    end
  end
end
