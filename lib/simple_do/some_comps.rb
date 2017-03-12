require 'simple_do/comp'
require 'shellwords'
require 'byebug'

module SimpleDO
    class RemoveFile < Component
        def_fields :path

        def initialize(name, options, &blk)
            super
        end

        def setup_proc
            comp = self
            set_check( Proc.new{ !test( " [ -f #{comp.path} ] " ) } )
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

    class CopyFile < Component
        def_fields :local, :remote, :owner, :permission

        def initialize(name, options, &blk)
            super
        end

        #TODO Need to specify user, permission, group, maybe need sudo
        def setup_proc
            comp = self
            raise ArgumentError.new( "File #{comp.remote} is not exist!" ) if !File.exists? comp.remote

            set_check( Proc.new do 
                if !test(" [ -f #{comp.remote} ] " )
                    return false
                end

                local_checksum = `md5sum #{comp.local}`
                remote_checksum = capture( :md5sum, comp.remote )
                local_checksum == remote_checksum
            end )

            set_up( Proc.new{ |host|
                upload! comp.local, "tmp"
                if comp.permission
                    excute( :chmod, "tmp", comp.permission )
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

        def initialize(name, options, &blk)
            super
        end

        def setup_proc
            line = "'#{Shellwords.escape(@line)}'"
            file = "'#{Shellwords.escape(@file)}'"

            set_check( Proc.new{ test( :grep, line, file ) } )
            set_up( Proc.new{ execute( :echo, line,  ">>", file  ) } )
        end
    end

    class AptInstall < Component
        def initialize(name, options, &blk)
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
        def initialize(name, options, &blk)
            @flag_type = :unknown
            super
        end

        def setup_proc
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

            set_up( Proc.new{  
                if test(" [ -d #{localpath} ] " ) 
                    execute( :rm, "-rf #{localpath}" )
                end
                execute( :git, "clone", repo, localpath )
                # execute( "echo 'export PATH=\"$HOME/.rbenv/bin:$PATH\"' >> ~/.bashrc" )
            })

            set_down( Proc.new{
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
            reg_comp( LineInFile.new(name, options, &blk) )
        end

        def apt_install(name, options={}, &blk)
            reg_comp( AptInstall.new(name, options, &blk) )
        end

        def remove_file(name, options={}, &blk)
            reg_comp( RemoveFile.new(name, options, &blk) )
        end
    end
end
