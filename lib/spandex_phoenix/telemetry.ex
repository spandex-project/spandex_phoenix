defmodule SpandexPhoenix.Telemetry do
  @moduledoc """
  Defines
  """

  @doc "Attaches `:telemetry` event handlers for Phoenix Telemetry events."
  def attach(opts \\ []) do
    handlers = %{
      [:phoenix, :router_dispatch, :start] => &phoenix_router_dispatch_start/4,
      [:phoenix, :router_dispatch, :stop] => &phoenix_router_dispatch_stop/4
    }

    tracer = Keyword.get_lazy(opts, :tracer, fn -> Application.get_env(:spandex_phoenix, :tracer) end)

    for {event, handler} <- handlers, handler_id = handler_id(event) do
      :telemetry.attach(handler_id, event, handler, %{tracer: tracer})
    end
  end

  @tracer_not_configured_msg "You must configure a :tracer for :spandex_phoenix"

  defp phoenix_router_dispatch_start(_, _, %{conn: conn}, %{tracer: tracer}) do
    tracer = tracer || Application.get_env(:spandex_phoenix, :tracer) || raise(@tracer_not_configured_msg)
    args = ["Phoenix.Controller", [resource: SpandexPhoenix.controller_resource_name(conn)]]
    apply(tracer, :start_span, args)
  end

  defp phoenix_router_dispatch_stop(_, _, %{conn: conn}, %{tracer: tracer}) do
    tracer = tracer || Application.get_env(:spandex_phoenix, :tracer) || raise(@tracer_not_configured_msg)
    apply(tracer, :finish_span, [])
  end

  defp handler_id(event), do: {__MODULE__, event}
end
