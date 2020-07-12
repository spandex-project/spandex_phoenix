defmodule SpandexPhoenix.Telemetry do
  @moduledoc """
  Defines the `:telemetry` handlers to attach tracing to Phoenix Telemetry.
  """

  alias Spandex.SpanContext

  @doc """
  Installs `:telemetry` event handlers for Phoenix Telemetry events.

  ### Options

  * `:endpoint_telemetry_prefix` (`Atom`)

      The telemetry prefix passed to `Plug.Telemetry` in the endpoint you want to trace.

      Default: `[:phoenix, :endpoint]`

  * `:tracer` (`Atom`)

      The tracing module to be used for traces in your Endpoint.

      Default: `Application.get_env(:spandex_phoenix, :tracer)`

  * `:filter_traces` (`fun((Plug.Conn.t()) -> boolean)`)

      A function that takes a conn and returns true if a trace should be created
      for that conn, and false if it should be ignored.

      Default: `&SpandexPhoenix.trace_all_requests/1`

  * `:span_name` (`String.t()`)

      The name for the span this module creates.

      Default: `"request"`

  * `:customize_metadata` (`fun((Plug.Conn.t()) -> Keyword.t())`)

      A function that takes a conn and returns a keyword list of metadata.

      Default: `&SpandexPhoenix.default_metadata/1`
  """
  def install(opts \\ []) do
    unless function_exported?(:telemetry, :attach_many, 4) do
      raise "Cannot install telemetry events without `:telemetry` dependency." <>
              "Did you mean to use the Phoenix Instrumenters integration instead?"
    end

    filter_traces = Keyword.get(opts, :filter_traces, &SpandexPhoenix.trace_all_requests/1)
    customize_metadata = Keyword.get(opts, :customize_metadata, &SpandexPhoenix.default_metadata/1)
    endpoint_prefix = Keyword.get(opts, :endpoint_telemetry_prefix, [:phoenix, :endpoint])
    span_name = Keyword.get(opts, :span_name, "request")

    tracer =
      Keyword.get_lazy(opts, :tracer, fn ->
        Application.get_env(:spandex_phoenix, :tracer)
      end)

    unless tracer do
      raise ArgumentError, "`:tracer` option must be provided or configured in `:spandex_phoenix`"
    end

    opts = %{tracer: tracer, filter_traces: filter_traces, customize_metadata: customize_metadata, span_name: span_name}

    endpoint_events = [
      endpoint_prefix ++ [:start],
      endpoint_prefix ++ [:stop]
    ]

    :telemetry.attach_many("spandex-endpoint-telemetry", endpoint_events, &__MODULE__.handle_endpoint_event/4, opts)

    router_events = [
      [:phoenix, :router_dispatch, :start],
      [:phoenix, :router_dispatch, :stop],
      [:phoenix, :router_dispatch, :exception]
    ]

    :telemetry.attach_many("spandex-router-telemetry", router_events, &__MODULE__.handle_router_event/4, opts)
  end

  def handle_endpoint_event(event, _, %{conn: conn}, %{tracer: tracer} = config) do
    case List.last(event) do
      :start -> start_trace(tracer, conn, config)
      :stop -> finish_trace(tracer, conn, config)
    end
  end

  defp start_trace(tracer, conn, %{span_name: span_name}) do
    case tracer.distributed_context(conn, []) do
      {:ok, %SpanContext{} = span} ->
        tracer.continue_trace(span_name, span, [])

      {:error, _} ->
        tracer.start_trace(span_name, [])
    end
  end

  defp finish_trace(tracer, conn, %{customize_metadata: customize_metadata}) do
    if tracer.current_trace_id() do
      conn
      |> customize_metadata.()
      |> tracer.update_top_span()

      tracer.finish_trace()
    end
  end

  @doc false
  def handle_router_event([_, _, :start], _, meta, %{tracer: tracer}) do
    # It's possible the router handed this request to a non-controller plug;
    # we only handle controller actions though, which is what the `is_atom` clauses are testing for
    if tracer.current_trace_id() && phx_controller?(meta) do
      tracer.start_span("phx.router_dispatch", resource: "#{meta.plug}.#{meta.plug_opts}")
    end
  end

  def handle_router_event([_, _, :stop], _, _, %{tracer: tracer}) do
    if tracer.current_trace_id() do
      tracer.finish_span()
    end
  end

  def handle_router_event([_, _, :exception], _, meta, %{tracer: tracer} = config) do
    # phx 1.5.4-dev has a breaking change that switches `:error` to `:reason`
    # maybe they'll see "reason" and keep using the old key too, but for now here's this
    error = meta[:reason] || meta[:error]

    if tracer.current_trace_id() do
      SpandexPhoenix.mark_span_as_error(tracer, error, meta.stack_trace)

      # @TODO unclear if traces need to be finished here, or if they'll still hit endpoint stop?
      finish_trace(tracer, meta.conn, config)
    end
  end

  defp phx_controller?(meta) do
    is_atom(meta[:plug]) and is_atom(meta[:plug_opts])
  end
end
