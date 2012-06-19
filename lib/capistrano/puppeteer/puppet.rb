module Capistrano
  module Puppeteer
    module Puppet

      def self.extended(configuration)
        configuration.load do
          unless exists? :puppet_path
            set(:puppet_path) { abort "Please specify the path to puppet, set :puppet_path, '/srv/puppet'" }
          end

          namespace :puppet do
            task :update do
              run_locally 'git push'
              run "cd #{puppet_path} && git pull --quiet"
            end

            desc <<-DESC
            Perform a puppet run.

            Pass options to puppt using OPTIONS

            puppet:go options="--noop"
            DESC
            task :go do
              update
              options = ENV['options'] || ENV['OPTIONS'] || ''
              run "cd #{puppet_path} && #{sudo} puppet apply --configfile puppet.conf manifests/site.pp #{options}"
            end
          end
        end
      end
    end
  end
end

if Capistrano::Configuration.instance
  Capistrano::Configuration.instance.extend Capistrano::Puppeteer::Puppet
end
