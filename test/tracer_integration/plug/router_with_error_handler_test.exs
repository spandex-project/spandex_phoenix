defmodule TracerWithPlugRouterAndErrorHandlerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  import RouterHelper

  defmodule Router do
    use Plug.Router
    use Plug.ErrorHandler
    use SpandexPhoenix

    require Logger

    plug(:match)
    plug(:dispatch)

    get "/hello" do
      send_resp(conn, 200, "world")
    end

    get "/exception" do
      raise "Test"
      send_resp(conn, 200, "Won't get here")
    end

    get "/exit" do
      exit("Test")
      send_resp(conn, 200, "Won't get here")
    end

    get "/throw" do
      throw("Test")
      send_resp(conn, 200, "Won't get here")
    end

    match _ do
      send_resp(conn, 404, "oops")
    end

    def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
      Logger.error("Error logged by Router.handle_errors/2")
      send_resp(conn, conn.status, "Internal Server Error")
    end
  end

  describe "SpandexPhoenix with Plug.Router and Plug.ErrorHandler" do
    test "traces successful requests" do
      call(Router, :get, "/hello")

      assert_receive {
        :sent_trace,
        %Spandex.Trace{
          spans: [
            %Spandex.Span{
              http: http,
              name: "request",
              resource: "GET /hello",
              service: :spandex_phoenix,
              tags: [],
              type: :web
            }
          ]
        }
      }

      assert "GET" == Keyword.get(http, :method)
      assert 200 == Keyword.get(http, :status_code)
      assert "/hello" == Keyword.get(http, :url)
    end

    test "sends an error trace when an exception is raised" do
      log =
        capture_log(fn ->
          assert_raise RuntimeError, fn -> call(Router, :get, "/exception") end
        end)

      assert log =~ ~r|Error logged by Router.handle_errors/2|

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

      assert %RuntimeError{message: "Test"} = Keyword.get(error, :exception)
      assert is_list(Keyword.get(error, :stacktrace))
      assert Keyword.get(error, :error?)
    end

    test "sends an error trace when the worker process exits" do
      log =
        capture_log(fn ->
          assert catch_exit(call(Router, :get, "/exit")) == "Test"
        end)

      assert log =~ ~r|Error logged by Router.handle_errors/2|

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
          assert catch_throw(call(Router, :get, "/throw")) == "Test"
        end)

      assert log =~ ~r|Error logged by Router.handle_errors/2|

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
  end
end
