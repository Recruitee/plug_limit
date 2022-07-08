defmodule PlugLimit.PlugRedisErrorTest do
  use ExUnit.Case
  use Plug.Test
  import ExUnit.CaptureLog

  setup do
    Application.get_all_env(:plug_limit)
    |> Enum.each(fn {k, _v} -> Application.delete_env(:plug_limit, k) end)

    :ok = Application.put_env(:plug_limit, :enabled?, true)
    :ok = Application.put_env(:plug_limit, :cmd, {__MODULE__, :command, []})
    :ok = Application.put_env(:plug_limit, :limiters, test_limiter: %{luascript: :test_script})

    :ok =
      Application.put_env(:plug_limit, :luascripts,
        test_script: %{script: {__MODULE__, :lua_echo, []}, headers: ["h1", "h2", "h3"]}
      )

    opts =
      PlugLimit.init(
        limiter: :test_limiter,
        opts: ["o1", "o2", "o3"],
        key: {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]}
      )

    conn = PlugLimit.Test.Helpers.build_conn()
    %{conn: conn, opts: opts}
  end

  def command(cmd), do: PlugLimit.Test.ErrorCli.command(cmd, [])

  def lua_echo() do
    script = """
    local key1 = KEYS[1]
    local arg1 = ARGV[1]
    local arg2 = ARGV[2]
    local arg3 = ARGV[3]
    return {key1, {arg1, arg2, arg3}}
    """

    {:ok, script}
  end

  @tag capture_log: true
  test "returns original conn if Redis is down", %{conn: conn, opts: opts} do
    assert PlugLimit.call(conn, opts) == conn
  end

  test "logs error if Redis is down", %{conn: conn, opts: opts} do
    assert capture_log(fn -> PlugLimit.call(conn, opts) end) |> String.contains?("[error]")
  end
end
