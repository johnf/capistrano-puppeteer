module Capistrano
  module Puppeteer
    module Bootstrap

      def self.extended(configuration)
        configuration.load do
          set(:bootstrap_domain) { abort "Please specify a domain, set :bootstrap_domain, 'inodes.org'" } unless exists? :bootstrap_domain
          set(:bootstrap_user)   { abort "Please specify a user, set :bootstrap_user, 'johnf'" } unless exists? :bootstrap_domain
          set(:puppet_path)      { abort "Please specify the path to puppet, set :puppet_path, '/srv/puppet'" } unless exists? :puppet_path
          set(:puppet_repo)      { abort "Please specify the path to puppet, set :puppet_reop, 'git@...'" } unless exists? :puppet_repo

          namespace :bootstrap do

            desc 'Create and bootstrap the server'
            task :create do
              puts "NOTE: Add host to puppet first and git push"
              puts
              sleep 5

              name = ENV['name'] or abort('please supply a name')
              ENV['FQDN'] ||= "#{name}.#{bootstrap_domain}"
              aws.create
              sleep 20 # Give SSH time to come up
              bootstrap.go
            end

            desc 'Bootstrap the server with pupper'
            task :go do
              system "ssh-add #{ssh_key}"
              hostname
              github
              upgrade
              puppet_setup
              puppet_ubuntu
              puppet.go
            end

            task :hostname do
              set :user, 'ubuntu'
              if ENV['FQDN']
                fqdn = ENV['FQDN']
              else
                fqdn = Capistrano::CLI.ui.ask "What is the full FQDN for the host"
              end
              hostname = fqdn.split('.')[0]

              run "#{sudo} sudo sed -i -e '/127.0.0.1/a127.0.1.1 #{fqdn} #{hostname}' /etc/hosts"
              run "echo #{hostname} | #{sudo} tee /etc/hostname > /dev/null"
              run "sudo sed -itmp -e 's/\\(domain\\|search\\).*/\\1 #{bootstrap_domain}/' /etc/resolv.conf"
              run "#{sudo} service hostname start"
            end

            task :github do
              set :user, 'ubuntu'
              run "mkdir -p .ssh"
              run "echo 'github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==' >> .ssh/known_hosts"
            end

            task :upgrade do
              set :user, 'ubuntu'

              run "#{sudo} apt-get -y update"
              run "DEBIAN_FRONTEND=noninteractive #{sudo} -E apt-get -y dist-upgrade"
            end

            def remote_file_exists?(full_path)
              'true' ==  capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
            end

            task :puppet_setup do
              set :user, 'ubuntu'

              release = capture 'lsb_release  --codename --short | tr -d "\n"'
              fail "unable to determine distro release" if release.empty?

              # add puppetlabs apt repos
              unless remote_file_exists? puppet_path
                filename = '/etc/apt/sources.list.d/puppetlabs.list'
                run "echo 'deb http://apt.puppetlabs.com/ #{release} main' | #{sudo} tee #{filename}"
              end
              run "#{sudo} apt-key adv --keyserver keyserver.ubuntu.com --recv 4BD6EC30"
              run "#{sudo} apt-get -yq update"
              run "#{sudo} apt-get install -y puppet libaugeas-ruby git"

              unless remote_file_exists? puppet_path
                run "cd /tmp && git clone #{puppet_repo}"
                run "#{sudo} mv /tmp/puppet #{puppet_path}"
              end

              run "#{sudo} mkdir -p /home/#{bootstrap_user}/.ssh"
              run "#{sudo} echo 'github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==' | #{sudo} tee /home/#{bootstrap_user}/.ssh/known_hosts"
            end

            task :puppet_ubuntu do
              set :user, 'ubuntu'

              run 'cd /srv/puppet && git pull'

              puppet.go
            end

            task :reboot do
              set :user, ENV['USER']

              run "#{sudo} reboot"
            end

          end

        end
      end
    end
  end
end

if Capistrano::Configuration.instance
  Capistrano::Configuration.instance.extend Capistrano::Puppeteer::Bootstrap
end
