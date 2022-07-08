defmodule PlugLimit.TestRedixTest do
  use ExUnit.Case

  def command(cmd, opts \\ [timeout: 500]), do: PlugLimit.Test.RedixCli.command(cmd, opts)

  setup do
    {:ok, "OK"} = command(["FLUSHALL", "SYNC"])
    {:ok, "OK"} = command(["SET", "key:1", "1"])
    {:ok, "OK"} = command(["SET", "key:2", "2"])
    :ok
  end

  describe "redis_del_keys/1" do
    test "deletes keys" do
      PlugLimit.Test.redis_del_keys({__MODULE__, :command, []}, "key:*")
      {:ok, keys} = command(["KEYS", "*"])
      assert Enum.empty?(keys)
    end

    test "doesn't delete keys not matching pattern" do
      PlugLimit.Test.redis_del_keys({__MODULE__, :command, []}, "my_key:*")
      {:ok, keys} = command(["KEYS", "*"])
      refute Enum.empty?(keys)
    end
  end

  describe "redis_flushdb/1" do
    test "flushes all keys" do
      PlugLimit.Test.redis_flushdb({__MODULE__, :command, []})
      {:ok, keys} = command(["KEYS", "*"])
      assert Enum.empty?(keys)
    end
  end
end
