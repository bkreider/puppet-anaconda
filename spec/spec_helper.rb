require 'rspec-puppet'

IDEAL_CONSOLE_WIDTH = 72
def horizontal_rule(width = 5)
  '=' * [width, IDEAL_CONSOLE_WIDTH].min
end

# require dependencies
gems = [
  'minitest',
  'minitest/autorun', # http://docs.seattlerb.org/minitest/
  'minitest/unit', # https://github.com/freerange/mocha#bundler
  'mocha/setup', # http://gofreerange.com/mocha/docs/Mocha/Configuration.html
  'jumanjiman_spec_helper',
  'puppet'
]
begin
  gems.each {|gem| require gem}
rescue => e
  # http://goo.gl/r3nFG
  # emphasize dependency failures in case a task spews lots of output
  warn horizontal_rule(e.message.length)
  warn e.class
  warn e.message
  warn horizontal_rule(e.message.length)
  exit(1)
end

fixture_path = File.expand_path(File.join(__FILE__, '..', 'fixtures'))

RSpec.configure do |c|
  # https://github.com/jumanjiman/jumanjiman_spec_helper#shared-contexts
  c.include JumanjimanSpecHelper::EnvironmentContext

  # https://www.relishapp.com/rspec/rspec-core/v/2-12/docs/mock-framework-integration/mock-with-mocha!
  c.mock_framework = :mocha

  # see output for all failures
  c.fail_fast = false

  c.module_path = File.join(fixture_path, 'modules')
  c.manifest_dir = File.join(fixture_path, 'manifests')
end
