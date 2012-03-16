# coding: utf-8
# 
# A small script that backs up bunches of files or directories.
#
# This script can:
# * Use tar or rsync or cp to copy files/dirs to another place
# * Back up multiple things to different destinations
# * Run any command before and after backup (like mysqldump)
# * Rotate backup files
#
# This script cannot:
# * Handle remote destinations well
# * Run any arbitrary command instead of tar/rsync/cp
# * Log to a file (it just prints to stdout, redirect it if you want)
# * Eat a goat
#
# Usage:
# Create another script like this:
#
#   require 'batchup'
#   settings = {
#     'personal_redmine' => {
#       :command => :tar,
#       :source => "/home/marco/sites/redmine",
#       :target => "/mnt/hgfs/naboo/dumps/oredmine",
#     }
#   }
#   Batchup.run(settings)
#
# And run it with cron or Jenkins or whatever.
# Backup files will look like /path/to/target/sourcename.2012-03-16.0300
#
# Settings details:
# Setting name
#   This is just a name that's printed out.
# :command
#   Choose one of
#     :tar (tar czf destination.tgz source)
#     :rsync (rsync -a source destination)
#     :cp (cp -rf source destination)
#     lambda { |source, destination| ... }
#   Anything else (including nil) will result in a no-op.
# :source (required)
#   Your thing to back up. File or directory.
# :target (required)
#   Where to backup to. Directory.
# :rotate
#   Number of backups to keep in target directory.
#   Older ones will be deleted.
# :precommand
#   A command to run before backing up (String or Proc).
#   Things like mysqldump into a temp directory.
#   You would then specify the source as that dump file.
# :postcommand
#   A command to run after backup is done (String or Proc).
#   Maybe you would want to delete that dump file?
# :conditions
#   A Proc that must evaluate to true for the backup to run.
#
#
# Example settings:
#   Run mysqldump first, use it to backup to another disk,
#   then delete the dump file. Only run on tuesdays.
#   Keep the latest 10 backups and discard the rest.
#   "blog_db" => {
#     :rotate => 10,
#     :command => :cp,
#     :precommand => "mysqldump -h localhost -u root blog -r /home/marco/dumps/blog.sql",
#     :postcommand => "trash /home/marco/dumps/blog.sql",
#     :source => "/home/marco/dumps/blog.sql",
#     :target_dir => "/mnt/hgfs/naboo/backups/blog_db",
#     :conditions => lambda { Time.now.wday==2 },
#   },
#
#
##############################################################

require 'date'
require 'fileutils'
require 'open3'

module Batchup
  extend self

  def run(settings)
    settings.each do |name, entry|
      work_on_entry(name, entry)
    end
  end

  # Process a single settings entry
  def work_on_entry(name, entry)
    puts "================================================================================"
    puts "Backing up #{name}..."

    if entry[:conditions] && !entry[:conditions].call
      puts "Skipping (conditions not met)"
      return
    end
    say_and_do(entry[:precommand]) if entry[:precommand]

    unless validate_target(entry[:target])
      puts "Aborting."
      return
    end
    unless validate_source(entry[:source])
      puts "Aborting."
      return 
    end
    target_file = File.join(entry[:target], File.basename(entry[:source]) + "." + timestamp)

    do_command(entry[:command], entry[:source], target_file)
    say_and_do(entry[:postcommand]) if entry[:postcommand]
    rotate(entry[:target], entry[:rotate]) if entry[:rotate]

    say_and_do("ls -alh #{entry[:target]}")
    puts "Done with #{name}."

    puts ""
  rescue Exception => e
    puts "Error while backing up #{name}:"
    puts e
    puts e.backtrace.join("\n")
    puts "Aborting."
  end


  # Make sure target directory exists or can be created
  def validate_target(target)
    unless File.exist? target
      begin
        FileUtils.mkdir_p target
      rescue Exception => e
        puts "Could not create directory #{target}."
        puts e.to_s
        return false
      end
    end
    unless File.directory? target
      puts "Target #{target} is not a directory."
      return false
    end
    true
  end

  # Make sure source exists
  def validate_source(source)
    unless File.exist? source
      puts "Source #{source} doesn't exist."
      return false
    end
    true
  end

  # Perform one of the main backup commands.
  def do_command(command, source, target_file)
    case command
    when Proc
      command.call
    when :tar
      say_and_do("tar czpf \"#{target_file}.tgz\" \"#{source}\"")
    when :rsync
      say_and_do("rsync -a \"#{source}\" \"#{target_file}\"")
    when :cp
      say_and_do("cp -rf \"#{source}\" \"#{target_file}\"")
    end
  end

  # Remove old entries from a directory, keeping specified number
  def rotate(target, number)
    # Sort files in target dir from latest to oldest
    files = Dir[File.join(target, "*")].sort { |a, b| File.mtime(a) <=> File.mtime(b) }.reverse
    to_keep = files[0...number]
    puts "Rotation: keeping #{to_keep.size} of #{files.size} files."
    (files - to_keep).each do |path|
      puts "Delete #{path}"
      FileUtils.rm_r(path)
    end
  end

  # Returns a current timestamp for use in filenames
  def timestamp
    d = DateTime.now
    sprintf("%04d-%02d-%02d.%02d%02d", d.year, d.month, d.day, d.hour, d.min)
  end

  # Outputs a command string and run it too.
  def say_and_do(cmd)
    puts "-> #{cmd}"
    result = ""
    Open3.popen3(cmd) { |stdin, stdout, stderr|
      stdout_fin = false
      stderr_fin = false
      while true
        readable = IO.select([stdout, stderr])[0]
        readable.each do |io|
          begin
            buf = io.read_nonblock(256)
            print buf if buf.length > 0
          rescue EOFError
            stdout_fin = true if io == stdout
            stderr_fin = true if io == stderr
          end
        end
        break if stdout_fin && stderr_fin
      end
    }
  end
end
