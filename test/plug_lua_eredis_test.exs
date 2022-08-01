defmodule PlugLimit.PlugLuaEredisTest do
  use ExUnit.Case
  use Plug.Test
  import ExUnit.CaptureLog

  setup do
    Application.get_all_env(:plug_limit)
    |> Enum.each(fn {k, _v} -> Application.delete_env(:plug_limit, k) end)

    :ok = Application.put_env(:plug_limit, :enabled?, true)
    :ok = Application.put_env(:plug_limit, :cmd, {__MODULE__, :command, []})

    {:ok, "OK"} = command(["FLUSHALL"])
    {:ok, "OK"} = command(["SCRIPT", "FLUSH"])
    conn = PlugLimit.Test.Helpers.build_conn()
    %{conn: conn}
  end

  def command(cmd, opts \\ 500), do: PlugLimit.Test.EredisCli.command(cmd, opts)

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

  def lua_echo_header_overwrite() do
    script = """
    local key1 = KEYS[1]
    local arg1 = ARGV[1]
    local arg2 = ARGV[2]
    local arg3 = ARGV[3]
    return {key1, {arg1, {"h2_mod", arg2}, arg3}}
    """

    {:ok, script}
  end

  def lua_echo_with_optional_output() do
    script = """
    local key1 = KEYS[1]
    local arg1 = ARGV[1]
    local arg2 = ARGV[2]
    local arg3 = ARGV[3]
    return {key1, {arg1, arg2, arg3}, "optional1", "optional2"}
    """

    {:ok, script}
  end

  def lua_raise_error() do
    script = """
    error('lua_error')
    """

    {:ok, script}
  end

  test "basic input :opts and output http headers flow", %{conn: conn} do
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

    conn = PlugLimit.call(conn, opts)
    assert get_resp_header(conn, "h1") == ["o1"]
    assert get_resp_header(conn, "h2") == ["o2"]
    assert get_resp_header(conn, "h3") == ["o3"]
  end

  test "set :key in :limiter definition", %{conn: conn} do
    :ok =
      Application.put_env(:plug_limit, :limiters,
        test_limiter: %{
          luascript: :test_script,
          key: {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]}
        }
      )

    :ok =
      Application.put_env(:plug_limit, :luascripts,
        test_script: %{script: {__MODULE__, :lua_echo, []}, headers: ["h1", "h2", "h3"]}
      )

    opts =
      PlugLimit.init(
        limiter: :test_limiter,
        opts: ["o1", "o2", "o3"]
      )

    conn = PlugLimit.call(conn, opts)
    assert get_resp_header(conn, "h1") == ["o1"]
    assert get_resp_header(conn, "h2") == ["o2"]
    assert get_resp_header(conn, "h3") == ["o3"]
  end

  test "set :response in :limiter definition", %{conn: conn} do
    :ok =
      Application.put_env(:plug_limit, :limiters,
        test_limiter: %{
          luascript: :test_script,
          key: {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]},
          response: {PlugLimit.Test.Helpers, :put_response_echo, []}
        }
      )

    :ok =
      Application.put_env(:plug_limit, :luascripts,
        test_script: %{script: {__MODULE__, :lua_echo, []}, headers: ["h1", "h2", "h3"]}
      )

    opts =
      PlugLimit.init(
        limiter: :test_limiter,
        opts: ["o1", "o2", "o3"]
      )

    {conn_out, _conf, _eval_result, _args} = PlugLimit.call(conn, opts)
    assert conn_out == conn
  end

  test "set :cmd in :limiter definition", %{conn: conn} do
    :ok = Application.delete_env(:plug_limit, :cmd)

    :ok =
      Application.put_env(:plug_limit, :limiters,
        test_limiter: %{luascript: :test_script, cmd: {__MODULE__, :command, []}}
      )

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

    conn = PlugLimit.call(conn, opts)
    assert get_resp_header(conn, "h1") == ["o1"]
    assert get_resp_header(conn, "h2") == ["o2"]
    assert get_resp_header(conn, "h3") == ["o3"]
  end

  test "http header overwrite", %{conn: conn} do
    :ok = Application.put_env(:plug_limit, :limiters, test_limiter: %{luascript: :test_script})

    :ok =
      Application.put_env(:plug_limit, :luascripts,
        test_script: %{
          script: {__MODULE__, :lua_echo_header_overwrite, []},
          headers: ["h1", "h2", "h3"]
        }
      )

    opts =
      PlugLimit.init(
        limiter: :test_limiter,
        opts: ["o1", "o2", "o3"],
        key: {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]}
      )

    conn = PlugLimit.call(conn, opts)
    assert get_resp_header(conn, "h1") == ["o1"]
    assert get_resp_header(conn, "h2") == []
    assert get_resp_header(conn, "h2_mod") == ["o2"]
    assert get_resp_header(conn, "h3") == ["o3"]
  end

  test "optional script output flow", %{conn: conn} do
    :ok =
      Application.put_env(:plug_limit, :limiters,
        test_limiter: %{
          luascript: :test_script,
          response: {PlugLimit.Test.Helpers, :put_response_echo, []}
        }
      )

    :ok =
      Application.put_env(:plug_limit, :luascripts,
        test_script: %{
          script: {__MODULE__, :lua_echo_with_optional_output, []},
          headers: ["h1", "h2", "h3"]
        }
      )

    opts =
      PlugLimit.init(
        limiter: :test_limiter,
        opts: ["o1", "o2", "o3"],
        key: {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]}
      )

    {_conn, _conf, {:ok, eval_result}, _args} = PlugLimit.call(conn, opts)
    assert eval_result == ["prefix:123", ["o1", "o2", "o3"], "optional1", "optional2"]
  end

  test "logs error on Redis Lua script error", %{conn: conn} do
    :ok = Application.put_env(:plug_limit, :limiters, test_limiter: %{luascript: :test_script})

    :ok =
      Application.put_env(:plug_limit, :luascripts,
        test_script: %{script: {__MODULE__, :lua_raise_error, []}, headers: ["h1", "h2", "h3"]}
      )

    opts =
      PlugLimit.init(
        limiter: :test_limiter,
        opts: ["o1", "o2", "o3"],
        key: {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]}
      )

    assert capture_log(fn -> PlugLimit.call(conn, opts) end) |> String.contains?("[error]")
  end

  @tag capture_log: true
  test "returns original conn on Redis Lua script error", %{conn: conn} do
    :ok = Application.put_env(:plug_limit, :limiters, test_limiter: %{luascript: :test_script})

    :ok =
      Application.put_env(:plug_limit, :luascripts,
        test_script: %{script: {__MODULE__, :lua_raise_error, []}, headers: ["h1", "h2", "h3"]}
      )

    opts =
      PlugLimit.init(
        limiter: :test_limiter,
        opts: ["o1", "o2", "o3"],
        key: {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]}
      )

    assert PlugLimit.call(conn, opts) == conn
  end
end
