defmodule PlugLimit.LuaTokenBucketRedixTest do
  use ExUnit.Case

  @script File.read("./lua/token_bucket.lua")

  setup do
    {:ok, script} = @script
    {:ok, "OK"} = command(["FLUSHALL"])
    {:ok, "OK"} = command(["SCRIPT", "FLUSH"])
    {:ok, sha} = command(["SCRIPT", "LOAD", script])
    %{sha: sha}
  end

  def command(cmd, opts \\ [timeout: 500]), do: PlugLimit.Test.RedixCli.command(cmd, opts)

  test "returns correct rate limiting http headers values", %{sha: sha} do
    assert command(["EVALSHA", sha, 1, "test:key", 5, 2, 3]) ==
             {:ok, ["allow", ["5 5;w=2;burst=3;policy=token_bucket", "2", "4"]]}

    assert command(["EVALSHA", sha, 1, "test:key", 5, 2, 3]) ==
             {:ok, ["allow", ["5 5;w=2;burst=3;policy=token_bucket", "2", "3"]]}

    assert command(["EVALSHA", sha, 1, "test:key", 5, 2, 3]) ==
             {:ok, ["allow", ["5 5;w=2;burst=3;policy=token_bucket", "2", "2", "1"]]}

    assert command(["EVALSHA", sha, 1, "test:key", 5, 2, 3]) ==
             {:ok, ["deny", ["5 5;w=2;burst=3;policy=token_bucket", "2", "2", "1"]]}

    assert command(["EVALSHA", sha, 1, "test:key", 5, 2, 3]) ==
             {:ok, ["deny", ["5 5;w=2;burst=3;policy=token_bucket", "2", "2", "1"]]}

    Process.sleep(1000)

    assert command(["EVALSHA", sha, 1, "test:key", 5, 2, 3]) ==
             {:ok, ["allow", ["5 5;w=2;burst=3;policy=token_bucket", "1", "1", "1"]]}

    assert command(["EVALSHA", sha, 1, "test:key", 5, 2, 3]) ==
             {:ok, ["deny", ["5 5;w=2;burst=3;policy=token_bucket", "1", "1", "1"]]}

    assert command(["EVALSHA", sha, 1, "test:key", 5, 2, 3]) ==
             {:ok, ["deny", ["5 5;w=2;burst=3;policy=token_bucket", "1", "1", "1"]]}
  end

  test "rate-limiter resets after time window", %{sha: sha} do
    assert command(["EVALSHA", sha, 1, "test:key", 4, 2, 2]) ==
             {:ok, ["allow", ["4 4;w=2;burst=2;policy=token_bucket", "2", "3"]]}

    assert command(["EVALSHA", sha, 1, "test:key", 4, 2, 2]) ==
             {:ok, ["allow", ["4 4;w=2;burst=2;policy=token_bucket", "2", "2", "1"]]}

    assert command(["EVALSHA", sha, 1, "test:key", 4, 2, 2]) ==
             {:ok, ["deny", ["4 4;w=2;burst=2;policy=token_bucket", "2", "2", "1"]]}

    assert command(["EVALSHA", sha, 1, "test:key", 4, 2, 2]) ==
             {:ok, ["deny", ["4 4;w=2;burst=2;policy=token_bucket", "2", "2", "1"]]}

    Process.sleep(1000)

    assert command(["EVALSHA", sha, 1, "test:key", 4, 2, 2]) ==
             {:ok, ["allow", ["4 4;w=2;burst=2;policy=token_bucket", "1", "1", "1"]]}

    assert command(["EVALSHA", sha, 1, "test:key", 4, 2, 2]) ==
             {:ok, ["deny", ["4 4;w=2;burst=2;policy=token_bucket", "1", "1", "1"]]}

    Process.sleep(1100)

    assert command(["EVALSHA", sha, 1, "test:key", 4, 2, 2]) ==
             {:ok, ["allow", ["4 4;w=2;burst=2;policy=token_bucket", "2", "3"]]}
  end
end
