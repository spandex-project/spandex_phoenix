defmodule SpandexPhoenix.Instrumenter do
  @moduledoc """
  Phoenix instrumenter callback module
  """

  @tracer Application.get_env(:spandex_phoenix, :tracer) || raise "You must configure a :tracer for :spandex_phoenix"

  def phoenix_controller_call(:start, _compiled_meta, %{conn: conn}) do
    controller = Phoenix.Controller.controller_module(conn)
    action = Phoenix.Controller.action_name(conn)
    @tracer.start_span("Phoenix.Controller", resource: "#{controller}.#{action}")
  end

  def phoenix_controller_call(:stop, _time_diff, _start_meta) do
    @tracer.finish_span()
  end

  def phoenix_controller_render(:start, _compiled_meta, %{view: view}) do
    @tracer.start_span("Phoenix.View", resource: view)
  end

  def phoenix_controller_render(:stop, _time_diff, _start_meta) do
    @tracer.finish_span()
  end
end
