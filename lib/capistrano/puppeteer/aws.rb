require 'fog'

module Capistrano
  module Puppeteer
    module AWS
      FLAVOURS = {
        't1.micro'    => {:ram => 0.6,  :io => 'low',      :compute => 2,    :price => 0.02,  :ebs_opt => false, :disk => 0 },

        'm1.small'    => {:ram => 1.7,  :io => 'moderate', :compute => 1,    :price => 0.06,  :ebs_opt => false, :disk => 160 },
        'm1.medium'   => {:ram => 3.75, :io => 'moderate', :compute => 2,    :price => 0.12,  :ebs_opt => false, :disk => 410 },
        'm1.large'    => {:ram => 7.5,  :io => 'moderate', :compute => 4,    :price => 0.24,  :ebs_opt => 500,   :disk => 850 },
        'm1.xlarge'   => {:ram => 15,   :io => 'high',     :compute => 8,    :price => 0.48,  :ebs_opt => 1000,  :disk => 1690 },

        'm3.xlarge'   => {:ram => 15,   :io => 'moderate', :compute => 13,   :price => 0.50,  :ebs_opt => 500,   :disk => 0 },
        'm3.2xlarge'  => {:ram => 30,   :io => 'high',     :compute => 26,   :price => 1.00,  :ebs_opt => 1000,  :disk => 0 },

        'm2.xlarge'   => {:ram => 17.1, :io => 'moderate', :compute => 6.5,  :price => 0.41,  :ebs_opt => false, :disk => 420 },
        'm2.2xlarge'  => {:ram => 34.2, :io => 'high',     :compute => 13,   :price => 0.82,  :ebs_opt => 500,   :disk => 850 },
        'm2.4xlarge'  => {:ram => 68.4, :io => 'high',     :compute => 26,   :price => 1.64,  :ebs_opt => 1000,  :disk => 1690 },

        'c1.medium'   => {:ram => 1.7,  :io => 'moderate', :compute => 5,    :price => 0.145, :ebs_opt => false, :disk => 350 },
        'c1.xlarge'   => {:ram => 7,    :io => 'high',     :compute => 20,   :price => 0.58,  :ebs_opt => 1000,  :disk => 1690 },

        'cc2.8xlarge' => {:ram => 60.5, :io => 'v.high',   :compute => 88,   :price => 2.40,  :ebs_opt => false, :disk => 3370 },

        'cr1.8xlarge' => {:ram => 224,  :io => 'v.high',   :compute => 88,   :price => 3.50,  :ebs_opt => false, :disk => 240,   :other => 'ssd' },

        'cg1.4xlarge' => {:ram => 22,   :io => 'v.high',   :compute => 33.5, :price => 2.10,  :ebs_opt => false, :disk => 1690,  :other => 'gpu' },

        'hi1.4xlarge' => {:ram => 60.5, :io => 'v.high',   :compute => 35,   :price => 3.10,  :ebs_opt => false, :disk => 1024,  :other => 'ssd' },

        'hs1.8xlarge' => {:ram => 117,  :io => 'v.high',   :compute => 35,   :price => 4.60,  :ebs_opt => false, :disk => 48000, :other => 'disk' },
      }

      def self.extended(configuration)
        configuration.load do
          set(:cloud_provider)        { abort "Please specify a cloud provider, set :cloud_provider, 'AWS'" } unless exists? :cloud_provider
          set(:aws_ami)               { abort "Please specify an AWS AMI, set :aws_ami, 'ami-a29943cb'" } unless exists? :aws_ami
          set(:aws_secret_access_key) { abort "Please specify an AWS Access Key, set :aws_secret_access_key, 'XXXX'" } unless exists? :aws_secret_access_key
          set(:aws_access_key_id)     { abort "Please specify an AWS AMI, set :aws_access_key_id, 'ZZZ'" } unless exists? :aws_access_key_id
          set(:aws_region)            { abort "Please specify an AWS Region, set :aws_region, 'us-west-1'" } unless exists? :aws_availability_zone
          set(:aws_availability_zone) { abort "Please specify an AWS AZ, set :aws_availability_zone, 'us-west-1a'" } unless exists? :aws_availability_zone
          set(:aws_key_name)          { abort "Please specify an AWS Key Name, set :aws_key_name, 'default'" } unless exists? :aws_key_name
          set(:aws_ssh_key)           { abort "Please specify an AWS SSH Key path, set :aws_ssh_key, 'config/aws.pem'" } unless exists? :aws_ssh_key

         namespace :aws do

            desc <<-DESC
              create an AWS instance.

                cap aws:create [OPTIONS]

              Available options:

                flavour  (required) - The type of EC2 instance to create
                name     (required) - The name of the instance, this will be used as the AWS tag
                iam_role            - An IAM role to apply to the instance
                ebs                 - Set EBS to standard or optimised (default:standard)
                az                  - Choose an availability zone

            DESC
            task :create do
              flavour = ENV['flavour'] || abort('please specify a flavour')
              name = ENV['name'] || abort('please specify name')
              iam_role = ENV['iam_role']
              iam_role = ENV['iam_role']
              ebs_optimised = ENV['ebs'] == 'optimised' || ENV['ebs'] == 'optimized'
              availability_zone = ENV['az'] || aws_availability_zone

              puts "Creating Instance..."
              instance_options = {
                :image_id          => aws_ami,
                :availability_zone => availability_zone,
                :flavor_id         => flavour,
                :key_name          => aws_key_name,
                :tags              => { 'Name' => name },
                :ebs_optimized     => ebs_optimised,
              }

              instance_options[:iam_instance_profile_name] = iam_role if iam_role

              server = servers.create instance_options
              server.wait_for { ready? }
              server.reload
              ENV['HOSTS'] = server.public_ip_address
            end


            desc <<-DESC
              List AWS Instance types.

              The pricing here is simply for reference and is the monthly spend for
              us-east-1 as of 2013-03-29.
            DESC
            task :flavours do
        #'hs1.8xlarge' => {:ram => 117,  :io => 'v.high',   :compute => 35,   :price => 4.60,  :ebs_opt => false, :disk => 48000, :other => 'disk' },
              puts '%-11s  %-9s  %-8s  %-5s  %-8s  %-8s  %-9s  %-s' % %w[Name Monthly RAM Units IO Storage EBS Other]
              Capistrano::Puppeteer::AWS::FLAVOURS.each do |flavor, opts|
                bits = [flavor, opts[:price] * 720, opts[:ram], opts[:compute], opts[:io], opts[:disk], (opts[:ebs_opt] ? "#{opts[:ebs_opt]} Mbps" : ''), opts[:other]]
                puts '%-11s  $ %7.2f  %5.1f GB  %5.1f  %8s  %5d GB  %9s  %s' % bits
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
