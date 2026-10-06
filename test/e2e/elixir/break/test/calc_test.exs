defmodule CalcTest do
  use ExUnit.Case

  test "add" do
    assert Calc.add(1, 2) == 4
  end
end
