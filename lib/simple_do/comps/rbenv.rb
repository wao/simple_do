require 'simple_do'

include SimpleDO::DSL

    namespace :rbenv do
      comp :rbenv, deps: [ :git, :bashrc ]

      apt_install (:build_pkgs) do
        packages "git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev python-software-properties libffi-dev nodejs" 
      end 

      line_in_file :bashrc do
        line 'export PATH="$HOME/.rbenv/bin:$PATH"'
        file '.bashrc'

        depends :git
      end 

      git_clone :git do
        flag_file ".rbenv/bin/rbenv"
        repo "https://github.com/rbenv/rbenv.git"
        localpath ".rbenv"
      end

      git_clone :ruby_build, deps: :rbenv do
        flag_file "~/.rbenv/plugins/ruby-build/bin/ruby-build" 
        repo "https://github.com/rbenv/ruby-build.git"
        localpath "~/.rbenv/plugins/ruby-build"
      end
    end
