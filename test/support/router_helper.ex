defmodule RouterHelper do
  @moduledoc false

  def call(router, verb, path, opts \\ []) do
    verb
    |> Plug.Test.conn(path)
    |> router.call(router.init(opts))
  end
end
