defmodule PlugLimit.PlugConfRedixTest do
  use ExUnit.Case, async: false
  use Plug.Test
  import ExUnit.CaptureLog

  setup do
    Application.get_all_env(:plug_limit)
    |> Enum.each(fn {k, _v} -> Application.delete_env(:plug_limit, k) end)

    {:ok, "OK"} = command(["FLUSHALL", "SYNC"])
    {:ok, "OK"} = command(["SCRIPT", "FLUSH", "SYNC"])
    conn = PlugLimit.Test.Helpers.build_conn()
    %{conn: conn}
  end

  def command(cmd, opts \\ [timeout: 500]), do: PlugLimit.Test.RedixCli.command(cmd, opts)

  test "returns unmodified conn when :enabled? is not set, empty plug options", %{conn: conn} do
    opts = PlugLimit.init([])
    conn_out = PlugLimit.call(conn, opts)
    assert conn == conn_out
  end

  test "returns unmodified conn when :enabled? is not set, some plug options", %{conn: conn} do
    opts = PlugLimit.init(opts: [1, 2, 3])
    conn_out = PlugLimit.call(conn, opts)
    assert conn == conn_out
  end

  test "returns unmodified conn when :enabled? is set to `false` Boolean, empty plug options", %{
    conn: conn
  } do
    :ok = Application.put_env(:plug_limit, :enabled?, false)
    opts = PlugLimit.init([])
    conn_out = PlugLimit.call(conn, opts)
    assert conn == conn_out
  end

  test "returns unmodified conn when :enabled? is set to `false` Boolean, some plug options", %{
    conn: conn
  } do
    :ok = Application.put_env(:plug_limit, :enabled?, false)
    opts = PlugLimit.init(opts: [1, 2, 3])
    conn_out = PlugLimit.call(conn, opts)
    assert conn == conn_out
  end

  test "returns unmodified conn when :enabled? is set to `false` String, empty plug options", %{
    conn: conn
  } do
    :ok = Application.put_env(:plug_limit, :enabled?, "false")
    opts = PlugLimit.init([])
    conn_out = PlugLimit.call(conn, opts)
    assert conn == conn_out
  end

  test "returns unmodified conn when :enabled? is set to `false` String, some plug options", %{
    conn: conn
  } do
    :ok = Application.put_env(:plug_limit, :enabled?, "false")
    opts = PlugLimit.init(opts: [1, 2, 3])
    conn_out = PlugLimit.call(conn, opts)
    assert conn == conn_out
  end

  test "raises KeyError when :opts setting is missing" do
    :ok = Application.put_env(:plug_limit, :enabled?, "true")
    assert_raise KeyError, fn -> PlugLimit.init([]) end
  end

  test "raises KeyError when :key setting is missing" do
    :ok = Application.put_env(:plug_limit, :enabled?, "true")
    assert_raise KeyError, fn -> PlugLimit.init(opts: [1, 2]) end
  end

  test "raises ArgumentError when :cmd setting is missing" do
    :ok = Application.put_env(:plug_limit, :enabled?, "true")
    assert_raise ArgumentError, fn -> PlugLimit.init(opts: [1, 2], key: {M, :f, []}) end
  end

  test "raises KeyError when :limiter doesn't exist" do
    :ok = Application.put_env(:plug_limit, :enabled?, true)

    assert_raise KeyError, fn ->
      PlugLimit.init(opts: [1, 2], key: {M, :f, []}, limiter: :not_existing)
    end
  end

  test "init/2 returns valid defaults when :enabled? is set to `true` Boolean" do
    :ok = Application.put_env(:plug_limit, :enabled?, true)
    :ok = Application.put_env(:plug_limit, :cmd, {__MODULE__, :command, []})

    assert PlugLimit.init(opts: [1, 2], key: {M, :f, []}) == %PlugLimit{
             cmd: {__MODULE__, :command, []},
             enabled?: true,
             headers: ["x-ratelimit-limit", "x-ratelimit-reset", "x-ratelimit-remaining"],
             key: {M, :f, []},
             log_level: :error,
             opts: [1, 2],
             response: {PlugLimit, :put_response, []},
             script: {PlugLimit, :get_script, [:fixed_window]},
             script_id: :fixed_window
           }
  end

  test "init/2 returns valid defaults when :enabled? is set to `true` String" do
    :ok = Application.put_env(:plug_limit, :enabled?, "true")
    :ok = Application.put_env(:plug_limit, :cmd, {__MODULE__, :command, []})

    assert PlugLimit.init(opts: [1, 2], key: {M, :f, []}) == %PlugLimit{
             cmd: {__MODULE__, :command, []},
             enabled?: true,
             headers: ["x-ratelimit-limit", "x-ratelimit-reset", "x-ratelimit-remaining"],
             key: {M, :f, []},
             log_level: :error,
             opts: [1, 2],
             response: {PlugLimit, :put_response, []},
             script: {PlugLimit, :get_script, [:fixed_window]},
             script_id: :fixed_window
           }
  end

  test "put_response/4 receives valid input arguments", %{conn: conn} do
    :ok = Application.put_env(:plug_limit, :enabled?, true)
    :ok = Application.put_env(:plug_limit, :cmd, {__MODULE__, :command, []})

    :ok =
      Application.put_env(
        :plug_limit,
        :response,
        {PlugLimit.Test.Helpers, :put_response_echo, ["custom_arg"]}
      )

    opts =
      PlugLimit.init(
        opts: [123_456, 654_321],
        key: {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]}
      )

    {conn_out, conf, eval_result, args} = PlugLimit.call(conn, opts)
    assert conn_out == conn, "valid 1st argument: Plug.Conn.t()"
    assert conf == opts, "valid 2nd argument: parsed configuration"

    assert eval_result == {:ok, ["allow", ["123456", "654321", "123455"]]},
           "valid 3rd argument: Redis Lua script output"

    assert args == ["custom_arg"], "valid 4th argument: static MFA arg"
  end

  test "call/2 returns correct http headers for a :fixed_window limiter", %{
    conn: conn
  } do
    :ok = Application.put_env(:plug_limit, :enabled?, true)
    :ok = Application.put_env(:plug_limit, :cmd, {__MODULE__, :command, []})

    opts =
      PlugLimit.init(
        opts: [123_456, 654_321],
        key: {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]}
      )

    conn = PlugLimit.call(conn, opts)
    assert get_resp_header(conn, "x-ratelimit-limit") == ["123456"], "valid x-ratelimit-limit"
    assert get_resp_header(conn, "x-ratelimit-reset") == ["654321"], "valid x-ratelimit-reset"

    assert get_resp_header(conn, "x-ratelimit-remaining") == ["123455"],
           "valid x-ratelimit-remaining"
  end

  test "call/2 returns correct http headers for a :token_bucket limiter", %{
    conn: conn
  } do
    :ok = Application.put_env(:plug_limit, :enabled?, true)
    :ok = Application.put_env(:plug_limit, :cmd, {__MODULE__, :command, []})

    opts =
      PlugLimit.init(
        limiter: :token_bucket,
        opts: [123_456, 654_321, 123],
        key: {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]}
      )

    conn = PlugLimit.call(conn, opts)

    assert get_resp_header(conn, "x-ratelimit-limit") == [
             "123456 123456;w=654321;policy=token_bucket"
           ],
           "valid x-ratelimit-limit"

    assert get_resp_header(conn, "x-ratelimit-reset") == ["654321"], "valid x-ratelimit-reset"

    assert get_resp_header(conn, "x-ratelimit-remaining") == ["122"],
           "valid x-ratelimit-remaining"
  end

  test "call/2 generates Logger error when :opts are invalid and Lua script fails", %{
    conn: conn
  } do
    :ok = Application.put_env(:plug_limit, :enabled?, true)
    :ok = Application.put_env(:plug_limit, :cmd, {__MODULE__, :command, []})

    opts =
      PlugLimit.init(
        opts: ["invalid option"],
        key: {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]}
      )

    assert capture_log(fn -> PlugLimit.call(conn, opts) end)
           |> String.contains?("[error]")
  end

  test "call/2 generates Logger info when `log_level: :info`, :opts are invalid and Lua script fails",
       %{
         conn: conn
       } do
    :ok = Application.put_env(:plug_limit, :enabled?, true)
    :ok = Application.put_env(:plug_limit, :cmd, {__MODULE__, :command, []})
    :ok = Application.put_env(:plug_limit, :log_level, :info)

    opts =
      PlugLimit.init(
        opts: ["invalid option"],
        key: {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]}
      )

    assert capture_log(fn -> PlugLimit.call(conn, opts) end)
           |> String.contains?("[info]")
  end

  @tag capture_log: true

  test "call/2 returns original conn when :opts are invalid and Lua script fails", %{
    conn: conn
  } do
    :ok = Application.put_env(:plug_limit, :enabled?, true)
    :ok = Application.put_env(:plug_limit, :cmd, {__MODULE__, :command, []})

    opts =
      PlugLimit.init(
        opts: ["invalid option"],
        key: {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]}
      )

    assert PlugLimit.call(conn, opts) == conn
  end
end
