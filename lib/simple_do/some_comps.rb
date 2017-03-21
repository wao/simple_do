require 'simple_do/comp'
require 'shellwords'

module SimpleDO
  class AddUser < Component
    def_fields :user_name, :shell, :has_home, :group, :passwd

    def initialize(namespace, name, options, &blk)
      super
    end

    def setup_proc
      comp = self
      home = if @has_home
               "-m"
             else
               "-M"
             end

      group = if @group
                " -G #{@group}"
              else
                "" 
              end

      shell = @shell || "/bin/false"

      set_check( Proc.new{ |host| test( " grep #{comp.user_name} /etc/passwd " ) } )
      set_up( Proc.new{ |host|
          prepare_sudo_password( host ) do
            as :root do
              execute( :useradd, " #{home} -s #{shell} #{group} #{comp.user_name}" )
            end
          end
      })
      set_down( Proc.new{ |host|
          prepare_sudo_password( host ) do
            as :root do
              execute( :deluser, "--remove-home", comp.user_name )
              if comp.passwd
                execute( :passwd, comp.user_name, interaction_handler: {
                  /Enter new UNIX password.*/ => "#{comp.passwd}\n",
                  /Retype new UNIX password.*/ => "#{comp.passwd}\n"
                })
              end
            end
          end
      })
    end
  end

  class RemoveFile < Component
    def_fields :path

    def initialize(namespace, name, options, &blk)
      super
    end

    def setup_proc
      comp = self
      set_check( Proc.new{ |host| !test( " [ -f #{comp.path} ] " ) } )
      set_up( Proc.new{ |host|
        if test( " [ -w '#{File.dirname comp.path}' ] " )
          execute( :rm, comp.path )
        else
          prepare_sudo_password( host ) do
            as :root do
              execute( :rm, comp.path )
            end
          end
        end
      })
    end
  end

  class SymbolLink < Component
    def_fields :target, :link

    def initialize(namespace, name, options, &blk)
      super
    end

    #TODO Need to specify user, permission, group, maybe need sudo
    def setup_proc
      comp = self
      # raise ArgumentError.new( "File #{comp.target} is not exist!" ) if !File.exists? comp.target

      set_check( ->(host) do 
        test(" [ -e #{comp.link} ] " )
      end )

      set_up( Proc.new{ |host|
        if test( " [ -w '#{File.dirname comp.link}' ] " )
          execute( :ln, "-s", comp.target, comp.link  ) 
        else
          prepare_sudo_password( host ) do
            as :root do
              execute( :ln, "-s", comp.target, comp.link  ) 
            end
          end
        end
      })

      set_down( Proc.new{ |host|
        if test( " [ -w '#{File.dirname comp.link}' ] " )
          execute( :rm, comp.link ) 
        else
          prepare_sudo_password( host ) do 
            as :root do
              execute( :rm, comp.link ) 
            end
          end
        end
      } )
    end
  end

  class CopyFile < Component
    def_fields :local, :remote, :owner, :permission

    def initialize(namespace, name, options, &blk)
      super
    end

    #TODO Need to specify user, permission, group, maybe need sudo
    def setup_proc
      comp = self
      raise ArgumentError.new( "File #{comp.local} is not exist!" ) if !File.exists? comp.local

      set_check( ->(host) do 
        if !test(" [ -f #{comp.remote} ] " )
          next false
        end

        local_checksum = `md5sum #{comp.local}`
        remote_checksum = capture( :md5sum, comp.remote )
        local_checksum.strip.split(" ")[0] == remote_checksum.strip.split(" ")[0]
      end )

      set_up( Proc.new{ |host|
        upload! comp.local, "tmp"
        if comp.permission
          execute( :chmod, comp.permission, "tmp" )
        end
        if test( " [ -w '#{File.dirname comp.remote}' ] " )
          execute( :mv, "tmp",  comp.remote  ) 
        else
          prepare_sudo_password( host ) do
            as :root do
              execute( :mv, "tmp",  comp.remote  ) 
            end
          end
        end
        if comp.owner
          prepare_sudo_password( host ) do
            as :root do
              execute( :chmod, comp.permission, comp.remote )
            end
          end
        end
      })

      set_down( Proc.new{ |host|
        if test( " [ -w '#{File.dirname comp.remote}' ] " )
          execute( :rm, comp.remote ) 
        else
          prepare_sudo_password( host ) do 
            as :root do
              execute( :rm, comp.remote ) 
            end
          end
        end
      } )
    end
  end

  class LineInFile < Component
    def_fields :line, :file

    def initialize(namespace, name, options, &blk)
      super
    end

    def setup_proc
      line = "'#{Shellwords.escape(@line)}'"
      file = "'#{Shellwords.escape(@file)}'"

      set_check( Proc.new{ |host| test("[[ -e #{@file} ]]") && test( :grep, line, file ) } )
      set_up( Proc.new{ |host| execute( :echo, line,  ">>", file  ) } )
    end
  end

  class AptInstall < Component
    def initialize(namespace, name, options, &blk)
      @pkgs = []
      super
    end

    def setup_proc
      pkgs = @pkgs.join(" ")
      set_up( Proc.new{ |host|
        prepare_sudo_password( host ) do
          as :root do
            execute( :"apt-get", "-y", "install", pkgs )
          end
        end
      })
    end

    def packages(*pkgs)
      @pkgs.concat(pkgs)
    end
  end

  class GitClone < Component
    def initialize(namespace, name, options, &blk)
      @flag_type = :unknown
      super
    end

    def setup_proc
      comp = self
      flag_file = @flag_file
      flag_type = case @flag_type
                  when :file
                    " -f "
                  when :dir
                    " -d "
                  else
                    " -e "
                  end
      repo = @repo
      localpath = @localpath

      set_check( Proc.new{ |host|
        test(" [ #{flag_type} #{flag_file} ] " ) 
      })

      set_up( Proc.new{ |host|  
        if test(" [ -d #{localpath} ] " ) 
          execute( :rm, "-rf #{localpath}" )
        end
        execute( :git, "clone", repo, localpath, comp.cmd_options )
        # execute( "echo 'export PATH=\"$HOME/.rbenv/bin:$PATH\"' >> ~/.bashrc" )
      })

      set_down( Proc.new{ |host|
        execute( :rm, "-rf", localpath )
      })
    end 

    def flag_file( filename )
      @flag_file = filename
    end

    def localpath( path )
      @localpath = path
    end

    def repo( url )
      @repo = url
    end
  end

  module DSL
    def line_in_file(name, options={}, &blk)
      reg_comp( LineInFile.new(ns, name, options, &blk) )
    end

    def apt_install(name, options={}, &blk)
      reg_comp( AptInstall.new(ns, name, options, &blk) )
    end

    def remove_file(name, options={}, &blk)
      reg_comp( RemoveFile.new(ns, name, options, &blk) )
    end

    def git_clone(name, options={}, &blk)
      reg_comp( GitClone.new(ns, name, options, &blk) )
    end

    def copy_file(name, options={}, &blk)
      reg_comp( CopyFile.new(ns, name, options, &blk) )
    end

    def symbol_link(name, options={}, &blk)
      reg_comp( SymbolLink.new(ns, name, options, &blk) )
    end

    def add_user(name, options={}, &blk)
      reg_comp( AddUser.new(ns, name, options, &blk) )
    end
  end
end
