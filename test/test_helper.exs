ExUnit.start()

{:ok, pid} = Redix.start_link()
:ok = :persistent_term.put({:redis_cli, :redix}, pid)

{:ok, pid} = :eredis.start_link()
:ok = :persistent_term.put({:redis_cli, :eredis}, pid)

defmodule PlugLimit.Test.RedixCli do
  def command(command, opts \\ [timeout: 5000]) do
    {:redis_cli, :redix}
    |> :persistent_term.get()
    |> Redix.command(command, opts)
  end
end

defmodule PlugLimit.Test.EredisCli do
  def command(command, timeout \\ 5000) do
    {:redis_cli, :eredis}
    |> :persistent_term.get()
    |> :eredis.q(command, timeout)
  end
end

defmodule PlugLimit.Test.Helpers do
  def build_conn(), do: :get |> Plug.Test.conn("/") |> Plug.Conn.assign(:user_id, 123)

  def user_id_key(%Plug.Conn{assigns: %{user_id: user_id}}, prefix),
    do: {:ok, ["#{prefix}:#{user_id}"]}

  def put_response_echo(%Plug.Conn{} = conn, conf, eval_result, args),
    do: {conn, conf, eval_result, args}
end
