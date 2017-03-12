require 'test_helper'

include SimpleDO
include SimpleDO::DSL

class SimpleDoCompMgrTest < Minitest::Test
  context "SimpleDo::ComponentMgr" do
    context "#push_namespace" do
      setup do
        @mgr = ComponentMgr.new
      end
      should "append namespace to name" do
        @mgr.push_namespace("sp1")
        assert_equal "sp1", @mgr.current_namespace
        @mgr.push_namespace("sp1")
        assert_equal "sp1:sp1", @mgr.current_namespace
      end
    end

    context "#pop_namespace" do
      setup do
        @mgr = ComponentMgr.new
      end
      should "remove existing namespace to name" do
        @mgr.push_namespace("sp1")
        @mgr.push_namespace("sp1")
        @mgr.pop_namespace
        @mgr.pop_namespace
        assert_equal "", @mgr.current_namespace
      end
    end
  end

  context "namespace" do
    setup do
      namespace :sp1 do
        namespace :sp2 do
          @comp1 = comp :comp1, :deps=>[ :s1, ":s2" ]
        end
      end
    end
    should "add namespace to registed comp" do
      assert_same @comp1, COMPONENT_MGR.get("sp1:sp2:comp1")
      assert_equal @comp1.name, :"sp1:sp2:comp1"
    end

    should "add namespace to depends not start with :" do
      assert_equal Set.new([ :"sp1:sp2:s1", :":s2" ]), @comp1.depends
    end
  end
end
