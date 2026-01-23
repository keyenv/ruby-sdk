# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc "Run tests"
task test: :spec

desc "Generate documentation"
task :yard do
  sh "yard doc lib/**/*.rb"
end

desc "Open documentation"
task docs: :yard do
  sh "open doc/index.html"
end
