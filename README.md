# Capistrano Puppeteer

Some useful capistrano tasks for standalone puppet masterless puppet deployments.

# Usage

## Launching Amazon Instances

Populate ```config/deploy.rb``` with the following attributes

``` ruby
require 'capistrano/puppeteer/aws'

set :cloud_provider, 'AWS'
set :aws_secret_access_key, 'X...'
set :aws_access_key_id,     'A...'
set :aws_region,            'us-west-2'
set :aws_availability_zone, 'us-west-2a'
set :aws_ami,               'ami-20800c10' # Precise 64bit http://cloud.ubuntu.com/ami/
set :aws_key_name,          'default'
set :aws_iam_role,          'backups' # Optional
```

## Bootstrapping an instance

Populate ```config/deploy.rb``` with the following attributes

``` ruby
set :bootstrap_domain, 'example.com'
set :bootstrap_user,   'johnf'
set :ssh_key,          'config/aws.pem'
set :puppet_repo,      'git@github.com:johnf/puppet.git'
```

# Installation

Add this line to your application's Gemfile:

``` ruby
gem 'capistrano-puppeteer'
```

And then execute:

``` bash
$ bundle
```

Or install it yourself as:

``` bash
$ gem install capistrano-puppeteer
```

Then add it to your _config/deploy.rb_

``` ruby
require 'capistrano/puppeteer'
```

# Configuration

Your puppet.conf requires at minimum

``` ini
[main]
  confdir = .
```

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
