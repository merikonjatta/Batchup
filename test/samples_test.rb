require File.expand_path("../test_helper", __FILE__)
require 'rubygems'
require 'shoulda-context'

class BatchupSamplesTest < Test::Unit::TestCase
  include Batchup::TestHelper

  context "samples" do
    setup do
      pristine_source_dir
    end

    should "tar" do
      settings = {
        "tar sample" => {
          :command => :tar,
          :source  => source_dir,
          :target  => target_dir,
        }
      }
      Batchup.run(settings)
    end
  end
end
