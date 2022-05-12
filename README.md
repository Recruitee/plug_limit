# PlugLimit (WIP)

Rate limiting Plug module based on Redis Lua scripting.

## Summary
PlugLimit is using Redis Lua scripting to provide rate-limiting functionality for web applications
based on a Plug library. PlugLimit has a modular architecture: users can use their own Redis Lua
scripts implementing custom rate limiting algorithms.

PlugLimit provides two built-in rate limiting algorithms: **fixed window** and **token bucket**.
Salient Redis Lua scripting feature is race conditions resiliency which makes it a recommended
solution for distributed systems.

## Installation
Add `PlugLimit` library to your application dependencies:
```elixir
def deps do
  [
    {:plug_limit, github: "recruitee/plug_limit", branch: "master"}
  ]
end
```

## Usage
PlugLimit is Redis client agnostic. In a first step you must define Elixir function executing Redis
commands, depending on Redis client of your choice:
```elixir
# config/config.exs
config :plug_limit,
  enabled?: true,
  cmd: {MyApp.Redis, :command, []}
```

`MyApp.Redis.command/2` function must accept Redis command as a first argument and static MFA tuple
`arg` as a second.
In most cases `:cmd` function will be a `Redix.command/3` or `:eredis.q/2,3` wrapper.
Example naive Redix driver wrapper:
```elixir
#lib/my_app/redis.ex
def command(command, opts \\ [timeout: 500]) do
  {:ok, pid} = Redix.start_link()
  Redix.command(pid, command, opts)
  :ok = Redix.stop(pid)
end
```

PlugLimit is tested with both [Redix](https://hex.pm/packages/redix) and
[eredis](https://hex.pm/packages/eredis) Redis clients.

Phoenix Framework endpoint can be protected with rate-limiter by placing a `PlugLimit` plug call
in the request processing pipeline:
```elixir
#lib/my_app_web/router.ex
pipeline :high_cost_pipeline do
  plug(PlugLimit, opts: [10, 60], key: {MyApp.RateLimiter, :user_key, [:high_cost_pipeline]})
  # remaining pipeline plugs...
end
```

Rate limits for `:high_cost_pipeline` pipeline will be evaluated with Redis Lua script fixed window
algorithm which is a default PlugLimit rate-limiter.
You can select token bucket algorithm instead of fixed window by adding: `limiter: :token_bucket`.
Options set with `:opts` key are passed directly to the fixed window Redis Lua script:
requests limit is equal `10` in time window `60` seconds.

MFA tuple defined with `:key` option specifies user function which should provide Redis key
used to uniquely identify given rate-limiter bucket. Redis rate-limiter key name should be derived
from `Plug.Conn.t()` connection struct parameters.
Example function to create Redis key name for rate-limiter throttling requests for a given user
identified by a connection assigned `user_id`:
```elixir
#lib/my_app/rate_limiter.ex
def user_key(%Plug.Conn{assigns: %{user_id: user_id}}, prefix),
   do: {:ok, ["#{prefix}:#{user_id}"]}
```

Please refer to `PlugLimit` module documentation for detailed library configuration description and
"Redis Lua script rate limiters" in LIMITERS.md file for Redis Lua scripts implementation
guidelines.

## TODO
- [ ] Add extended rate-limiter's Redis Lua scripts collecting blocked requests metrics.
- [ ] Add leaky bucket rate limiting algorithm implementation.
