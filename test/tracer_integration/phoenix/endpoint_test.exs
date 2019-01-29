defmodule TracerWithPhoenixEndpointTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  import RouterHelper

  defmodule Controller do
    use Phoenix.Controller

    def exception(conn, _params) do
      raise "Test"
      text(conn, "Won't get here")
    end

    def exit(conn, _params) do
      exit("Test")
      text(conn, "Won't get here")
    end

    def hello(conn, %{"name" => name}), do: text(conn, name)

    def hello(conn, _params), do: text(conn, "hello")

    def throw(conn, _params) do
      throw("Test")
      text(conn, "Won't get here")
    end
  end

  defmodule ErrorView do
    def render("404.html", _) do
      "404 not found"
    end

    def render("500.html", %{kind: kind, reason: reason}) do
      "500: #{inspect(kind)}, #{inspect(reason)}"
    end
  end

  defmodule Router do
    use Phoenix.Router
    get("/exception", Controller, :exception)
    get("/exit", Controller, :exit)
    get("/hello", Controller, :hello)
    get("/hello/:name", Controller, :hello)
    get("/throw", Controller, :throw)
  end

  # Just enough to make it work and eliminate warnings
  Application.put_env(:spandex_phoenix, __MODULE__.Endpoint, [])

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :spandex_phoenix
    use SpandexPhoenix
    plug(Router)
  end

  setup_all do
    {:ok, _pid} = Endpoint.start_link()
    :ok
  end

  describe "SpandexPhoenix with Phoenix.Endpoint and Phoenix.Router" do
    test "traces successful requests" do
      log =
        capture_log(fn ->
          conn = call(Endpoint, :get, "/hello")

          assert conn.status == 200
          assert conn.resp_body == "hello"
        end)

      assert log =~ ~r|Processing with TracerWithPhoenixEndpointTest.Controller.hello/2|

      assert_receive {
        :sent_trace,
        %Spandex.Trace{
          spans: [
            %Spandex.Span{
              http: http,
              name: "request",
              resource: "GET /hello",
              service: :spandex_phoenix,
              type: :web
            }
          ]
        }
      }

      assert "GET" == Keyword.get(http, :method)
      assert 200 == Keyword.get(http, :status_code)
      assert "/hello" == Keyword.get(http, :url)
    end

    test "traces successful requests with path params" do
      log =
        capture_log(fn ->
          conn = call(Endpoint, :get, "/hello/spandex")

          assert conn.status == 200
          assert conn.resp_body == "spandex"
        end)

      assert log =~ ~r|Processing with TracerWithPhoenixEndpointTest.Controller.hello/2|

      assert_receive {
        :sent_trace,
        %Spandex.Trace{
          spans: [
            %Spandex.Span{
              http: http,
              name: "request",
              resource: "GET /hello/:name",
              service: :spandex_phoenix,
              tags: [],
              type: :web
            }
          ]
        }
      }

      assert "GET" == Keyword.get(http, :method)
      assert 200 == Keyword.get(http, :status_code)
      assert "/hello/spandex" == Keyword.get(http, :url)
    end

    test "sends an error trace when an exception is raised" do
      log =
        capture_log(fn ->
          assert_raise RuntimeError, fn -> call(Endpoint, :get, "/exception") end
        end)

      assert log =~ ~r|Processing with TracerWithPhoenixEndpointTest.Controller.exception/2|

      assert_receive {
        :sent_trace,
        %Spandex.Trace{
          spans: [
            %Spandex.Span{error: error, http: http, name: "request", resource: "GET /exception"}
          ]
        }
      }

      assert "GET" == Keyword.get(http, :method)
      assert 500 == Keyword.get(http, :status_code)
      assert "/exception" == Keyword.get(http, :url)

      assert %RuntimeError{} = Keyword.get(error, :exception)
      assert is_list(Keyword.get(error, :stacktrace))
      assert Keyword.get(error, :error?)
    end

    test "sends an error trace when the worker process exits" do
      log =
        capture_log(fn ->
          assert catch_exit(call(Endpoint, :get, "/exit")) == "Test"
        end)

      assert log =~ ~r|Processing with TracerWithPhoenixEndpointTest.Controller.exit/2|

      assert_receive {
        :sent_trace,
        %Spandex.Trace{
          spans: [
            %Spandex.Span{error: error, http: http, name: "request", resource: "GET /exit"}
          ]
        }
      }

      assert "GET" == Keyword.get(http, :method)
      assert 500 == Keyword.get(http, :status_code)
      assert "/exit" == Keyword.get(http, :url)

      assert %RuntimeError{message: "** (exit) \"Test\""} = Keyword.get(error, :exception)
      assert is_list(Keyword.get(error, :stacktrace))
      assert Keyword.get(error, :error?)
    end

    test "sends an error trace when an error is thrown and not caught" do
      log =
        capture_log(fn ->
          assert catch_throw(call(Endpoint, :get, "/throw")) == "Test"
        end)

      assert log =~ ~r|Processing with TracerWithPhoenixEndpointTest.Controller.throw/2|

      assert_receive {
        :sent_trace,
        %Spandex.Trace{
          spans: [
            %Spandex.Span{error: error, http: http, name: "request", resource: "GET /throw"}
          ]
        }
      }

      assert "GET" == Keyword.get(http, :method)
      assert 500 == Keyword.get(http, :status_code)
      assert "/throw" == Keyword.get(http, :url)

      assert %RuntimeError{message: "** (throw) \"Test\""} = Keyword.get(error, :exception)
      assert is_list(Keyword.get(error, :stacktrace))
      assert Keyword.get(error, :error?)
    end

    test "renames trace to RouteNotFound when Phoenix raises NoRouteError" do
      assert_raise Phoenix.Router.NoRouteError, fn -> call(Endpoint, :get, "/not_found") end

      assert_receive {
        :sent_trace,
        %Spandex.Trace{
          spans: [
            %Spandex.Span{error: error, http: http, name: "request", resource: "Not Found"}
          ]
        }
      }

      assert "GET" == Keyword.get(http, :method)
      assert 404 == Keyword.get(http, :status_code)
      assert "/not_found" == Keyword.get(http, :url)

      assert %Phoenix.Router.NoRouteError{
               message: "no route found for GET /not_found (TracerWithPhoenixEndpointTest.Router)"
             } = Keyword.get(error, :exception)

      assert is_list(Keyword.get(error, :stacktrace))
      assert Keyword.get(error, :error?)
    end

    test "allows customizing metadata" do
      Application.put_env(:spandex_phoenix, __MODULE__.EndpointWithCustomizedMetadata, [])

      defmodule EndpointWithCustomizedMetadata do
        use Phoenix.Endpoint, otp_app: :spandex_phoenix
        use SpandexPhoenix, customize_metadata: &__MODULE__.customize_metadata/1
        plug(Router)

        def customize_metadata(conn) do
          name = conn.path_params["name"] || ""

          conn
          |> SpandexPhoenix.default_metadata()
          |> Keyword.update(:resource, "", &String.replace(&1, ":name", name))
        end
      end

      {:ok, _pid} = EndpointWithCustomizedMetadata.start_link()

      assert capture_log(fn ->
               call(EndpointWithCustomizedMetadata, :get, "/hello/spandex")
             end) =~ ~r|Processing with TracerWithPhoenixEndpointTest.Controller.hello/2|

      assert_receive {
        :sent_trace,
        %Spandex.Trace{
          spans: [
            %Spandex.Span{resource: "GET /hello/spandex"}
          ]
        }
      }
    end

    test "handles non-ASCII characters in path params" do
      assert capture_log(fn ->
               call(Endpoint, :get, "/hello/%f0%9f%a4%af")
             end) =~ ~r|Processing with TracerWithPhoenixEndpointTest.Controller.hello/2|

      assert_receive {
        :sent_trace,
        %Spandex.Trace{
          spans: [
            %Spandex.Span{
              resource: "GET /hello/:name",
              http: http
            }
          ]
        }
      }

      assert Keyword.get(http, :url) == "/hello/🤯"
    end

    test "validates the options passed to the use macro" do
      Application.put_env(:spandex_phoenix, __MODULE__.EndpointWithInvalidFilterTraces, [])

      assert_raise ArgumentError, "Opt Validation Error: filter_traces - must be of type {:function, 1}", fn ->
        defmodule EndpointWithInvalidFilterTraces do
          use Phoenix.Endpoint, otp_app: :spandex_phoenix
          use SpandexPhoenix, filter_traces: &__MODULE__.customize_metadata/2

          def customize_metadata(conn, _extra_arg), do: []
        end
      end
    end
  end
end
