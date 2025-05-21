# frozen_string_literal: true

require 'bundler/setup'

require 'minitest/autorun'
require 'minitest/mock'
require 'xmlsimple'
require 'json'
require 'pathname'

$LOAD_PATH << File.expand_path('../lib', __dir__)
require 'sablon'
require 'sablon/test'

module Sablon
  class TestCase < Minitest::Test
    def teardown
      super
      Sablon::Numbering.instance.reset!
    end
  end
end
