require 'fog'

module Capistrano
  module Puppeteer
    module AWS
      FLAVOURS = {
        't1.micro'    => {:ram => 0.6,  :io => 'low',      :compute => 2,    :price => 0.02},

        'm1.small'    => {:ram => 1.7,  :io => 'moderate', :compute => 1,    :price => 0.08},
        'm1.medium'   => {:ram => 3.75, :io => 'moderate', :compute => 2,    :price => 0.16},
        'm1.large'    => {:ram => 7.5,  :io => 'high',     :compute => 4,    :price => 0.32},
        'm1.xlarge'   => {:ram => 15,   :io => 'high',     :compute => 8,    :price => 0.64},

        'm2.xlarge'   => {:ram => 17.1, :io => 'moderate', :compute => 6.5,  :price => 0.45},
        'm2.2xlarge'  => {:ram => 34.2, :io => 'high',     :compute => 13,   :price => 0.90},
        'm2.4xlarge'  => {:ram => 68.4, :io => 'high',     :compute => 26,   :price => 1.80},

        'c1.medium'   => {:ram => 1.7,  :io => 'moderate', :compute => 5,    :price => 0.165},
        'c1.xlarge'   => {:ram => 7,    :io => 'high',     :compute => 20,   :price => 0.66},

        'cc1.4xlarge' => {:ram => 23,   :io => 'v.high',   :compute => 33.5, :price => 1.30},
        'cc1.8xlarge' => {:ram => 60.5, :io => 'v.high',   :compute => 88  , :price => 2.40},

        'cg1.4xlarge' => {:ram => 22,   :io => 'v.high',   :compute => 33.5, :price => 2.10},
      }

      def self.extended(configuration)
        configuration.load do
          set(:cloud_provider)        { abort "Please specify a cloud provider, set :cloud_provider, 'AWS'" } unless exists? :cloud_provider
          set(:aws_ami)               { abort "Please specify a AWS AMI, set :aws_ami, 'ami-a29943cb'" } unless exists? :aws_ami
          set(:aws_secret_access_key) { abort "Please specify an AWS Access Key, set :aws_secret_access_key, 'XXXX'" } unless exists? :aws_secret_access_key
          set(:aws_access_key_id)     { abort "Please specify a AWS AMI, set :aws_access_key_id, 'ZZZ'" } unless exists? :aws_access_key_id
          set(:aws_region)            { abort "Please specify a AWS AMI, set :aws_region, 'us-west-1'" } unless exists? :aws_availability_zone
          set(:aws_availability_zone) { abort "Please specify a AWS AMI, set :aws_availability_zone, 'us-west-1a'" } unless exists? :aws_availability_zone
          set(:aws_key_name)          { abort "Please specify a AWS AMI, set :aws_key_name, 'default'" } unless exists? :aws_key_name
          set(:aws_ssh_key)           { abort "Please specify a AWS AMI, set :aws_ssh_key, 'config/aws.pem'" } unless exists? :aws_ssh_key

         namespace :aws do

            desc <<-DESC
              create an AWS instance.

                cap aws:create [OPTIONS]

              Available options:

                flavour  (required) - The type of EC2 instance to create
                name     (required) - The name of the instance, this will be used as the AWS tag
                iam_role            - An IAM role to apply to the instance

            DESC
            task :create do
              flavour = ENV['flavour'] || abort('please specify a flavour')
              name = ENV['name'] || abort('please specify name')
              iam_role = ENV['iam_role']

              puts "Creating Instance..."
              instance_options = {
                :image_id          => aws_ami,
                :availability_zone => aws_availability_zone,
                :flavor_id         => flavour,
                :key_name          => aws_key_name,
                :tags              => { 'Name' => name },
              }

              options[:iam_instance_profile] = iam_role if iam_role

              server = servers.create instance_options
              server.wait_for { ready? }
              server.reload
              ENV['HOSTS'] = server.public_ip_address
            end


            desc 'List Instance types'
            task :flavours do
              puts "%-11s  %-11s   %-7s %-5s  %s" % %w[Name Price/Month RAM Units IO]
              Capistrano::Puppeteer::AWS::FLAVOURS.each do |flavor, opts|
                puts "%-11s  $ %7.2f   %4.1f GB   %4.1f   %s" % [flavor, opts[:price] * 720, opts[:ram], opts[:compute], opts[:io]]
              end
            end

            desc 'List current AWS instances'
            task :list do
              format = '%-15s  %-10s  %-8s  %-10s  %-43s  %-15s  %-10s  %-s %s'
              puts format % %w{Name ID State Zone DNS IP Type CreatedAt ImageID}
              servers.sort {|a,b| (a.tags['Name'] || 'Unknown') <=> (b.tags['Name'] || 'Unknown') }.each do |server|
                puts format % [server.tags['Name'], server.id, server.state, server.availability_zone, server.dns_name, server.private_ip_address, server.flavor_id, server.created_at, server.image_id]
              end
            end

            desc 'Describe an instance'
            desc <<-DESC
              Describe an AWS instance.

                cap aws:show instance_id=...

            DESC
            task :show do
              instance_id = ENV['instance_id'] || abort('provide an instance_id')
              server = servers.get instance_id
              p server
            end

            desc <<-DESC
              Start an AWS instance.

                cap aws:start instance_id=...

            DESC
            task :start do
              instance_id = ENV['instance_id'] || abort('provide an instance_id')

              server = servers.get instance_id
              server.start
            end

            desc <<-DESC
              Stop an AWS instance.

                cap aws:stop instance_id=...

                Options:
                force=true - Forces a stop for a hung instance

            DESC
            task :stop do
              instance_id = ENV['instance_id'] || abort('provide an instance_id')
              force = ENV['force'] =~ /^true$/i

              server = servers.get instance_id
              server.stop force
            end

            desc <<-DESC
              Destroy an AWS instance.

                cap aws:destroy instance_id=...

            DESC
            task :destroy do
              instance_id = ENV['instance_id'] || abort('provide an instance_id')

              server = servers.get instance_id
              server.destroy
            end

            desc <<-DESC
              Reboot an AWS instance.

                cap aws:reboot instance_id=...

                Options:
                force=true - Forces a stop for a hung instance

            DESC
            task :reboot do
              instance_id = ENV['instance_id'] || abort('provide an instance_id')
              force = ENV['force'] =~ /^true$/i

              server = servers.get instance_id
              server.reboot force
            end

            def compute
              @compute ||= Fog::Compute.new(
                :provider              => cloud_provider,
                :region                => aws_region,
                :aws_secret_access_key => aws_secret_access_key,
                :aws_access_key_id     => aws_access_key_id,
              )
            end

            def servers
              @servers ||= compute.servers
            end

          end

        end
      end
    end
  end
end

if Capistrano::Configuration.instance
  Capistrano::Configuration.instance.extend Capistrano::Puppeteer::AWS
end
