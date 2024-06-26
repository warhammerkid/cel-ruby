# frozen_string_literal: true

require_relative "lib/cel/version"

Gem::Specification.new do |spec|
  spec.name = "cel"
  spec.version = Cel::Ruby::VERSION
  spec.platform = Gem::Platform::RUBY
  spec.authors = ["Tiago Cardoso"]
  spec.email = ["cardoso_tiago@hotmail.com"]

  spec.summary = "Pure Ruby implementation of Google Common Expression Language, https://opensource.google/projects/cel."
  spec.description = spec.summary

  spec.license = "Apache 2.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata = {
    "bug_tracker_uri" => "https://gitlab.com/os85/cel-ruby/issues",
    "changelog_uri" => "https://gitlab.com/os85/cel-ruby/-/blob/master/CHANGELOG.md",
    # "documentation_uri" => "https://os85.gitlab.io/cel-ruby/rdoc/",
    "source_code_uri" => "https://gitlab.com/os85/cel-ruby",
    "homepage_uri" => "https://gitlab.com/os85/cel-ruby",
    "rubygems_mfa_required" => "true",
  }
  spec.required_ruby_version = ">= 2.6"

  spec.files = Dir["LICENSE.txt", "CHANGELOG.md", "README.md", "lib/**/*.rb", "sig/**/*.rbs"]
  spec.extra_rdoc_files = Dir["LICENSE.txt", "CHANGELOG.md", "README.md"]

  spec.require_paths = ["lib"]

  spec.add_dependency "bigdecimal"

  spec.add_development_dependency "minitest"
  spec.add_development_dependency "tzinfo"
end
