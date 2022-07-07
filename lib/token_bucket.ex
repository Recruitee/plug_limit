defmodule PlugLimit.TokenBucket do
  @moduledoc """
  Token bucket rate limiter Plug.

  `PlugLimit.TokenBucket` is a convenience wrapper build on top of a `PlugLimit` plug.
  Module provides syntactic sugar for token bucket algorithm specific options.

  ## Usage
  Example usage:
  ```elixir
  #lib/my_app_web/controllers/page_controller.ex
  plug PlugLimit.TokenBucket,
       [
         burst: 3,
         limit: 6,
         ttl: 60,
         key: {MyApp.RateLimiter, :my_key, "page_controller:token_bucket"}
       ]
       when action in [:create]
  ```
  Action `:create` in `PageController` will be protected by token bucket rate-limiter.
  Users will be able to issue up to 6 requests in 60 seconds time window with initial burst rate
  3 requests.

  Example code above corresponds to the following direct `PlugLimit` usage:
  ```elixir
  #lib/my_app_web/controllers/page_controller.ex
  plug PlugLimit,
       [
         limiter: :token_bucket,
         opts: [6, 60, 3],
         key: {MyApp.RateLimiter, :my_key, "page_controller:token_bucket"}
       ]
       when action in [:create]
  ```

  ## Configuration
  Configuration options:
  * `:burst` - token bucket initial burst rate. Required.
  * `:limit` - requests limit. Required.
  * `:ttl` - rate-limiter time to live (time-window length) defined as number of seconds.
    Required.
  * `:key` - same as `PlugLimit` `:key` configuration option. Required.
  """

  @behaviour Plug

  @impl true
  @doc false
  def init(opts) do
    burst = Keyword.fetch!(opts, :burst)
    limit = Keyword.fetch!(opts, :limit)
    ttl = Keyword.fetch!(opts, :ttl)
    key = Keyword.fetch!(opts, :key)

    PlugLimit.init(
      limiter: :token_bucket,
      opts: [limit, ttl, burst],
      key: key
    )
  end

  @impl true
  @doc false
  def call(conn, conf), do: PlugLimit.call(conn, conf)
end
