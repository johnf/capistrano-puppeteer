module Capistrano
  module Puppeteer
    module Puppet

      def self.extended(configuration)
        configuration.load do
          unless exists? :puppet_path
            set(:puppet_path) { '/srv/puppet' } unless exists? :puppet_path
          end

          namespace :puppet do
            task :update do
              fast = ENV['fast'] || ENV['FAST'] || ''
              fast = fast =~ /true|TRUE|yes|YES/

              unless fast
                system 'git push'
                if bootstrap_user
                  run "if id #{bootstrap_user} > /dev/null 2>&1 ; then #{sudo} chown -R #{bootstrap_user} #{puppet_path}; fi"
                end
                run "#{sudo} chgrp -R adm #{puppet_path}"
                run "#{sudo} chmod -R g+rw #{puppet_path}"
                run "cd #{puppet_path} && git pull --quiet"
                run "cd #{puppet_path} && if [ -f Gemfile ]; then bundle install --deployment --without=development --quiet ; fi"
                # TODO Support other methods besides henson
                run "cd #{puppet_path} && if [ -f Puppetfile ]; then bundle exec henson; fi"
              end
            end

            desc <<-DESC
            Perform a puppet run.

            Pass options to puppt using OPTIONS

            puppet:go options="--noop"
            DESC
            task :go do
              update

              options = ENV['options'] || ENV['OPTIONS'] || ''
              apply   = ENV['apply'] || ENV['APPLY'] || ''

              apply = apply =~ /true|TRUE|yes|YES/
                p apply

              puppet_options  = ['--noop']
              if options
                puppet_options += options.split(' ')
              end

              puppet_options.delete('--noop') if apply

              options = puppet_options.join(' ')

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
