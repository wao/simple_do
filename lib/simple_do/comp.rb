require 'attr_chain'

module SimpleDO
  class ComponentMgr 
    def initialize
      @components = {}
      @namespaces = []
    end

    def register(component, &blk)
      component.name( gen_name(component.name) )
      @components[component.name] = component
      component.instance_eval( &blk )
    end

    def get(name)
      @components[name.to_sym]
    end

    def push_namespace(name)
      @namespaces.push(name.to_sym)
    end

    def pop_namespace()
      @namespaces.pop
    end

    def gen_name(name)
      ret = @namespaces.push(name).join(":").to_sym
      @namespaces.pop
      ret
    end
  end

  COMPONENT_MGR = ComponentMgr.new

  class Component
    include AttrChain
    attr_chain :name

    def self.fields
      @fields || @fields = []
    end

    def self.append_fields(*args)
      fields.concat( args.flatten.map{ |i| i.to_sym } )
    end

    def self.def_fields(*args)
      attr_chain( *args )
      append_fields( *args )
    end

    def set_check(check)
      @check = check
    end

    def set_down(down)
      @down = down
    end

    def set_up(up)
      @up = up
    end

    def initialize(name, options = {}, &blk)
      @check = nil
      @up = nil
      @down = nil
      @name = name
      @deps = Set.new 
      self.class.fields.each do |fname|
        if options.include? fname
          self.send( fname, options[fname] )
        end
      end
      if options.include? :deps
        depends( options[:deps] )
      end
      if blk
        instance_eval(&blk)
      end
    end

    def instance_eval(&blk)
      if blk
        super(&blk)
      end
      setup_proc
    end

    def setup_proc
    end

    def depends( *pdeps )
      if pdeps.empty?
        @deps
      else
        if pdeps.is_a? Array
          @deps.merge( pdeps.flatten.map{ |i| i.to_sym } )
        else
          @deps.add( pdeps.to_sym )
        end
        self
      end
    end

    def check(&blk)
      @check = blk
    end

    def up(&blk)
      @up = blk
    end

    def down(&blk)
      @down = blk
    end

    def do_check(inst, host )
      if @check
        inst.instance_eval( &@check )
      else
        false
      end
    end

    def do_up(inst, host )
      inst.instance_eval( &@up ) if @up
    end

    def do_down(inst, host )
      inst.instance_eval( &@down ) if @down
    end

    def run(inst, host)
      if do_check(inst, host ) 
        inst.info "#{@name} has already be updated to latest status. skip it."
        true
      else
        if check_deps( inst, host )
          begin
            do_up(inst, host)
            return true
          rescue StandardError => ex
            inst.info "Got error: #{ex}, rollback #{@name}"
            # do_down( inst, host )
            raise ex
          end
        else
          return false
        end
      end
      do_check(inst, host)
    end

    def check_deps( inst, host )
      @deps.each do |dep|
        if !COMPONENT_MGR.get(dep).run( inst, host )
          return false
        end
      end
      true
    end
  end

  module DSL
    def reg_comp( comp )
      COMPONENT_MGR.register(comp)
      comp
    end

    def comp(name, options={}, &blk)
      reg_comp( Component.new(name, options, &blk) )
    end

    def namespace name
      COMPONENT_MGR.push_namespace(name)
      yield
    ensure
      COMPONENT_MGR.pop_namespace
    end
  end
end
