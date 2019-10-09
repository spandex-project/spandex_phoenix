defmodule SpandexPhoenix.Instrumenter do
  @moduledoc """
  Phoenix instrumenter callback module to automatically create spans for
  Phoenix Controller and View information.

  Configure your Phoenix `Endpoint` to use this library as one of its
  `instrumenters`:

  ```elixir
  config :my_app, MyAppWeb.Endpoint,
    # ... existing config ...
    instrumenters: [SpandexPhoenix.Instrumenter]
  ```

  More details can be found in [the Phoenix documentation].

  [the Phoenix documentation]: https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#module-phoenix-default-events
  """

  defmacro __using__(opts) do
    quote bind_quoted: [tracer: opts[:tracer], otp_app: opts[:otp_app]] do
      unless tracer || otp_app do
        raise "You must configure a tracer or an otp_app in #{__MODULE__}"
      end

      @tracer tracer
      @otp_app otp_app

      @doc false
      def phoenix_controller_call(step, compiled_meta, %{conn: conn}) do
        tracer = @tracer || Application.get_env(@otp_app, __MODULE__)[:tracer] || raise(@tracer_not_configured_msg)
        SpandexPhoenix.Instrumenter.phoenix_controller_call(step, compiled_meta, %{conn: conn}, tracer: tracer)
      end

      @doc false
      def phoenix_controller_render(step, _compiled_meta, %{view: view}) do
        tracer = @tracer || Application.get_env(@otp_app, __MODULE__)[:tracer] || raise(@tracer_not_configured_msg)
        SpandexPhoenix.Instrumenter.phoenix_controller_render(step, compiled_meta, %{conn: conn}, tracer: tracer)
      end
    end
  end

  @tracer_not_configured_msg "You must configure a :tracer for :spandex_phoenix"

  @doc false
  def phoenix_controller_call(:start, _compiled_meta, %{conn: conn}) do
    tracer = Application.get_env(:spandex_phoenix, :tracer) || raise(@tracer_not_configured_msg)
    apply(tracer, :start_span, ["Phoenix.Controller", [resource: controller_resource_name(conn)]])
  end

  @doc false
  def phoenix_controller_call(:stop, _time_diff, _start_meta) do
    tracer = Application.get_env(:spandex_phoenix, :tracer) || raise(@tracer_not_configured_msg)
    apply(tracer, :finish_span, [])
  end

  @doc false
  def phoenix_controller_render(:start, _compiled_meta, %{view: view}) do
    tracer = Application.get_env(:spandex_phoenix, :tracer) || raise(@tracer_not_configured_msg)
    apply(tracer, :start_span, ["Phoenix.View", [resource: view]])
  end

  @doc false
  def phoenix_controller_render(:stop, _time_diff, _start_meta) do
    tracer = Application.get_env(:spandex_phoenix, :tracer) || raise(@tracer_not_configured_msg)
    apply(tracer, :finish_span, [])
  end

  defp controller_resource_name(conn) do
    if Code.ensure_loaded?(Phoenix) do
      controller = Phoenix.Controller.controller_module(conn)
      action = Phoenix.Controller.action_name(conn)
      "#{controller}.#{action}"
    else
      "unknown.unknown"
    end
  end
end
