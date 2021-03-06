# internet_monitor
Monitor the status of the internet connection and record disconnections
to a Google Drive spreadsheet.

## Requirements
- An internet connection.
- Ruby

## Setup and Configuration
Install required gems

    gem install bundler
    bundle install

Run the script in setup mode. This will create an initial config/application.yml
file, set up the connection to Google Drive and create a spreadsheet to store
a log of disconnections.

    ./internet_monitor.rb setup

Update config/application.yml as required. For example, ping_host should be
updated to point to your ISP.  You will also need to update spreadsheet_key
to point to the spreadsheet created in Google Drive by the setup process.

## Running the script
You can run the script as a daemon using internet_monitor_control.rb, e.g.

    ./internet_monitor_control.rb start

See the daemons ruby gem for more information.
The script can also be run directly in the foreground to debug problems.
A log file is kept at log/internet_monitor.log

    ./internet_monitor.rb

## Running the script on server startup

The internet_monitor_control.rb script uses the daemons ruby gem, and can be
used as an init.d script, e.g.

    cd /etc/init.d
    ln -s path/to/project/internet_monitor_control.rb internet_monitor
    /etc/init.d/internet_monitor start
