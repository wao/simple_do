require 'sshkit'
require 'sshkit/dsl'
module SSHKit

    # @author Lee Hambley
    class Command
        def user(&_block)
            return yield unless options[:user]
            "sudo -A -u #{options[:user]} #{environment_string + " " unless environment_string.empty?}-- sh -c '#{yield}'"
        end
    end
end


module SSHKit
    module Backend
        class Abstract
            ASKPASS_TMPL=<<__END__
#!/usr/bin/env bash

echo "%s"
__END__

            def prepare_sudo_password(host, &_block)    
                if host[:password].nil?
                    @askpass = nil
                    yield
                else
                    ask_pass = ASKPASS_TMPL % host[:password]
                    File.write( "pass_agent.sh", ask_pass )
                    upload! "pass_agent.sh", "pass_agent.sh"
                    File.unlink( "pass_agent.sh" )
                    execute(:chmod, "a+x", "pass_agent.sh")
                    @askpass = capture(:realpath, "pass_agent.sh")
                    with( SUDO_ASKPASS: @askpass ) do
                        yield
                    end
                end
            ensure
                if !host[:password].nil?
                    execute(:rm, "pass_agent.sh" )
                end
                @askpass = nil
            end

            def as(who, &_block)
                if who.is_a? Hash
                    @user  = who[:user]  || who["user"]
                    @group = who[:group] || who["group"]
                else
                    @user  = who
                    @group = nil
                end
                execute <<-EOTEST, verbosity: Logger::DEBUG
                    if ! #{ "SUDO_ASKPASS=#{@askpass}" if @askpass } sudo #{"-A" if @askpass} -u #{@user} whoami > /dev/null
                        then echo "You cannot switch to user '#{@user}' using sudo, please check the sudoers file" 1>&2
                        false
                     fi
                EOTEST
                yield
            ensure
                remove_instance_variable(:@user)
                remove_instance_variable(:@group)
            end
        end
    end
end

SSHKit.config.output_verbosity = :debug
