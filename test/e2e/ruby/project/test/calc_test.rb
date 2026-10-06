# frozen_string_literal: true

require "minitest/autorun"
require "calc"

class CalcTest < Minitest::Test
  def test_add
    assert_equal 3, Calc.add(1, 2)
  end
end
