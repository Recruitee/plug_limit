defmodule PlugLimit.FixedWindow do
  @moduledoc """
  Fixed window rate limiter Plug.

  `PlugLimit.FixedWindow` is a convenience wrapper build on top of a `PlugLimit` plug.
  Module provides syntactic sugar for fixed window algorithm specific options.

  ## Usage
  Example usage:
  ```elixir
  #lib/my_app_web/controllers/page_controller.ex
  plug PlugLimit.FixedWindow,
       [
         limit: 10,
         ttl: 60,
         key: {MyApp.RateLimiter, :my_key, "page_controller:fixed_window"}
       ]
       when action in [:create]
  ```
  Action `:create` in `PageController` will be protected by fixed window rate-limiter.
  Users will be able to issue up to 10 requests in 60 seconds time window.

  Example code above corresponds to the following direct `PlugLimit` usage:
  ```elixir
  #lib/my_app_web/controllers/page_controller.ex
  plug PlugLimit,
       [
         limiter: :fixed_window,
         opts: [10, 60],
         key: {MyApp.RateLimiter, :my_key, "page_controller:fixed_window"}
       ]
       when action in [:create]
  ```

  ## Configuration
  Configuration options:
  * `:limit` - requests limit. Required.
  * `:ttl` - rate-limiter time to live (time-window length) defined as number of seconds.
    Required.
  * `:key` - same as `PlugLimit` `:key` configuration option. Required.
  """

  @behaviour Plug

  @impl true
  @doc false
  def init(opts) do
    limit = Keyword.fetch!(opts, :limit)
    ttl = Keyword.fetch!(opts, :ttl)
    key = Keyword.fetch!(opts, :key)

    PlugLimit.init(
      limiter: :fixed_window,
      opts: [limit, ttl],
      key: key
    )
  end

  @impl true
  @doc false
  def call(conn, conf), do: PlugLimit.call(conn, conf)
end
