#!/usr/bin/env ruby
# monitor internet status and log to google drive

require 'yaml'
require 'google_drive'
require 'net/ping'
require 'active_support/all'
require 'logger'
require 'fileutils'
require 'readline'

Signal.trap("INT")  { shutdown }
Signal.trap("TERM") { shutdown }
Signal.trap("HUP")  { @config = nil }

def shutdown
  throw :shutdown
end

def server_path(file)
  path = __FILE__
  path = File.readlink(path) if File.symlink?(path)
  path = File.dirname(path)
  path = File.join(path, file) if file
  path
end

def config
  @config ||= begin
    YAML.load_file(server_path("config/application.yml"))
  end
end

def session
  @session ||= begin
    drive_config_file = server_path("config/drive.json")
    GoogleDrive::Session.from_config(drive_config_file)
  end
end

def logger
  @logger ||= begin
    log_path = server_path("log/internet_monitor.log")
    log_dir = File.dirname(log_path)
    Dir.mkdir(log_dir) unless Dir.exist?(log_dir)
    logger = Logger.new(log_path, 5, 1024000)
    logger.level = Logger::INFO
    logger
  end
end

def worksheet
  @worksheet ||= begin
    key = config["spreadsheet_key"]
    raise "spreadsheet key required" unless key
    ws = session.spreadsheet_by_key(key).worksheets[0]
  end
end

def connected?
  @ping ||= begin
    host = config["ping_host"]
    raise "ping_host required" unless host
    Net::Ping::External.new(host)
  end

  @ping.ping?
  # try to ping three times
  ping_count = config["ping_count"] || 5
  ping_count.times do
    return true if @ping.ping?
  end

  # internet disconnected if ping failed three times
  false
end

# return number of disconnections and disconnected time since given date.
# if date is not given, over all time
def find_disconnections(since = nil)
  ws = worksheet
  row = ws.num_rows
  count = 0
  total_time = 0

  loop do
    date, time = ws[row, 1], ws[row, 2]
    date = Time.parse(date) rescue nil

    break if date.nil? || date < since
    count += 1
    total_time += time.to_i
    row -= 1
  end

  [count, total_time]
end

# update disconnections statistics in spreadsheet
def update_dc_statistics(column, since)
  ws = worksheet
  dc = find_disconnections(since)
  ws[2, column] = dc[1]  # disconnected time
  ws[3, column] = dc[0]  # number of disconnections
  ws.save
end

def update_statistics
  update_dc_statistics(2, Time.now.beginning_of_day)   # today
  update_dc_statistics(3, Time.now.beginning_of_week)  # this week
end

def update_status(status)
  return if status == @status

  logger.info("internet status changed to #{status}")

  case status
  when :connected
    # save disconnection to spreadsheet
    if @dc_time
      disconnected_time = (Time.now - @dc_time).to_i
      ws = worksheet
      row = ws.num_rows + 1
      ws[row, 1] = @dc_time
      ws[row, 2] = disconnected_time
    end
    update_statistics

  when :disconnected
    # disconnected, save disconnection time
    @dc_time = Time.now
  end

  @status = status
end

def run
  fail_count = 0
  status = nil

  loop do
    sleep(config["ping_delay"] || 5)

    if connected?
      fail_count = 0
      status = :connected
    else
      ping_count = config["ping_count"] || 3
      fail_count += 1
      status = :disconnected if fail_count > ping_count
    end
    update_status(status)
  end
end

def show_status
  puts "number of rows: #{worksheet.num_rows}"
  count, time = find_disconnections(Time.now.beginning_of_day)
  puts "disconnections for today: #{count}, #{time} seconds"
end

def setup
  # create application.yml
  app_config_file = server_path("config/application.yml")
  unless File.exist?(app_config_file)
    example_config_file = server_path("config/application.example.yml")
    FileUtils.copy_file(example_config_file, app_config_file)
    puts "Created #{app_config_file}"
  end

  # log in to google drive
  # this prompts for google drive session key if it's not set
  session

  # check spreadsheet
  begin
    worksheet
    puts "Spreadsheet found."
  rescue Exception => e
    puts "\nGoogle Drive spreadsheet not found"
    response = Readline.readline("Create spreadsheet (Y/N)? ")
    if response == "Y" || response == "y"
      puts "Creating spreadsheet"
      csv_file = server_path("config/initial.csv")
      sheet = session.upload_from_file(csv_file, "Internet Monitor")
      puts "Add this spreadsheet key to config/application.yml"
      puts "spreadsheet_key: #{sheet.key}"
    end
  end
end

begin
  if ARGV[0] == "setup"
    # show status / login if required
    setup
  elsif ARGV[0] == "test"
    # test connection
    show_status
  else
    begin
      logger.info("Monitor script started")
      catch(:shutdown) { run }
    rescue Exception => e
      logger.error("error: #{e.message}")
      logger.error("#{e.backtrace.join("\n")}") if ENV["DEBUG"]
    end
    logger.info("Monitor script stopping")
  end
end
