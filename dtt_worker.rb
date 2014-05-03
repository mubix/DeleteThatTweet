#!/usr/bin/env ruby

require 'backburner'
require 'screencap'
require 'twitter'

Backburner.configure do |config|
  config.beanstalk_url    = ["beanstalk://127.0.0.1"]
  config.tube_namespace   = "deltweetarchver"
  config.on_error         = lambda { |e| puts e }
  config.max_job_retries  = 3 # default 0 retries
  config.retry_delay      = 2 # default 5 seconds
  config.default_priority = 65536
  config.respond_timeout  = 120
  config.default_worker   = Backburner::Workers::Simple
  config.logger           = Logger.new(STDOUT)
  config.primary_queue    = "deltweetjobs"
  config.priority_labels  = { :custom => 50, :useless => 1000 }
end

class ScreenshotJob
  # required
  def self.perform(id, url)
    if File.exists?("imgs/#{id}.png")
		puts "Screenshot already exists, skipping"
		return
	else
		f = Screencap::Fetcher.new(url)
		screenshot = f.fetch(:output => "imgs/#{id}.png")
	end
  end

  # optional, defaults to 'backburner-jobs' tube
  def self.queue
    "deltweetjobs"
  end

  # optional, defaults to default_priority
  def self.queue_priority
    1000 # most urgent priority is 0
  end

  # optional, defaults to respond_timeout
  def self.queue_respond_timeout
    300 # number of seconds before job times out
  end
end

Backburner.work
