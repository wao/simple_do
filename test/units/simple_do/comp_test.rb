require 'test_helper'

include SimpleDO
include SimpleDO::DSL

class SimpleDoCompMgrTest < Minitest::Test
  context "SimpleDo::ComponentMgr" do
    context "#push_namespace" do
      setup do
        @mgr = ComponentMgr.new
      end
      should "append namespace to register component name" do
        @mgr.push_namespace("sp1")
        comp1 = Component.new(:comp1) 
        @mgr.register( comp1 )
        assert_same comp1, @mgr.get(:"sp1:comp1")
      end
    end

    context "#pop_namespace" do
      setup do
        @mgr = ComponentMgr.new
      end
      should "append namespace to register component name" do
        @mgr.push_namespace("sp1")
        @mgr.pop_namespace
        comp1 = Component.new(:comp1) 
        @mgr.register( comp1 )
        assert_same comp1, @mgr.get(:comp1)
      end
    end
  end

  context "namespace" do
    should "add namespace to registed comp" do
      comp1 = nil
      namespace :sp1 do
        namespace :sp2 do
          comp1 = comp :comp1
        end
      end

      assert_same comp1, COMPONENT_MGR.get("sp1:sp2:comp1")
      assert_equal comp1.name, :"sp1:sp2:comp1"
    end
  end
end
