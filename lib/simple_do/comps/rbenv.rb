require 'simple_do'

module SimpleDO
  module Ext 
    include SimpleDO::DSL

    def decl_rbenv_install(name, p_user=nil, p_umask="0022")
      l_cmd_options = { umask: p_umask }

      namespace name do
        namespace :rbenv do
          comp :rbenv, deps: [ :git, :bashrc ]

          apt_install (:build_pkgs) do
            packages "git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev python-software-properties libffi-dev nodejs libev-dev libgmp3-dev" 
          end 

          line_in_file :bashrc do
            line 'export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"'
            file "/home/#{p_user}/.bashrc"

            depends :git
          end 

          git_clone :git do
            cmd_options l_cmd_options
            flag_file "/home/#{p_user}/.rbenv/bin/rbenv"
            repo "https://github.com/rbenv/rbenv.git"
            localpath "/home/#{p_user}/.rbenv"
          end

          git_clone :ruby_build, deps: :rbenv do
            cmd_options l_cmd_options
            flag_file "/home/#{p_user}/.rbenv/plugins/ruby-build/bin/ruby-build" 
            repo "https://github.com/rbenv/ruby-build.git"
            localpath "/home/#{p_user}/.rbenv/plugins/ruby-build"
          end

          comp :ruby240, deps: [ :build_pkgs, :ruby_build ] do
            as_user p_user if p_user
            if p_user
              dir "/home/#{p_user}"
            end

            check{
              test(" [[ -e /home/#{p_user}/.rbenv/versions/2.4.0 ]] " )
            }

            up{
              with rbenv_root: "/home/#{p_user}/.rbenv" do
                execute( "/home/#{p_user}/.rbenv/bin/rbenv", "install 2.4.0" )
                execute( "/home/#{p_user}/.rbenv/bin/rbenv", "global 2.4.0" )
                execute( "/home/#{p_user}/.rbenv/shims/gem", "install bundler" )
              end
            }

            down{
              execute( :rm, "-rf", "/home/#{p_user}/.rbenv/versions/2.4.0" )
            }
          end
        end
      end
    end
  end
end
