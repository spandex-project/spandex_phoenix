defmodule FinishTracePlugTest do
  use ExUnit.Case

  import RouterHelper

  alias SpandexPhoenix.Plug.{
    AddContext,
    FinishTrace,
    StartTrace
  }

  describe "SpandexPhoenix.Plug.FinishTrace" do
    test "finishes a trace using the default Tracer" do
      refute TestTracer.current_span()

      StartTrace
      |> call(:get, "/")
      |> AddContext.call(AddContext.init([]))
      |> FinishTrace.call(FinishTrace.init([]))

      refute TestTracer.current_span()

      assert_receive {
        :sent_trace,
        %Spandex.Trace{
          spans: [
            %Spandex.Span{name: "request", resource: "GET /"}
          ]
        }
      }
    end

    test "allows the tracer to be overridden" do
      defmodule AnotherTracer do
        use Spandex.Tracer, otp_app: :another_app
      end

      config = [
        adapter: TestAdapter,
        service: :another_service,
        type: :web
      ]

      Application.put_env(:another_app, __MODULE__.AnotherTracer, config)
      refute TestTracer.current_span()

      StartTrace
      |> call(:get, "/", tracer: AnotherTracer)
      |> AddContext.call(AddContext.init(tracer: AnotherTracer))
      |> FinishTrace.call(FinishTrace.init(tracer: AnotherTracer))

      assert_receive {
        :sent_trace,
        %Spandex.Trace{
          spans: [
            %Spandex.Span{
              name: "request",
              resource: "GET /",
              service: :another_service
            }
          ]
        }
      }
    end
  end
end
