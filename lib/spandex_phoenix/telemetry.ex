defmodule SpandexPhoenix.Telemetry do
  @moduledoc """
  Defines the `:telemetry` handlers to attach tracing to Phoenix Telemetry.

  See `install/1` documentation for usage.
  """

  alias Spandex.SpanContext

  @doc """
  Installs `:telemetry` event handlers for Phoenix Telemetry events.

  `Plug.Telemetry` must be included in your endpoint or router for traces to
  function properly. If you upgraded to Phoenix 1.5, you must add the plug yourself.
  The Phoenix 1.5 installer includes the plug in your endpoint automatically.

  ### Options

  * `:tracer` (`Atom`)

      The tracing module to be used for traces in your Endpoint.

      Default: `Application.get_env(:spandex_phoenix, :tracer)`

  * `:endpoint_telemetry_prefix` (`Atom`)

      The telemetry prefix passed to `Plug.Telemetry` in the endpoint you want to trace.

      Default: `[:phoenix, :endpoint]`

  * `:filter_traces` (`fun((Plug.Conn.t()) -> boolean)`)

      A function that takes a conn and returns true if a trace should be created
      for that conn, and false if it should be ignored.

      Default: `&SpandexPhoenix.trace_all_requests/1`

  * `:span_name` (`String.t()`)

      The name for the span this module creates.

      Default: `"request"`

  * `:span_opts` (`Spandex.Tracer.opts()`)

      A list of span options to pass during the creation or continuation of
      the top level span.

      Default: `[type: :web]`

  * `:customize_metadata` (`fun((Plug.Conn.t()) -> Keyword.t())`)

      A function that takes a conn and returns a keyword list of metadata.

      Default: `&SpandexPhoenix.default_metadata/1`
  """
  def install(opts \\ []) do
    unless function_exported?(:telemetry, :attach_many, 4) do
      raise "Cannot install telemetry events without `:telemetry` dependency." <>
              "Did you mean to use the Phoenix Instrumenters integration instead?"
    end

    {filter_traces, opts} = Keyword.pop(opts, :filter_traces, &SpandexPhoenix.trace_all_requests/1)
    {customize_metadata, opts} = Keyword.pop(opts, :customize_metadata, &SpandexPhoenix.default_metadata/1)
    {endpoint_prefix, opts} = Keyword.pop(opts, :endpoint_telemetry_prefix, [:phoenix, :endpoint])
    {span_name, opts} = Keyword.pop(opts, :span_name, "request")
    {span_opts, opts} = Keyword.pop(opts, :span_opts, type: :web)

    {tracer, opts} =
      Keyword.pop_lazy(opts, :tracer, fn ->
        Application.get_env(:spandex_phoenix, :tracer)
      end)

    unless tracer do
      raise ArgumentError, "`:tracer` option must be provided or configured in `:spandex_phoenix`"
    end

    unless Enum.empty?(opts) do
      raise ArgumentError, "Unknown options: #{inspect(Keyword.keys(opts))}"
    end

    opts = %{
      customize_metadata: customize_metadata,
      filter_traces: filter_traces,
      span_name: span_name,
      span_opts: span_opts,
      tracer: tracer
    }

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

  @doc false
  def handle_endpoint_event(event, _, %{conn: conn}, %{tracer: tracer} = config) do
    if trace?(conn, config) do
      case List.last(event) do
        :start -> start_trace(tracer, conn, config)
        :stop -> finish_trace(tracer, conn, config)
      end
    end
  end

  defp trace?(conn, %{filter_traces: filter_traces}), do: filter_traces.(conn)

  defp start_trace(tracer, conn, %{span_name: name, span_opts: opts}) do
    case tracer.distributed_context(conn) do
      {:ok, %SpanContext{} = span} ->
        tracer.continue_trace(name, span, opts)

      {:error, _} ->
        tracer.start_trace(name, opts)
    end
  end

  defp finish_trace(tracer, conn, %{customize_metadata: customize_metadata}) do
    conn
    |> customize_metadata.()
    |> tracer.update_top_span()

    tracer.finish_trace()
  end

  @doc false
  def handle_router_event([:phoenix, :router_dispatch, :start], _, meta, %{tracer: tracer}) do
    if phx_controller?(meta) do
      tracer.start_span("phx.router_dispatch", resource: "#{meta.plug}.#{meta.plug_opts}")
    end
  end

  def handle_router_event([:phoenix, :router_dispatch, :stop], _, meta, %{tracer: tracer}) do
    if phx_controller?(meta) do
      tracer.finish_span()
    end
  end

  def handle_router_event([:phoenix, :router_dispatch, :exception], _, meta, %{tracer: tracer}) do
    # phx 1.5.3 has a breaking change that switches `:error` to `:reason`
    error = meta[:reason] || meta[:error]

    # :phoenix :router_dispatch :exception has far fewer keys in its metadata
    # (just `kind`, `error/reason`, and `stacktrace`)
    # so we can't use `phx_controller?` or `filter_traces` to detect if we are tracing
    if tracer.current_trace_id() do
      SpandexPhoenix.mark_span_as_error(tracer, error, meta.stacktrace)
      tracer.finish_span()
    end
  end

  # It's possible the router handed this request to a non-controller plug;
  # we only handle controller actions though, which is what the `is_atom` clauses are testing for
  defp phx_controller?(meta) do
    is_atom(meta[:plug]) and is_atom(meta[:plug_opts])
  end
end
