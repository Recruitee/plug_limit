defmodule PlugLimit.TestTest do
  use ExUnit.Case
  use Plug.Test

  setup do
    conn = PlugLimit.Test.Helpers.build_conn()
    %{conn: conn}
  end

  describe "get_remaining/1" do
    test "valid header", %{conn: conn} do
      conn = Plug.Conn.put_resp_header(conn, "x-ratelimit-remaining", "123456")
      assert PlugLimit.Test.get_remaining(conn) == 123_456
    end

    test "invalid header", %{conn: conn} do
      conn = Plug.Conn.put_resp_header(conn, "x-ratelimit-remaining", "abc")

      assert PlugLimit.Test.get_remaining(conn) ==
               "Invalid, non-standard or missing x-ratelimit-remaining header."
    end

    test "missing header", %{conn: conn} do
      assert PlugLimit.Test.get_remaining(conn) ==
               "Invalid, non-standard or missing x-ratelimit-remaining header."
    end
  end

  describe "get_reset/1" do
    test "valid header", %{conn: conn} do
      conn = Plug.Conn.put_resp_header(conn, "x-ratelimit-reset", "123456")
      assert PlugLimit.Test.get_reset(conn) == 123_456
    end

    test "invalid header", %{conn: conn} do
      conn = Plug.Conn.put_resp_header(conn, "x-ratelimit-reset", "abc")

      assert PlugLimit.Test.get_reset(conn) ==
               "Invalid, non-standard or missing x-ratelimit-reset header."
    end

    test "missing header", %{conn: conn} do
      assert PlugLimit.Test.get_reset(conn) ==
               "Invalid, non-standard or missing x-ratelimit-reset header."
    end
  end

  describe "headers_exist?/1" do
    test "headers exist", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_resp_header("x-ratelimit-limit", "123")
        |> Plug.Conn.put_resp_header("x-ratelimit-remaining", "456")
        |> Plug.Conn.put_resp_header("x-ratelimit-reset", "789")

      assert PlugLimit.Test.headers_exist?(conn)
    end

    test "headers do not exist", %{conn: conn} do
      refute PlugLimit.Test.headers_exist?(conn)
    end
  end
end
