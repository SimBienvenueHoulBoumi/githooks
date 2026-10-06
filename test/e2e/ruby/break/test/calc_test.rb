# frozen_string_literal: true

require "minitest/autorun"
require "calc"

class CalcTest < Minitest::Test
  def test_add
    assert_equal 4, Calc.add(1, 2)
  end
end
