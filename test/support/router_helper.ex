defmodule RouterHelper do
  @moduledoc false

  def call(router, verb, path, opts \\ []) do
    conn = Plug.Test.conn(verb, path)

    conn =
      case Keyword.get(opts, :content_type) do
        nil -> conn
        content_type -> Plug.Conn.put_req_header(conn, "content-type", content_type)
      end

    router.call(conn, router.init(opts))
  end
end
