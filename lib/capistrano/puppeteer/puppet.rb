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
              system 'git push'
              run "#{sudo} chgrp -R adm #{puppet_path}"
              run "#{sudo} chmod -R g+rw #{puppet_path}"
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
              run "cd #{puppet_path} && #{sudo} puppet apply --config puppet.conf --verbose #{options} manifests/site.pp"
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
