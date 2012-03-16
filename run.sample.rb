# This is a sample run script for Batchup.
$: << File.dirname(__FILE__)
require "batchup"

settings = {
  "svn_myrepo" => {
    :rotate => 10,
    :command => :rsync,
    :precommand => "svnadmin dump /home/marco/svn/repos/myrepo > /home/marco/dumps/svn_myrepo 2>/dev/null",
    :postcommand => "trash /home/marco/dumps/svn_myrepo",
    :source => "/home/marco/dumps/svn_myrepo",
    :target => "/mnt/hgfs/naboo/Dumps/svn/myrepo",
    :conditions => lambda { Time.now.wday == 2 },
  },
  "redmine" => {
    :rotate => 10,
    :command => :tar,
    :source => "/home/marco/sites/redmine",
    :target => "/mnt/hgfs/naboo/Dumps/redmine",
  }
}

Batchup.run(settings)
