require 'simple_do'

module SimpleDO
  module DSL
    namespace :nginx do
      apt_install :install_pkgs do
        packages "nginx"
      end

      remove_file :remove_default_site do
        path "/etc/nginx/sites-available/default"
      end

      comp :install, deps: [ :install_pkgs, :remove_default_site ]
    end
  end
end
