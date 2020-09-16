$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "blacklight_alma/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "blacklight_alma"
  s.version     = BlacklightAlma::VERSION
  s.authors     = ["Jeff Chiu"]
  s.email       = ["jeffchiu@upenn.edu"]
  s.homepage    = "https://github.com/upenn-libraries/blacklight_alma"
  s.summary     = "Blacklight integration with Alma"
  s.description = "Blacklight integration with Alma"
  s.license     = "Apache 2.0"

  s.files = Dir["{app,config,db,lib}/**/*", "LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", ">= 5.2", "< 6"
  s.add_dependency "blacklight", "~> 7.0"
  # there is no way to point to a git repo in a gemspec,
  # so the app's Gemfile will need to include ezwadl as well.
  s.add_dependency 'ezwadl', '0.0.1'
  s.add_dependency 'jwt', '1.5.6'

  s.add_development_dependency "engine_cart", "1.0.1"
end
