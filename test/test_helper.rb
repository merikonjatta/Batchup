require File.expand_path('../../batchup', __FILE__)
require 'fileutils'
require 'stringio'

module Batchup
  module TestHelper
    def assert_false(expr)
      assert !expr
    end

    def source_dir
      File.expand_path("../source", __FILE__)
    end

    def target_dir
      File.expand_path("../target", __FILE__)
    end

    def pristine_dirs
      pristine_source_dir
      pristine_target_dir
    end

    def pristine_source_dir
      Dir[source_dir+"/*"].each { |entry| FileUtils.rm_rf(entry) }
      FileUtils.mkdir(source_dir+"/one")
      File.open(source_dir+"/one/a.txt", "w+") { |f| f.write("file one/a") }
      File.open(source_dir+"/one/b.txt", "w+") { |f| f.write("file one/b") }
      File.open(source_dir+"/one/c.txt", "w+") { |f| f.write("file one/c") }
      File.open(source_dir+"/two.txt", "w+") { |f| f.write("file two") }
    end

    def pristine_target_dir
      Dir[target_dir+"/*"].each { |entry| FileUtils.rm_rf(entry) }
    end

    def capture(&block)
      out = StringIO.new
      $stdout = out
      block.call
    ensure
      $stdout = STDOUT
      return out.string
    end
  end
end
