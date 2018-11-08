defmodule TracerWithPlugRouterTest do
  use ExUnit.Case
  import RouterHelper

  defmodule Router do
    use Plug.Router
    use SpandexPhoenix

    plug(:match)
    plug(:dispatch)

    get "/hello" do
      send_resp(conn, 200, "world")
    end

    get "/hello/:name" do
      send_resp(conn, 200, name)
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
  end

  describe "SpandexPhoenix used with Plug.Router" do
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

    test "traces successful requests with path params" do
      call(Router, :get, "/hello/spandex")

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
      assert_raise RuntimeError, fn -> call(Router, :get, "/exception") end

      assert_receive {
        :sent_trace,
        %Spandex.Trace{
          spans: [
            %Spandex.Span{error: error, http: http, name: "request", resource: "GET /exception"}
          ]
        }
      }

      assert "GET" == Keyword.get(http, :method)
      assert nil == Keyword.get(http, :status_code)
      assert "/exception" == Keyword.get(http, :url)

      assert %RuntimeError{message: "Test"} = Keyword.get(error, :exception)
      assert is_list(Keyword.get(error, :stacktrace))
      assert Keyword.get(error, :error?)
    end

    test "sends an error trace when the worker process exits" do
      assert catch_exit(call(Router, :get, "/exit")) == "Test"

      assert_receive {
        :sent_trace,
        %Spandex.Trace{
          spans: [
            %Spandex.Span{error: error, http: http, name: "request", resource: "GET /exit"}
          ]
        }
      }

      assert "GET" == Keyword.get(http, :method)
      assert nil == Keyword.get(http, :status_code)
      assert "/exit" == Keyword.get(http, :url)

      assert %RuntimeError{message: "** (exit) \"Test\""} = Keyword.get(error, :exception)
      assert is_list(Keyword.get(error, :stacktrace))
      assert Keyword.get(error, :error?)
    end

    test "sends an error trace when an error is thrown and not caught" do
      assert catch_throw(call(Router, :get, "/throw")) == "Test"

      assert_receive {
        :sent_trace,
        %Spandex.Trace{
          spans: [
            %Spandex.Span{error: error, http: http, name: "request", resource: "GET /throw"}
          ]
        }
      }

      assert "GET" == Keyword.get(http, :method)
      assert nil == Keyword.get(http, :status_code)
      assert "/throw" == Keyword.get(http, :url)

      assert %RuntimeError{message: "** (throw) \"Test\""} = Keyword.get(error, :exception)
      assert is_list(Keyword.get(error, :stacktrace))
      assert Keyword.get(error, :error?)
    end
  end
end
