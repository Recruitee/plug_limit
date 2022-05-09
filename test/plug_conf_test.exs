defmodule PlugLimit.PlugConfRedixTest do
  use ExUnit.Case, async: false
  use Plug.Test

  setup do
    Application.get_all_env(:plug_limit)
    |> Enum.each(fn {k, _v} -> Application.delete_env(:plug_limit, k) end)

    {:ok, "OK"} = command(["FLUSHALL", "SYNC"])
    {:ok, "OK"} = command(["SCRIPT", "FLUSH", "SYNC"])
    :ok
  end

  def command(cmd, opts \\ [timeout: 500]), do: PlugLimit.Test.RedixCli.command(cmd, opts)
  # def command(cmd, opts \\ 500), do: PlugLimit.Test.EredisCli.command(cmd, opts)

  defp gen_conn(), do: :get |> conn("/") |> assign(:user_id, 123)

  test ":enabled? is not set, empty plug options" do
    opts = PlugLimit.init([])
    conn_in = gen_conn()
    conn_out = PlugLimit.call(conn_in, opts)
    assert conn_in == conn_out
  end

  test ":enabled? is not set, some plug options" do
    opts = PlugLimit.init(opts: [1, 2, 3])
    conn_in = gen_conn()
    conn_out = PlugLimit.call(conn_in, opts)
    assert conn_in == conn_out
  end

  test ":enabled? is set to `false`, empty plug options" do
    :ok = Application.put_env(:plug_limit, :enabled?, false)
    opts = PlugLimit.init([])
    conn_in = gen_conn()
    conn_out = PlugLimit.call(conn_in, opts)
    assert conn_in == conn_out
  end

  test ":enabled? is set to `false` string, some plug options" do
    :ok = Application.put_env(:plug_limit, :enabled?, "false")
    opts = PlugLimit.init(opts: [1, 2, 3])
    conn_in = gen_conn()
    conn_out = PlugLimit.call(conn_in, opts)
    assert conn_in == conn_out
  end

  test "missing :opts setting" do
    :ok = Application.put_env(:plug_limit, :enabled?, "true")
    assert_raise KeyError, fn -> PlugLimit.init([]) end
  end

  test "missing :key setting" do
    :ok = Application.put_env(:plug_limit, :enabled?, "true")
    assert_raise KeyError, fn -> PlugLimit.init(opts: [1, 2]) end
  end

  test "missing :cmd setting" do
    :ok = Application.put_env(:plug_limit, :enabled?, "true")
    assert_raise ArgumentError, fn -> PlugLimit.init(opts: [1, 2], key: {M, :f, []}) end
  end

  test ":enabled? is set to `true` with defaults" do
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

  test ":enabled? is set to `true` string with defaults" do
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

  # TODO custom response

  test "fixed window limiter with defaults returns correct http headers" do
    :ok = Application.put_env(:plug_limit, :enabled?, true)
    :ok = Application.put_env(:plug_limit, :cmd, {__MODULE__, :command, []})

    opts =
      PlugLimit.init(
        opts: [123_456, 654_321],
        key: {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]}
      )

    conn = gen_conn() |> PlugLimit.call(opts)
    assert get_resp_header(conn, "x-ratelimit-limit") == ["123456"], "valid x-ratelimit-limit"
    assert get_resp_header(conn, "x-ratelimit-reset") == ["654321"], "valid x-ratelimit-reset"

    assert get_resp_header(conn, "x-ratelimit-remaining") == ["123455"],
           "valid x-ratelimit-remaining"
  end

  test "token bucket limiter with defaults returns correct http headers" do
    :ok = Application.put_env(:plug_limit, :enabled?, true)
    :ok = Application.put_env(:plug_limit, :cmd, {__MODULE__, :command, []})

    opts =
      PlugLimit.init(
        limiter: :token_bucket,
        opts: [123_456, 654_321, 123],
        key: {PlugLimit.Test.Helpers, :user_id_key, ["prefix"]}
      )

    conn = gen_conn() |> PlugLimit.call(opts)

    assert get_resp_header(conn, "x-ratelimit-limit") == [
             "123456 123456;w=654321;policy=token_bucket"
           ],
           "valid x-ratelimit-limit"

    assert get_resp_header(conn, "x-ratelimit-reset") == ["654321"], "valid x-ratelimit-reset"

    assert get_resp_header(conn, "x-ratelimit-remaining") == ["122"],
           "valid x-ratelimit-remaining"
  end
end
