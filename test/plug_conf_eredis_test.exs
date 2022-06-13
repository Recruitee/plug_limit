defmodule PlugLimit.PlugConfEredisTest do
  use ExUnit.Case, async: false
  use Plug.Test
  import ExUnit.CaptureLog

  def command(cmd, opts \\ 500), do: PlugLimit.Test.EredisCli.command(cmd, opts)

  @cmd {__MODULE__, :command, []}
  @key {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]}
  @response {PlugLimit.Test.Helpers, :put_response_echo, ["custom_arg"]}

  describe "init/1" do
    setup do
      Application.get_all_env(:plug_limit)
      |> Enum.each(fn {k, _v} -> Application.delete_env(:plug_limit, k) end)
    end

    test "raises if :cmd is missing" do
      assert_raise ArgumentError, fn -> PlugLimit.init(key: @key, opts: [1, 2, 3]) end
    end

    test "raises if :opts is missing" do
      :ok = Application.put_env(:plug_limit, :cmd, @cmd)
      assert_raise KeyError, fn -> PlugLimit.init(key: @key) end
    end

    test "raises if :key is missing" do
      :ok = Application.put_env(:plug_limit, :cmd, @cmd)
      assert_raise KeyError, fn -> PlugLimit.init(opts: [1, 2, 3]) end
    end

    test "returns config with defaults" do
      :ok = Application.put_env(:plug_limit, :cmd, @cmd)

      assert PlugLimit.init(key: @key, opts: [1, 2, 3]) ==
               %PlugLimit{
                 cmd: {PlugLimit.PlugConfEredisTest, :command, []},
                 headers: ["x-ratelimit-limit", "x-ratelimit-reset", "x-ratelimit-remaining"],
                 key: {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]},
                 log_level: :error,
                 opts: [1, 2, 3],
                 response: {PlugLimit, :put_response, []},
                 script: {PlugLimit, :get_script, [:fixed_window]},
                 script_id: :fixed_window
               }
    end
  end

  describe "call/2" do
    setup do
      Application.get_all_env(:plug_limit)
      |> Enum.each(fn {k, _v} -> Application.delete_env(:plug_limit, k) end)

      {:ok, "OK"} = command(["FLUSHALL", "SYNC"])
      {:ok, "OK"} = command(["SCRIPT", "FLUSH", "SYNC"])
      conn = PlugLimit.Test.Helpers.build_conn()
      %{conn: conn}
    end

    test "returns unmodified conn when :enabled? is not set", %{conn: conn} do
      :ok = Application.put_env(:plug_limit, :cmd, @cmd)

      opts = PlugLimit.init(key: @key, opts: [1, 2, 3])
      conn_out = PlugLimit.call(conn, opts)

      assert conn == conn_out
    end

    test "returns unmodified conn when :enabled? is set to `false` `Boolean`", %{conn: conn} do
      :ok = Application.put_env(:plug_limit, :enabled?, false)
      :ok = Application.put_env(:plug_limit, :cmd, @cmd)

      opts = PlugLimit.init(key: @key, opts: [1, 2, 3])
      conn_out = PlugLimit.call(conn, opts)

      assert conn == conn_out
    end

    test "returns unmodified conn when :enabled? is set to `false` `String.t()`", %{conn: conn} do
      :ok = Application.put_env(:plug_limit, :enabled?, "false")
      :ok = Application.put_env(:plug_limit, :cmd, @cmd)

      opts = PlugLimit.init(key: @key, opts: [1, 2, 3])
      conn_out = PlugLimit.call(conn, opts)

      assert conn == conn_out
    end

    test "put_response/4 receives valid input arguments for a default limiter", %{conn: conn} do
      :ok = Application.put_env(:plug_limit, :enabled?, true)
      :ok = Application.put_env(:plug_limit, :cmd, @cmd)
      :ok = Application.put_env(:plug_limit, :response, @response)

      opts = PlugLimit.init(opts: [123_456, 654_321], key: @key)
      {conn_out, conf, eval_result, args} = PlugLimit.call(conn, opts)

      assert conn_out == conn, "valid 1st argument: Plug.Conn.t()"
      assert conf == opts, "valid 2nd argument: parsed configuration"

      assert eval_result == {:ok, ["allow", ["123456", "654321", "123455"]]},
             "valid 3rd argument: Redis Lua script output"

      assert args == ["custom_arg"], "valid 4th argument: static MFA arg"
    end

    test "returns correct http headers for a default limiter", %{conn: conn} do
      :ok = Application.put_env(:plug_limit, :enabled?, true)
      :ok = Application.put_env(:plug_limit, :cmd, @cmd)

      opts = PlugLimit.init(opts: [123_456, 654_321], key: @key)
      conn = PlugLimit.call(conn, opts)

      assert get_resp_header(conn, "x-ratelimit-limit") == ["123456"], "valid x-ratelimit-limit"
      assert get_resp_header(conn, "x-ratelimit-reset") == ["654321"], "valid x-ratelimit-reset"

      assert get_resp_header(conn, "x-ratelimit-remaining") == ["123455"],
             "valid x-ratelimit-remaining"
    end

    test "returns correct http headers for a :token_bucket limiter", %{conn: conn} do
      :ok = Application.put_env(:plug_limit, :enabled?, true)
      :ok = Application.put_env(:plug_limit, :cmd, @cmd)

      opts = PlugLimit.init(limiter: :token_bucket, opts: [123_456, 654_321, 123], key: @key)
      conn = PlugLimit.call(conn, opts)

      assert get_resp_header(conn, "x-ratelimit-limit") ==
               ["123456 123456;w=654321;burst=123;policy=token_bucket"],
             "valid x-ratelimit-limit"

      assert get_resp_header(conn, "x-ratelimit-reset") == ["654321"], "valid x-ratelimit-reset"

      assert get_resp_header(conn, "x-ratelimit-remaining") == ["123455"],
             "valid x-ratelimit-remaining"
    end

    test "generates Logger error when :opts are invalid and Lua script fails", %{
      conn: conn
    } do
      :ok = Application.put_env(:plug_limit, :enabled?, true)
      :ok = Application.put_env(:plug_limit, :cmd, @cmd)

      opts = PlugLimit.init(opts: ["invalid option"], key: @key)

      assert capture_log(fn -> PlugLimit.call(conn, opts) end)
             |> String.contains?("[error]")
    end

    test "generates Logger info when `log_level: :info`, :opts are invalid and Lua script fails",
         %{
           conn: conn
         } do
      :ok = Application.put_env(:plug_limit, :enabled?, true)
      :ok = Application.put_env(:plug_limit, :cmd, @cmd)
      :ok = Application.put_env(:plug_limit, :log_level, :info)

      opts = PlugLimit.init(opts: ["invalid option"], key: @key)

      assert capture_log(fn -> PlugLimit.call(conn, opts) end)
             |> String.contains?("[info]")
    end

    @tag capture_log: true
    test "returns original conn when :opts are invalid and Lua script fails", %{
      conn: conn
    } do
      :ok = Application.put_env(:plug_limit, :enabled?, true)
      :ok = Application.put_env(:plug_limit, :cmd, @cmd)

      opts = PlugLimit.init(opts: ["invalid option"], key: @key)

      assert PlugLimit.call(conn, opts) == conn
    end
  end
end
