# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rdbi-driver-postgresql}
  s.version = "0.9.1"

  s.date = %q{2011-09-18}
  s.authors = ["Pistos", "Erik Hollensbe"]
  s.email = %q{rdbi@pistos.oib.com}
  s.homepage = %q{https://github.com/RDBI/rdbi-driver-postgresql}
  s.summary = %q{PostgreSQL driver for RDBI}
  s.description = %q{PostgreSQL driver for RDBI}

  s.require_paths = ["lib"]

  s.files = `git ls-files`.split("\n")

  s.test_files = [
    "test/helper.rb",
    "test/test_database.rb"
  ]

  s.add_development_dependency(%q<test-unit>, [">= 0"])
  s.add_development_dependency(%q<rdoc>, [">= 0"])
  s.add_development_dependency(%q<rdbi-dbrc>, [">= 0"])

  s.add_runtime_dependency(%q<rdbi>, [">= 0"])
  s.add_runtime_dependency(%q<pg>, [">= 0.10.0"])
  s.add_runtime_dependency(%q<methlab>, [">= 0"])
  s.add_runtime_dependency(%q<epoxy>, [">= 0.3.1"])
end

