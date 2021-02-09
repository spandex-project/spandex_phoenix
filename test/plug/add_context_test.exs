defmodule AddContextPlugTest do
  use ExUnit.Case

  import RouterHelper

  alias SpandexPhoenix.Plug.{
    AddContext,
    StartTrace
  }

  describe "SpandexPhoenix.Plug.AddContext" do
    test "sets default metadata using the default Tracer" do
      refute TestTracer.current_span()

      StartTrace
      |> call(:get, "/path/to/something?key=value&another=42")
      |> Plug.Conn.put_req_header("user-agent", "Chrome")
      |> Plug.Conn.put_status(200)
      |> AddContext.call(AddContext.init([]))

      assert %Spandex.Span{
               http: [
                 method: "GET",
                 query_string: "key=value&another=42",
                 status_code: 200,
                 url: "/path/to/something",
                 user_agent: "Chrome"
               ],
               name: "request",
               resource: "GET /path/to/something",
               type: :web
             } = TestTracer.current_span()
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

      assert %Spandex.Span{
               resource: "GET /",
               service: :another_service
             } = AnotherTracer.current_span()

      refute TestTracer.current_span()
    end

    test "allows customization of the metadata" do
      defmodule M do
        @doc "Add a custom tag and delete :url from :http"
        def fun(conn) do
          conn
          |> SpandexPhoenix.default_metadata()
          |> Keyword.put(:tags, custom_tag: 42)
          |> Keyword.update(:http, nil, fn http -> Keyword.delete(http, :url) end)
        end
      end

      refute TestTracer.current_span()

      StartTrace
      |> call(:get, "/path/to/something?key=value&another=42")
      |> Plug.Conn.put_req_header("user-agent", "Chrome")
      |> Plug.Conn.put_status(200)
      |> AddContext.call(AddContext.init(customize_metadata: &M.fun/1))

      assert %Spandex.Span{
               http: [
                 method: "GET",
                 query_string: "key=value&another=42",
                 status_code: 200,
                 user_agent: "Chrome"
               ],
               name: "request",
               resource: "GET /path/to/something",
               tags: [custom_tag: 42],
               type: :web
             } = TestTracer.current_span()
    end

    test "only updates the root span" do
      refute TestTracer.current_span()
      TestTracer.start_trace("request")
      TestTracer.start_span("child_span", resource: "child resource")
      call(AddContext, :get, "/")
      assert %Spandex.Span{name: "child_span", resource: "child resource"} = TestTracer.current_span()
      TestTracer.finish_span()
      assert %Spandex.Span{name: "request", resource: "GET /"} = TestTracer.current_span()
    end
  end
end
