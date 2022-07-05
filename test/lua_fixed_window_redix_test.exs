defmodule PlugLimit.LuaFixedWindowRedixTest do
  use ExUnit.Case, async: false
  use Plug.Test

  @script File.read("./lua/fixed_window.lua")

  setup do
    {:ok, script} = @script
    {:ok, "OK"} = command(["FLUSHALL", "SYNC"])
    {:ok, "OK"} = command(["SCRIPT", "FLUSH", "SYNC"])
    {:ok, sha} = command(["SCRIPT", "LOAD", script])
    %{sha: sha}
  end

  def command(cmd, opts \\ [timeout: 500]), do: PlugLimit.Test.RedixCli.command(cmd, opts)

  test "returns correct rate limiting http headers values", %{sha: sha} do
    assert command(["EVALSHA", sha, 1, "test:key", 3, 60]) == {:ok, ["allow", ["3", "60", "2"]]}
    assert command(["EVALSHA", sha, 1, "test:key", 3, 60]) == {:ok, ["allow", ["3", "60", "1"]]}
    assert command(["EVALSHA", sha, 1, "test:key", 3, 60]) == {:ok, ["allow", ["3", "60", "0"]]}
    assert command(["EVALSHA", sha, 1, "test:key", 3, 60]) == {:ok, ["deny", ["3", "60", "0"]]}
    assert command(["EVALSHA", sha, 1, "test:key", 3, 60]) == {:ok, ["deny", ["3", "60", "0"]]}
  end

  test "rate-limiter resets after time window", %{sha: sha} do
    assert command(["EVALSHA", sha, 1, "test:key", 3, 1]) == {:ok, ["allow", ["3", "1", "2"]]}
    assert command(["EVALSHA", sha, 1, "test:key", 3, 1]) == {:ok, ["allow", ["3", "1", "1"]]}
    assert command(["EVALSHA", sha, 1, "test:key", 3, 1]) == {:ok, ["allow", ["3", "1", "0"]]}
    assert command(["EVALSHA", sha, 1, "test:key", 3, 1]) == {:ok, ["deny", ["3", "1", "0"]]}
    assert command(["EVALSHA", sha, 1, "test:key", 3, 1]) == {:ok, ["deny", ["3", "1", "0"]]}
    Process.sleep(1000)
    assert command(["EVALSHA", sha, 1, "test:key", 3, 1]) == {:ok, ["allow", ["3", "1", "2"]]}
    assert command(["EVALSHA", sha, 1, "test:key", 3, 1]) == {:ok, ["allow", ["3", "1", "1"]]}
    assert command(["EVALSHA", sha, 1, "test:key", 3, 1]) == {:ok, ["allow", ["3", "1", "0"]]}
    assert command(["EVALSHA", sha, 1, "test:key", 3, 1]) == {:ok, ["deny", ["3", "1", "0"]]}
    assert command(["EVALSHA", sha, 1, "test:key", 3, 1]) == {:ok, ["deny", ["3", "1", "0"]]}
  end
end
