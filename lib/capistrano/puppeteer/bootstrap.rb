require 'socket'
require 'timeout'

module Capistrano
  module Puppeteer
    module Bootstrap

      def self.extended(configuration)
        configuration.load do
          set(:bootstrap_domain) { abort "Please specify a domain, set :bootstrap_domain, 'inodes.org'" } unless exists? :bootstrap_domain
          set(:bootstrap_user)   { abort "Please specify a user, set :bootstrap_user, 'johnf'" } unless exists? :bootstrap_domain
          set(:puppet_path)      { abort "Please specify the path to puppet, set :puppet_path, '/srv/puppet'" } unless exists? :puppet_path
          set(:puppet_repo)      { abort "Please specify the path to puppet, set :puppet_repo, 'git@...'" } unless exists? :puppet_repo

          namespace :bootstrap do

            desc <<-DESC
              Create and bootstrap the server.

              Needs options from aws:create.
            DESC
            task :create do
              puts "NOTE: Add host to puppet first and git push"
              puts

              name = ENV['name'] or abort('please supply a name')
              ENV['fqdn'] ||= "#{name}.#{bootstrap_domain}"
              aws.create
              unless wait_for_ssh
                abort "Timed out waiting for SSH to come up on #{ENV['HOSTS']}"
              end
              bootstrap.go
            end

            def wait_for_ssh
              60.times do
                begin
                  Timeout::timeout(1) do
                    s = TCPSocket.new(ENV['HOSTS'], 22)
                    s.close
                    return true
                  end
                rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
                end
              end

              return false
            end

            desc <<-DESC
              Bootstrap the server with puppet.

                * Sets the hostname
                * Adds github SSH keys to known_hosts
                * Upgrades all the packages
                * Installs and configures pupper
                * Performs puppet runs

              Options:

                 skip_puppet=true     (optional)   to skip the puppet run
                 fqdn=foo.example.com (optional)   the hostname of the new instance (prompted if not set)

            DESC
            task :go do
              if exists? :ssh_key
                system "ssh-add #{ssh_key}"
              end
              hostname
              github
              upgrade
              puppet_setup
              unless ENV['skip_puppet']
                if exists?(:cloud_provider) && cloud_provider == 'AWS'
                  # Run puppet once as the ubuntu user to give puppet a chance to create out standard user
                  set :user, 'ubuntu'
                  puppet.go
                  set :user, bootstrap_user
                end
                puppet.go
              end
            end

            task :hostname do
              set :user, 'ubuntu' if exists?(:cloud_provider) && cloud_provider == 'AWS'
              fqdn = ENV['fqdn'] || Capistrano::CLI.ui.ask('What is the full fqdn for the host')
              hostname = fqdn.split('.')[0]

              run "#{sudo} sudo sed -i -e '/127.0.0.1/a127.0.1.1 #{fqdn} #{hostname}' /etc/hosts"
              run "echo #{hostname} | #{sudo} tee /etc/hostname > /dev/null"
              run "#{sudo} sed -itmp -e 's/\\(domain\\|search\\).*/\\1 #{bootstrap_domain}/' /etc/resolv.conf"
              run "#{sudo} service hostname start"
            end

            task :github do
              set :user, 'ubuntu' if exists?(:cloud_provider) && cloud_provider == 'AWS'
              run "mkdir -p .ssh"
              run "echo 'github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==' >> .ssh/known_hosts"

              run "#{sudo} mkdir -p /home/#{bootstrap_user}/.ssh"
              run "echo 'github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==' | #{sudo} tee /home/#{bootstrap_user}/.ssh/known_hosts"
            end

            task :upgrade do
              set :user, 'ubuntu' if exists?(:cloud_provider) && cloud_provider == 'AWS'

              run "#{sudo} apt-get --quiet --yes update"
              run "DEBIAN_FRONTEND=noninteractive #{sudo} -E apt-get --yes dist-upgrade"
            end

            def remote_file_exists?(full_path)
              'true' ==  capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
            end

            task :puppet_setup do
              set :user, 'ubuntu' if exists?(:cloud_provider) && cloud_provider == 'AWS'

              release = capture 'lsb_release  --codename --short | tr -d "\n"'
              fail "unable to determine distro release" if release.empty?

              # add puppetlabs apt repos
              unless remote_file_exists? puppet_path
                filename = '/etc/apt/sources.list.d/puppetlabs.list'
                run "echo 'deb http://apt.puppetlabs.com/ #{release} main dependencies' | #{sudo} tee #{filename}"
              end
              run "#{sudo} apt-key adv --keyserver keyserver.ubuntu.com --recv 4BD6EC30"
              run "#{sudo} apt-get -yq update"
              run "#{sudo} apt-get install -y puppet libaugeas-ruby git"

              unless remote_file_exists? puppet_path
                run "git clone #{puppet_repo} /tmp/puppet"
                run "#{sudo} mv /tmp/puppet #{puppet_path}"
              end

            end

            task :reboot do
              set :user, bootstrap_user

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
