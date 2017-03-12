require 'test_helper'

class SimpleDoTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::SimpleDo::VERSION
  end
end
