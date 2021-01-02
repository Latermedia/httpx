# frozen_string_literal: true

require "bundler/gem_tasks"
require "rdoc/task"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs = %w[lib test]
  t.pattern = "test/**/*_test.rb"
  t.warning = false
end

desc "integration tests for third party modules"
Rake::TestTask.new(:integrations) do |t|
  t.libs = %w[lib test]
  t.pattern = "integrations/**/*_test.rb"
  t.warning = false
end

RUBY_MAJOR_MINOR = RUBY_VERSION.split(/\./).first(2).join(".")

begin
  require "rubocop/rake_task"
  desc "Run rubocop"
  RuboCop::RakeTask.new(:rubocop) do |task|
    task.options += %W[-c.rubocop-#{RUBY_MAJOR_MINOR}.yml --parallel]
  end
rescue LoadError
end

namespace :coverage do
  desc "Aggregates coverage reports"
  task :report do
    return unless ENV.key?("CI")

    require "simplecov"

    SimpleCov.collate Dir["coverage/**/.resultset.json"]
  end
end

task :"test:ci" => (RUBY_ENGINE == "ruby" ? %i[test rubocop] : %i[test])

# Doc

rdoc_opts = ["--line-numbers", "--title", "HTTPX: An HTTP client library for ruby"]

begin
  gem "hanna-nouveau"
  rdoc_opts.concat(["-f", "hanna"])
rescue Gem::LoadError
end

rdoc_opts.concat(["--main", "README.md"])
RDOC_FILES = %w[README.md lib/**/*.rb] + Dir["doc/*.rdoc"] + Dir["doc/release_notes/*.md"]

RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.options += rdoc_opts
  rdoc.rdoc_files.add RDOC_FILES
end

desc "Builds Homepage"
task :prepare_website => ["rdoc"] do
  require "fileutils"
  FileUtils.rm_rf("wiki")
  system("git clone https://gitlab.com/honeyryderchuck/httpx.wiki.git wiki")
  Dir.glob("wiki/*.md") do |path|
    data = File.read(path)
    name = File.basename(path, ".md")
    title = name == "home" ? "Wiki" : name.split("-").map(&:capitalize).join(" ")
    layout = name == "home" ? "page" : "wiki"

    header = "---\n" \
             "layout: #{layout}\n" \
             "title: #{title}\n" \
             "---\n\n"
    File.write(path, header + data)
  end
end
