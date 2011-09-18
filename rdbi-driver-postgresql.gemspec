# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rdbi-driver-postgresql}
  s.version = "0.9.2"

  s.authors = ["Pistos", "Erik Hollensbe"]
  s.date = %q{2011-09-18}
  s.description = %q{PostgreSQL driver for RDBI}
  s.email = %q{rdbi@pistos.oib.com}
  s.extra_rdoc_files = [
    "LICENSE",
    "README.rdoc"
  ]
  s.files = [
    "LICENCE",
    "LICENSE",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "lib/rdbi-driver-postgresql.rb",
    "lib/rdbi/driver/postgresql.rb",
    "rdbi-driver-postgresql.gemspec",
    "test/helper.rb",
    "test/test_database.rb"
  ]
  s.homepage = %q{http://github.com/Pistos/rdbi-dbd-postgresql}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{PostgreSQL driver for RDBI}
  s.test_files = [
    "test/helper.rb",
    "test/test_database.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<test-unit>, [">= 0"])
      s.add_development_dependency(%q<rdoc>, [">= 0"])
      s.add_development_dependency(%q<rdbi-dbrc>, [">= 0"])
      s.add_runtime_dependency(%q<rdbi>, [">= 0"])
      s.add_runtime_dependency(%q<pg>, [">= 0.10.0"])
      s.add_runtime_dependency(%q<methlab>, [">= 0"])
      s.add_runtime_dependency(%q<epoxy>, [">= 0.3.1"])
    else
      s.add_dependency(%q<test-unit>, [">= 0"])
      s.add_dependency(%q<rdoc>, [">= 0"])
      s.add_dependency(%q<rdbi-dbrc>, [">= 0"])
      s.add_dependency(%q<rdbi>, [">= 0"])
      s.add_dependency(%q<pg>, [">= 0.10.0"])
      s.add_dependency(%q<methlab>, [">= 0"])
      s.add_dependency(%q<epoxy>, [">= 0.3.1"])
    end
  else
    s.add_dependency(%q<test-unit>, [">= 0"])
    s.add_dependency(%q<rdoc>, [">= 0"])
    s.add_dependency(%q<rdbi-dbrc>, [">= 0"])
    s.add_dependency(%q<rdbi>, [">= 0"])
    s.add_dependency(%q<pg>, [">= 0.10.0"])
    s.add_dependency(%q<methlab>, [">= 0"])
    s.add_dependency(%q<epoxy>, [">= 0.3.1"])
  end
end

