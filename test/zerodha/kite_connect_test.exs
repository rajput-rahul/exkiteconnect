defmodule KiteConnectTest do
  use ExUnit.Case
  alias Zerodha.KiteConnect

  test "greets the world" do
    assert KiteConnect.hello() == :world
  end
end
