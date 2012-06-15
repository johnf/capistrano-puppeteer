require 'puppeteer/version'
require 'capistrano'

module Capistrano

  class Puppeteer
    def self.extended(configuration)
      configuration.load do
        _cset(:puppet_path) { abort "Please specify the path to puppet, set :puppet_path, '/srv/puppet'" }

        namespace :puppet do
          task :update do
            run_locally 'git push'
            run "cd #{puppet_path} && git pull --quiet"
          end

          desc 'Perform a puppet run'
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

if Capistrano::Configuration.instance
  Capistrano::Configuration.instance.extend Capistrano::Puppeteer
end
