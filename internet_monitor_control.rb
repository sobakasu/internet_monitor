#!/usr/bin/env ruby
#
### BEGIN INIT INFO
# Provides:       internet_monitor
# Required-Start: $local_fs
# Required-Stop:
# Default-Start:  2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Internet status monitor
# Description: monitor internet status and log to google drive
### END INIT INFO

require 'rubygems'
require 'daemons'

file = __FILE__
file = File.readlink(file) if File.symlink?(file)
path = File.join(File.dirname(file), 'internet_monitor.rb')

options = {
  backtrace: true,
  log_output: true,
  monitor: true,
  dir_mode: :system
}
Daemons.run(path, options)
