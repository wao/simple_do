require 'attr_chain'
require 'sshkit'
require 'sshkit/dsl'

module SimpleDO
  class ComponentMgr 
    def initialize
      @components = {}
      @namespaces = []
    end

    def register(component, &blk)
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

    def current_namespace
      @namespaces.join(":")
    end
  end

  COMPONENT_MGR = ComponentMgr.new

  class Component
    include AttrChain
    attr_reader :namespace, :as_user, :cmd_options

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

    def resolve_name(pname)
      if pname.to_s.start_with? ":"
        pname
      else
        if @namespace.empty?
          @name
        else
          :"#{@namespace}:#{pname}"
        end
      end
    end

    def name
      resolve_name(@name)
    end

    def initialize(namespace, name, options = {}, &blk)
      @check = nil
      @up = nil
      @down = nil
      @namespace = namespace 
      @name = name.to_sym
      @deps = Set.new 
      @cmd_options = {}
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
          @deps.merge( pdeps.flatten.map{ |i| resolve_name(i).to_sym } )
        else
          @deps.add( resolve_name(pdeps).to_sym )
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

    def do_check(inst, host, params = {} )
      if @check
        inst.instance_exec( host, &@check )
      else
        false
      end
    end

    def do_up(inst, host, params = {} )
      inst.instance_exec( host, &@up ) if @up
    end

    def do_down(inst, host, params = {} )
      inst.instance_exec( host, &@down ) if @down
    end

    def run(inst, host)
      if @as_user
        inst.prepare_sudo_passwd(host) do
          inst.as @as_user do
            do_run(inst, host)
          end
        end
      else
        do_run(inst, host)
      end
    end

    def do_run(inst, host, params = {})
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

    #down this only or down all
    def run_down(inst, host)
      if do_check(inst, host )
        begin
          do_down(inst, host)
        rescue StandardError => ex
          inst.info "Got error: #{ex}, rollback #{@name}"
          # do_down( inst, host )
          raise ex
        end
      else
        inst.info "#{@name} has already be removed. skip it."
      end

      @deps.each do |dep|
        if !COMPONENT_MGR.get(dep).run_down( inst, host )
          return false
        end
      end

      !do_check(inst, host)
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
    include SSHKit::DSL
    def run_up( servers, comp )
      on servers do |host|
        COMPONENT_MGR.get( comp.to_sym ).run( self, host )
      end
    end

    def run_down( servers, comp )
      on servers do |host|
        COMPONENT_MGR.get( comp.to_sym ).run_down( self, host )
      end
    end

    def reg_comp( comp )
      COMPONENT_MGR.register(comp)
      comp
    end

    def ns
      COMPONENT_MGR.current_namespace
    end

    def comp(name, options={}, &blk)
      reg_comp( Component.new( ns, name, options, &blk) )
    end

    def namespace(name)
      COMPONENT_MGR.push_namespace(name)
      yield
    ensure
      COMPONENT_MGR.pop_namespace
    end
  end
end
