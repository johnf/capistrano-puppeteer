# Capistrano Puppeteer

Some useful capistrano tasks for standalone puppet masterless puppet deployments.

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
