defmodule SpandexPhoenix.Telemetry do
  @moduledoc """
  Defines the `:telemetry` handlers to attach tracing to Phoenix Telemetry.
  """

  @doc """
  Attaches `:telemetry` event handlers for Phoenix Telemetry events.

  ### Options

  * `:tracer` (`Atom`)

      The tracing module to be used for traces in your Endpoint.

      Default: `Application.get_env(:spandex_phoenix, :tracer)`

  * `:endpoint_prefix` (`[atom]`)

      The prefix passed to Plug.Telemetry in your Endpoint.

      Default: `[:phoenix, :endpoint]`
  """
  def attach(opts \\ []) do
    tracer =
      Keyword.get_lazy(opts, :tracer, fn ->
        Application.get_env(:spandex_phoenix, :tracer)
      end)

    unless tracer do
      raise ArgumentError, ":tracer option must be provided or configured in :spandex_phoenix"
    end

    endpoint_prefix = Keyword.get(opts, :endpoint_prefix, [:phoenix, :endpoint])
    filter_traces = Keyword.get(opts, :filter_traces, fn _ -> true end)
    customize_metadata = Keyword.get(opts, :customize_metadata, &Spandex.default_metadata/1)
    span_name = Keyword.get(opts, :span_name, "request")

    opts = %{tracer: tracer, filter_traces: filter_traces, customize_metadata: customize_metadata, span_name: span_name}

    handlers = %{
      (endpoint_prefix ++ [:start]) => &phoenix_endpoint_start/4,
      (endpoint_prefix ++ [:stop]) => &phoenix_endpoint_stop/4,
      [:phoenix, :router_dispatch, :start] => &phoenix_router_dispatch_start/4,
      [:phoenix, :router_dispatch, :stop] => &phoenix_router_dispatch_stop/4,
      [:phoenix, :router_dispatch, :exception] => &phoenix_router_dispatch_exception/4,
      [:phoenix, :error_rendered] => &phoenix_error_rendered/4
    }

    for {event, handler} <- handlers, handler_id = handler_id(event) do
      :telemetry.attach(handler_id, event, handler, %{tracer: tracer})
    end
  end

  defp phoenix_router_dispatch_start(_, _, %{conn: conn}, %{tracer: tracer}) do
    tracer.start_span("Phoenix.Controller", resource: SpandexPhoenix.controller_resource_name(conn))
  end

  defp phoenix_router_dispatch_stop(_, _, %{conn: conn}, %{tracer: tracer}) do
    tracer.finish_span()
  end

  defp phoenix_router_dispatch_exception(_, _, metadata, %{tracer: tracer}) do
    # ruh roh.

    # e in Plug.Conn.WrapperError ->
    # metadata = %{kind: :error, error: e, stacktrace: __STACKTRACE__}
    # if it's a Plug.Conn.WrapperError...
    # %{conn: conn, kind: kind, reason: reason, stack: stack} = e
  end

  defp phoenix_error_rendered(_, _, metadata, %{tracer: tracer}) do
    # metadata = %{status: status, kind: kind, reason: reason, stacktrace: stack, log: level}

    # !??! what's the relationship between router dispatch exception and this??
    # one thing: if the response has already been sent, this isn't displayed.
    # probably it's just safe to do the `if tracer.id do` in both situations
    # and call it good?
    # or should it be,
    # in router dispatch Exception
    #   if already sent -> finish trace
    #   else -> assume error_rendered will handle it?
  end

  defp phoenix_endpoint_start(_, _, %{conn: conn}, %{tracer: tracer} = config) do
    %{span_name: span_name, filter_traces: filter_traces} = config

    if filter_traces.(conn) do
      case tracer.distributed_context(conn) do
        {:ok, %SpanContext{} = span_context} ->
          tracer.continue_trace(span_name, span_context)

        {:error, _} ->
          tracer.start_trace(span_name)
      end
    end
  end

  defp phoenix_endpoint_stop(_, _, %{conn: conn}, %{tracer: tracer} = config) do
    if tracer.current_trace_id() do
      conn
      |> config.customize_metadata.()
      |> tracer.update_top_span()
      |> tracer.finish_trace()
    end
  end

  defp handler_id(event), do: {__MODULE__, event}
end
