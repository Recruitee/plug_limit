defmodule PlugLimit.Test do
  @moduledoc """
  Conveniences for testing endpoints protected with PlugLimit rate limiters.

  Unit testing endpoints protected with rate limiters might provide unexpected results
  because after exceeding requests limit during consecutive tests given endpoint will respond
  with `429` status code.

  `PlugLimit.Test` can help to avoid unexpected `429` responses by adding following code to your
  test cases:
  ```elixir
  use PlugLimit.Test, redis_flushdb?: true
  ```
  Using this module with `:redis_flushdb?` set to `true` will flush Redis database with
  `redis_flushdb/1` function executed inside `ExUnit.Callbacks.setup/1`.
  Required by `redis_flushdb/1` Redis command function is taken from `:plug_limit` `:cmd` key
  defined for testing environment, for example:
  ```elixir
  # config/test.exs
  config :plug_limit, cmd: {MyApp.Redis, :command, []}
  ```
  Please refer to `PlugLimit` module documentation for detailed `:cmd` setting description.

  `PlugLimit.Test` has one configuration setting `:redis_flushdb?`, set to `false` by default.
  When using `:redis_flushdb?` you might consider setting separate Redis database
  (e.g.: `redis://localhost:6379/15`) for PlugLimit to avoid interference with other parts of your
  application during testing.

  Alternatively to `:redis_flushdb?` you can use `redis_del_keys/2`.
  """

  use ExUnit.CaseTemplate

  using opts do
    quote bind_quoted: [opts: opts] do
      @redis_flushdb Keyword.get(opts, :redis_flushdb?, false)

      setup do
        if @redis_flushdb,
          do: :plug_limit |> Application.fetch_env!(:cmd) |> PlugLimit.Test.redis_flushdb(),
          else: :ok
      end
    end
  end

  @doc """
  Gets `x-ratelimit-remaining` header from `conn` and parses it to integer.

  Returns `x-ratelimit-remaining` header as an integer or string message if invalid or missing header.

  Example:
  ```elixir

  test "x-ratelimit-remaining is correct", %{conn: conn} do
    conn = get(conn, "/")
    assert PlugLimit.Test.get_remaining(conn) == 60
  end
  ```

  ```elixir
  iex> PlugLimit.Test.get_remaining(conn_invalid_header)
  "Invalid, non-standard or missing x-ratelimit-remaining header."
  ```
  """
  @spec get_remaining(conn :: Plug.Conn.t()) :: integer() | String.t()
  def get_remaining(conn), do: hdr_to_integer(conn, "x-ratelimit-remaining")

  @doc """
  Same as `get_remaining/1` but for `x-ratelimit-reset` header.
  """
  @spec get_reset(conn :: Plug.Conn.t()) :: integer()
  def get_reset(conn), do: hdr_to_integer(conn, "x-ratelimit-reset")

  @doc """
  Checks for IETF recommended `x-ratelimit-*` http response headers in `conn`.

  Checks if basic rate limiting http response headers complying with
  ["RateLimit Fields for HTTP"](https://datatracker.ietf.org/doc/draft-ietf-httpapi-ratelimit-headers/)
  IETF specification are added to `Plug.Conn.t()`.

  Required rate limiting http response headers:
  * `x-ratelimit-limit`,
  * `x-ratelimit-remaining`,
  * `x-ratelimit-reset`.

  Returns `true` if above headers are present and `false` otherwise.

  Example:
  ```elixir
  test "it is protected by rate limiter", %{conn: conn} do
    conn = get(conn, "/")
    assert PlugLimit.Test.headers_exist?(conn)
  end
  ```
  """
  @spec headers_exist?(conn :: Plug.Conn.t()) :: boolean()
  def headers_exist?(conn) do
    ["x-ratelimit-limit", "x-ratelimit-remaining", "x-ratelimit-reset"]
    |> Enum.map(fn hdr ->
      conn
      |> Plug.Conn.get_resp_header(hdr)
      |> Enum.empty?()
      |> Kernel.not()
    end)
    |> Enum.reduce(true, fn v, acc -> acc && v end)
  end

  @redis_del_keys_script """
  return redis.call('DEL', 'default:not:existing:key:*', unpack(redis.call('KEYS', ARGV[1])))
  """

  @doc """
  Deletes all keys with the names matching pattern given by `key` from the Redis DB selected with
  `{m, f, a}` Redis command function.

  `{m, f, a}` usually should be consistent with a value given in `:plug_limit` `:cmd` configuration key.
  Returns `:ok` on success or `any()` on error.

  Function should not be used to delete large numbers of Redis keys.

  Example:
  ```elixir
  setup do
    :ok = PlugLimit.Test.redis_del_keys({MyApp.Redis, :command, []}, "my_key:*")
  end
  ```
  """
  @spec redis_del_keys({m :: module(), f :: atom(), [a :: any()]}, key :: String.t()) ::
          :ok | any()
  def redis_del_keys({m, f, a} = _redis_command_function, key) do
    case apply(m, f, [["EVAL", @redis_del_keys_script, "0", [key]]] ++ a) do
      {:ok, _key_count} -> :ok
      err -> err
    end
  end

  @doc """
  Deletes all keys from the Redis DB selected with `{m, f, a}` Redis command function.

  `{m, f, a}` usually should be consistent with a value given in `:plug_limit` `:cmd` configuration key.
  Returns `:ok` on success or `any()` on error.

  Redis command which is used to delete keys: [`FLUSHDB SYNC`](https://redis.io/commands/flushdb/).

  Example:
  ```elixir
  iex> PlugLimit.Test.redis_flushdb({MyApp.Redis, :command, []})
  :ok
  ```
  """
  @spec redis_flushdb({m :: module(), f :: atom(), [a :: any()]}) :: :ok | any()
  def redis_flushdb({m, f, a} = _redis_command_function) do
    case apply(m, f, [["FLUSHDB"]] ++ a) do
      {:ok, "OK"} -> :ok
      err -> err
    end
  end

  defp hdr_to_integer(conn, hdr) do
    with [hdr] <- Plug.Conn.get_resp_header(conn, hdr),
         {hdr, ""} <- Integer.parse(hdr) do
      hdr
    else
      _ -> "Invalid, non-standard or missing #{hdr} header."
    end
  end
end
