defmodule PlugLimit.TokenBucketTest do
  use ExUnit.Case

  @cmd {__MODULE__, :command, []}

  describe "init/1" do
    setup do
      Application.get_all_env(:plug_limit)
      |> Enum.each(fn {k, _v} -> Application.delete_env(:plug_limit, k) end)
    end

    test "raises if :limit is missing" do
      assert_raise KeyError, fn -> PlugLimit.TokenBucket.init(ttl: 60, burst: 10, key: {}) end
    end

    test "raises if :ttl is missing" do
      assert_raise KeyError, fn -> PlugLimit.TokenBucket.init(limit: 10, burst: 10, key: {}) end
    end

    test "raises if :burst is missing" do
      assert_raise KeyError, fn -> PlugLimit.TokenBucket.init(limit: 10, ttl: 60, key: {}) end
    end

    test "raises if :key is missing" do
      assert_raise KeyError, fn -> PlugLimit.TokenBucket.init(limit: 10, ttl: 60, burst: 10) end
    end

    test "returns valid config" do
      :ok = Application.put_env(:plug_limit, :cmd, @cmd)

      assert PlugLimit.TokenBucket.init(burst: 5, limit: 10, ttl: 60, key: {M, :f, "a"}) ==
               %PlugLimit{
                 cmd: {PlugLimit.TokenBucketTest, :command, []},
                 headers: [
                   "x-ratelimit-limit",
                   "x-ratelimit-reset",
                   "x-ratelimit-remaining",
                   "retry-after"
                 ],
                 key: {M, :f, "a"},
                 log_level: :error,
                 opts: [10, 60, 5],
                 response: {PlugLimit, :put_response, []},
                 script: {PlugLimit, :get_script, [:token_bucket]},
                 script_id: :token_bucket
               }
    end
  end
end
