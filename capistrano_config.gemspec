# -*- encoding: utf-8 -*-

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "capistrano_config/version"
require "gem_helper/gem_utils"

Gem::Specification.new do |gem|
  utils = GemUtils.new(gem: gem)
  gem.name          = "capistrano_config"
  gem.version       = CapistranoConfig::VERSION
  gem.authors       = ["Tom Clements", "Lee Hambley", "John Pelly"]
  gem.email         = [ "jpelly@gmail.com"]
  gem.description   = "Extracted the configuration logic from Capistrano"
  gem.summary       = "Capistrano config gooies"
  gem.homepage      = "https://github.com/pelly/capistrano_config"
  gem.metadata      = {
    "source_code_uri" => "https://github.com/pelly/capistrano_config",
  }
  gem.files         = utils.gem_files_with_standard_exclusions.reject { |f| f =~ /^docs/ }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.licenses      = ["MIT"]

  gem.required_ruby_version = ">= 2.0"
  gem.add_dependency "i18n"
  gem.add_dependency "sshkit", ">= 1.9.0"
end
