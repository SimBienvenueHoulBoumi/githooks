defmodule CalcTest do
  use ExUnit.Case

  test "add" do
    assert Calc.add(1, 2) == 3
  end
end
