defmodule PlugLimit.FixedWindowTest do
  use ExUnit.Case, async: false
  use Plug.Test

  @cmd {__MODULE__, :command, []}

  describe "init/1" do
    setup do
      Application.get_all_env(:plug_limit)
      |> Enum.each(fn {k, _v} -> Application.delete_env(:plug_limit, k) end)
    end

    test "raises if :limit is missing" do
      assert_raise KeyError, fn -> PlugLimit.FixedWindow.init(ttl: 60, key: {}) end
    end

    test "raises if :ttl is missing" do
      assert_raise KeyError, fn -> PlugLimit.FixedWindow.init(limit: 10, key: {}) end
    end

    test "raises if :key is missing" do
      assert_raise KeyError, fn -> PlugLimit.FixedWindow.init(limit: 10, ttl: 60) end
    end

    test "returns valid config" do
      :ok = Application.put_env(:plug_limit, :cmd, @cmd)

      assert PlugLimit.FixedWindow.init(limit: 10, ttl: 60, key: {M, :f, "a"}) ==
               %PlugLimit{
                 cmd: {PlugLimit.FixedWindowTest, :command, []},
                 headers: ["x-ratelimit-limit", "x-ratelimit-reset", "x-ratelimit-remaining"],
                 key: {M, :f, "a"},
                 log_level: :error,
                 opts: [10, 60],
                 response: {PlugLimit, :put_response, []},
                 script: {PlugLimit, :get_script, [:fixed_window]},
                 script_id: :fixed_window
               }
    end
  end
end
