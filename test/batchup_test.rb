require File.expand_path("../test_helper", __FILE__)
require 'rubygems'
require 'shoulda-context'

class BatchupTest < Test::Unit::TestCase
  include Batchup::TestHelper

  context "validations" do
    setup do
      pristine_dirs
    end

    context "validate_target" do

      should "return true if target dir exists" do
        assert Batchup.validate_target(target_dir)
      end

      should "create if target not exists" do
        assert_false File.exist? target_dir+"/x"
        assert Batchup.validate_target(target_dir+"/x")
        assert File.exist? target_dir+"/x"
        assert File.directory? target_dir + "/x"
      end

      should "puts mesg and return false if target can't be created" do
        out = capture {
          assert_false Batchup.validate_target("/batchup")
        }.length > 0
      end

      should "puts mesg and return false if target is a file" do
        FileUtils.touch target_dir+"/file.txt"
        out = capture {
          assert_false Batchup.validate_target(target_dir+"/file.txt")
        }
        assert out.length > 0
      end
    end

    context "validate_source" do
      should "return true if source exists, otherwise puts and return false" do
        out = capture {
          assert_false Batchup.validate_source(source_dir+"/x")
        }
        assert out.length > 0
        FileUtils.touch source_dir+"/x"
        assert Batchup.validate_source(source_dir+"/x")
      end
    end
  end # context validations


  context "say_and_do" do
    should "puts command and its output" do
      out = capture {
        Batchup.say_and_do("ruby -v")
      }
      assert out.lines.to_a[0] == "-> ruby -v\n"
      assert out.lines.to_a[1] =~ /^ruby #{RUBY_VERSION}/
    end
  end


  context "rotate" do
    setup do
      pristine_dirs
    end

    should "delete older files" do
      # Create 9 files in target dir, smallest number = oldest
      9.times do |i|
        mtime = Time.now - (10-i)*60
        FileUtils.touch("#{target_dir}/#{i}")
        File.utime(mtime, mtime, "#{target_dir}/#{i}")
      end

      # Rotate.
      out = capture {
        Batchup.rotate(target_dir, 5)
      }
      assert out.lines.to_a[0] == "Rotation: keeping 5 of 9 files.\n"
      out.lines.to_a[1...4].each do |line|
        assert line =~ /^Delete #{target_dir}/
      end

      # Make sure there's only 5 latest files
      remained = Dir[target_dir+"/*"]
      assert remained.size == 5
      (4..8).each do |i|
        assert remained.include? "#{target_dir}/#{i}"
      end
    end
  end

end
