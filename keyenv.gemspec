# frozen_string_literal: true

require_relative "lib/keyenv/version"

Gem::Specification.new do |spec|
  spec.name = "keyenv"
  spec.version = KeyEnv::VERSION
  spec.authors = ["KeyEnv"]
  spec.email = ["support@keyenv.dev"]

  spec.summary = "Official Ruby SDK for KeyEnv - Secure secrets management"
  spec.description = "KeyEnv Ruby SDK provides a simple interface for managing secrets in your Ruby applications. Fetch, create, and manage environment variables securely."
  spec.homepage = "https://keyenv.dev"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/keyenv/ruby-sdk"
  spec.metadata["changelog_uri"] = "https://github.com/keyenv/ruby-sdk/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://keyenv.dev/docs/sdks/ruby"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem
  spec.files = Dir.chdir(__dir__) do
    Dir["{lib}/**/*", "LICENSE", "README.md", "CHANGELOG.md"].reject { |f| File.directory?(f) }
  end
  spec.require_paths = ["lib"]

  # Runtime dependencies - using only stdlib (net/http, json, uri)
  # No external runtime dependencies needed!

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "webmock", "~> 3.19"
  spec.add_development_dependency "rubocop", "~> 1.57"
  spec.add_development_dependency "rubocop-rspec", "~> 2.25"
  spec.add_development_dependency "yard", "~> 0.9"
end
