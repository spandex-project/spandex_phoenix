defmodule SpandexPhoenix do
  @moduledoc """
  A Plug wrapper for use in a Plug.Router or Phoenix.Endpoint to trace the entire request with Spandex.

  > NOTE: If you want to `use` this in combination with `Plug.ErrorHandler` or
  similar "wrapper" plugs, this one should be last so that it traces the
  effects of the other wrappers.

  Phoenix integration:

  ```elixir
  defmodule MyAppWeb.Endpoint do
    use Phoenix.Endpoint, otp_app: :my_app
    use SpandexPhoenix

    # ...
  end
  ```

  Plug integration:
  ```elixir
  defmodule MyApp.Router do
    use Plug.Router
    use SpandexPhoenix

    # ...
  end
  ```

  ## Options for `use` Macro

  * `:filter_traces` (arity-1 function reference)

      A function that takes a `Plug.Conn` and returns `true` for requests to be
      traced. For example, to only trace certain HTTP methods, you could do
      something like:

      ```elixir
      defmodule MyAppWeb.Endpoint do
        use Phoenix.Endpoint, otp_app: :my_app
        use SpandexPhoenix, filter_traces: &__MODULE__.filter_traces/1

        def filter_traces(conn) do
          conn.method in ~w(DELETE GET POST PUT)
        end
      end
      ```

      > NOTE: Local references to functions in the module being defined (e.g.
      `&function/1`) will not work because the module will not be compiled yet
      when the function is being referenced, so the function does not exist.
      Referencing the local function using `&__MODULE__.function/1` will work,
      however.

      Default: (a private function that always returns `true`)

  * `:span_name` (`String`)

      The name to be used for the top level span.

      Default: `“request”`

  * `:tracer` (`Atom`)

      The tracing module to be used for the trace.

      Default: `Application.get_env(:spandex_phoenix, :tracer)`

  * `:customize_metadata` (arity-1 function reference)

      A function that takes the `Plug.Conn` for the current request and returns
      the desired span options to apply to the top-level span in the trace (as a
      `Keyword`). The `Plug.Conn` is normally evaluated just before the response
      is sent to the client, to ensure that the most-accurate metadata can be
      collected. In cases where there is an unhandled error, it may only
      represent the initial request without any response information.

      For example, if you want a particular path parameter to show its value in
      the `resource` instead of its name, you should do something like:

      ```elixir
      defmodule MyApp.Tracer do
        use Spandex.Tracer, otp_app: :my_app

        def customize_metadata(conn) do
          name = conn.path_params["name"] || ""

          conn
          |> SpandexPhoenix.default_metadata()
          |> Keyword.update(:resource, "", &String.replace(&1, ":name", name))
        end
      end

      defmodule MyAppWeb.Endpoint do
        use Phoenix.Endpoint, otp_app: :my_app
        use SpandexPhoenix, customize_metadata: &MyApp.Tracer.customize_metadata/1
        plug Router

      end
      ```

      > NOTE: Local references to functions in the module being defined (e.g.
      `&function/1`) will not work because the module will not be compiled yet
      when the function is being referenced, so the function does not exist.
      Referencing the local function using `&__MODULE__.function/1` will work,
      however.

      Default: `&SpandexPhoenix.default_metadata/1`
  """

  alias SpandexPhoenix.Plug.{
    AddContext,
    FinishTrace,
    StartTrace
  }

  defmacro __using__(opts) do
    tracer = Keyword.get(opts, :tracer, Application.get_env(:spandex_phoenix, :tracer))
    if is_nil(tracer), do: raise("You must configure a :tracer for :spandex_phoenix")
    opts = Keyword.put(opts, :tracer, tracer)
    start_opts = Keyword.take(opts, [:filter_traces, :span_name, :tracer])
    context_opts = Keyword.take(opts, [:customize_metadata, :tracer])
    finish_opts = Keyword.take(opts, [:tracer])

    quote location: :keep,
          bind_quoted: [
            use_opts: opts,
            tracer: tracer,
            start_opts: start_opts,
            context_opts: context_opts,
            finish_opts: finish_opts
          ] do
      @before_compile SpandexPhoenix
      @use_opts use_opts
      @tracer tracer
      @start_opts StartTrace.init(start_opts)
      @context_opts AddContext.init(context_opts)
      @finish_opts FinishTrace.init(finish_opts)
    end
  end

  defmacro __before_compile__(_env) do
    quote location: :keep do
      defoverridable call: 2

      def call(conn, opts) do
        try do
          conn
          |> StartTrace.call(@start_opts)
          |> Plug.Conn.register_before_send(&AddContext.call(&1, @context_opts))
          |> super(opts)
        rescue
          error in Plug.Conn.WrapperError ->
            SpandexPhoenix.handle_errors(error, @tracer, @context_opts, @finish_opts)
        catch
          kind, reason ->
            error = %{conn: conn, kind: kind, reason: reason, stack: __STACKTRACE__}
            SpandexPhoenix.handle_errors(error, @tracer, @context_opts, @finish_opts)
        else
          conn ->
            FinishTrace.call(conn, @finish_opts)
        end
      end
    end
  end

  @doc """
  """
  @spec default_metadata(Plug.Conn.t()) :: Keyword.t()
  def default_metadata(conn) do
    conn = Plug.Conn.fetch_query_params(conn)

    route = route_name(conn)

    user_agent =
      conn
      |> Plug.Conn.get_req_header("user-agent")
      |> List.first()

    method = String.upcase(conn.method)

    [
      http: [
        method: method,
        query_string: conn.query_string,
        status_code: conn.status,
        url: URI.decode(conn.request_path),
        user_agent: user_agent
      ],
      resource: method <> " " <> route,
      type: :web
    ]
  end

  @spec trace_all_requests(Plug.Conn.t()) :: true
  @doc "Default implementation of the filter_traces function"
  def trace_all_requests(_conn), do: true

  @already_sent {:plug_conn, :sent}

  @doc false
  def handle_errors(error, tracer, context_opts, finish_opts) do
    %{conn: conn, kind: kind, reason: reason, stack: stack} = error

    # If the response has already been sent, `AddContext` has already been called.
    # If not, we need to call it here to set the request metadata.
    conn =
      receive do
        @already_sent ->
          # Make sure we put this back in the mailbox for others.
          send(self(), @already_sent)
          conn
      after
        0 ->
          AddContext.call(conn, context_opts)
      end

    exception =
      case kind do
        :error -> Exception.normalize(kind, reason, stack)
        _ -> %RuntimeError{message: Exception.format_banner(kind, reason)}
      end

    mark_span_as_error(tracer, exception, stack)
    FinishTrace.call(conn, finish_opts)
    :erlang.raise(kind, reason, stack)
  end

  @doc false
  def mark_span_as_error(tracer, %{__struct__: Phoenix.Router.NoRouteError, __exception__: true}, _stack) do
    tracer.update_span(resource: "Not Found")
  end

  def mark_span_as_error(_tracer, %{__struct__: Plug.Parsers.UnsupportedMediaTypeError, __exception__: true}, _stack),
    do: nil

  def mark_span_as_error(tracer, exception, stack) do
    tracer.span_error(exception, stack)
    tracer.update_span(error: [error?: true])
  end

  # Private Helpers

  # Set by Plug.Router
  defp route_name(%Plug.Conn{private: %{plug_route: {route, _fn}}}), do: route

  # Phoenix doesn't set the plug_route for us, so we have to figure it out ourselves
  defp route_name(%Plug.Conn{path_params: path_params, path_info: path_info}) do
    "/" <> Enum.map_join(path_info, "/", &replace_path_param_with_name(path_params, &1))
  end

  defp replace_path_param_with_name(path_params, path_component) do
    decoded_component = URI.decode(path_component)

    Enum.find_value(path_params, decoded_component, fn
      {param_name, ^decoded_component} -> ":#{param_name}"
      _ -> nil
    end)
  end
end
