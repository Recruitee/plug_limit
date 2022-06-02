# Unit testing

PlugLimit architecture is based on a single check-and-set Redis Lua scripts to simplify library
configuration and usage.
Because there are no functions resetting, listing or deleting individual rate-limiters, unit testing
PlugLimit implementations in user applications might require specific approach.
Suggested example user application unit testing strategy is provided below.

Example user application controller where `:index` action is protected with PlugLimit token bucket
rate-limiter:
```elixir
defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller

  plug(
    PlugLimit,
    [
      limiter: :token_bucket,
      opts: [10, 60, 3],
      key: {__MODULE__, :static_key, "page_controller:index"}
    ]
    when action in [:index]
  )

  def index(conn, _params), do: send_resp(conn, 200, "OK")

  def static_key(_conn, prefix), do: {:ok, ["#{prefix}:key"]}
end
```

Example unit test for controller defined above:
```elixir
defmodule MyAppWeb.PageControllerTest do
  use MyAppWeb.ConnCase
  alias MyApp.Test.PlugLimitHelper

  describe "index" do
    setup %{} do
      :ok = PlugLimitHelper.del_redis_keys("page_controller:index:*")
    end

    test "it is protected by rate limiter", %{conn: conn} do
      assert conn |> get("/") |> PlugLimitHelper.ratelimit_headers_exist?()
    end
  end
end
```

Test is asserting that controller action is protected by rate limiter by ensuring that required
rate-limiting http headers were inserted to the request response.
In a test `setup` Redis keys associated with rate limiter are deleted to avoid situation where some
of the unit tests would fail due to exceeded requests limit. Alternative solution could be using
unique rate-limiting buckets names in each unit test.

PlugLimit helpers used in the unit tests module above can be defined as follows:
```elixir
#test/test_helper.exs
ExUnit.start()

defmodule MyApp.Test.PlugLimitHelper do
  @redis_del_script """
  return redis.call('DEL', 'default:not:existing:key:*', unpack(redis.call('KEYS', ARGV[1])))
  """
  @doc """
  Deletes all Redis keys with names matching pattern given by `key`.
  Returns `:error` if encountered any errors, `:ok` otherwise.
  """
  @spec del_redis_keys(key :: String.t()) :: :ok | :error
  def del_redis_keys(key) do
    case Rt.Redix.command(["EVAL", @redis_del_script, "0", [key]]) do
      {:ok, _key_count} -> :ok
      _ -> :error
    end
  end

  @doc """
  Checks if basic rate limiting http response headers complying with
  ["RateLimit Fields for HTTP"](https://datatracker.ietf.org/doc/draft-ietf-httpapi-ratelimit-headers/)
  IETF specification are added to `Plug.Conn.t()`.
  Returns `true` if required rate limiting http response headers exist and `false` otherwise.
  """
  @spec ratelimit_headers_exist?(conn :: Plug.Conn.t()) :: boolean()
  def ratelimit_headers_exist?(conn) do
    ["x-ratelimit-limit", "x-ratelimit-remaining", "x-ratelimit-reset"]
    |> Enum.map(fn hdr ->
      conn
      |> Plug.Conn.get_resp_header(hdr)
      |> Enum.empty?()
      |> Kernel.not()
    end)
    |> Enum.reduce(true, fn v, acc -> acc && v end)
  end
end
```
