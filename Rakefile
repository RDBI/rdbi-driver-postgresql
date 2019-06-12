# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :git
Hoe.plugin :rcov
Hoe.plugin :roodi
Hoe.plugin :reek

spec = Hoe.spec 'rdbi-driver-postgresql' do
  developer 'Pistos', 'pistos@purepistos.net'
  developer 'Erik Hollensbe', 'erik@hollensbe.org'

  self.description = <<-EOF
  This is the PostgreSQL driver for RDBI.

  RDBI is a database interface built out of small parts. A micro framework for
  databases, RDBI works with and extends libraries like 'typelib' and 'epoxy'
  to provide type conversion and binding facilities. Via a driver/adapter
  system it provides database access. RDBI itself provides pooling and other
  enhanced database features.
  EOF

  self.summary = 'PostgreSQL driver for RDBI';
  self.urls = {
    'github' => 'https://github.com/rdbi/rdbi-driver-postgresql'
  }

  require_ruby_version '>= 1.8.7'

  extra_dev_deps << ['hoe-roodi']
  extra_dev_deps << ['hoe-reek']
  extra_dev_deps << ['minitest']

  extra_deps << ['rdbi']
  extra_deps << ['pg', '>= 0.10.0']

  desc 'install a gem without sudo'
end

task :install => [:gem] do
  sh 'gem install pkg/#{spec.name}-#{spec.version}.gem'
end
# vim: syntax=ruby
