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
              ENV['fast'] ||= ENV['FAST']
              fast = case ENV['fast']
                     when nil then 'all'
                     when /pull/i then 'pull'
                     else
                       'none'
                     end

              next if fast == 'none'

              system 'git push'
              run "cd #{puppet_path} && git pull --quiet"

              next if fast == 'pull'

              run "#{sudo} chown -R `id -un` #{puppet_path}; fi"
              run "#{sudo} chgrp -R adm #{puppet_path}"
              run "#{sudo} chmod -R g+rw #{puppet_path}"
              run "cd #{puppet_path} && if [ -f Gemfile ]; then bundle install --deployment --without=development --quiet ; fi"
              # TODO Support other methods besides henson
              run "cd #{puppet_path} && if [ -f Puppetfile ]; then bundle exec henson; fi"
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
