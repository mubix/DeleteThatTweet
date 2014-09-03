#!/usr/bin/env ruby

require 'twitter'
require 'sqlite3'
require 'screencap'
require 'backburner'
require 'fileutils'

# Database Config

@checkdb = SQLite3::Database.new('check.db')
@checkdb.execute <<SQL

CREATE TABLE IF NOT EXISTS tweets (
	key INTEGER PRIMARY KEY,
	id INTEGER UNIQUE,
	text VARCHAR(255),
	author VARCHAR(255),
	url VARCHAR(255),
	timestamp VARCHAR(255)
	);
SQL

# Queue Manager Config

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

# Twitter Config

ckey = ""
csec = ""
akey = ""
asec = ""

@client = Twitter::REST::Client.new do |config|
  config.consumer_key        = ckey
  config.consumer_secret     = csec
  config.access_token        = akey
  config.access_token_secret = asec
end

@stream = Twitter::Streaming::Client.new do |config|
  config.consumer_key        = ckey
  config.consumer_secret     = csec
  config.access_token        = akey
  config.access_token_secret = asec
end


# File System Config

# Make images directory if not existant
Dir.exists?('imgs') ? nil : FileUtils.mkdir('imgs')
Dir.exists?('imgs/deleted') ? nil : FileUtils.mkdir('imgs/deleted')
Dir.exists?('text') ? nil : FileUtils.mkdir('text')

class ScreenshotJob
  # required
  def self.perform(id, url)
    if File.exists?("imgs/#{id}")
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

def store_deltweet(id)
	tweet = @checkdb.execute("SELECT * from tweets WHERE id = #{id}")[0]
	doc = tweet.join("\n")
	File.open("text/#{id}.txt", 'w') {|f| f.write(doc)}
	@checkdb.execute("DELETE from tweets WHERE id = #{id}")
	FileUtils.cp("imgs/#{id}.png","imgs/deleted/#{id}.png")
	File.delete("imgs/#{id}.png") if File.exist?("imgs/#{id}.png")
end

def delete_storage(id)
	@checkdb.execute("DELETE from tweets WHERE id = #{id}")
	File.delete("imgs/#{id}.png") if File.exist?("imgs/#{id}.png")
end

def check_tweet(id)
	ratehit = 0
	begin
		@client.status(id)
	rescue Twitter::Error::TooManyRequests
		print "R"
		ratehit = 1
	rescue Twitter::Error::NotFound
		print 'D'
		store_deltweet(id)
	rescue => error
		puts "Error Happened"
		puts "Error #{error.inspect}"
	end
	return ratehit
end

def check_db
	current = @checkdb.execute("SELECT * from tweets")
	print current.count
	current.each do |item|
		if (Time.now - Time.parse(item[5]) > 3600)
			print 'V'
			ratehit = check_tweet(item[1])
			if ratehit == 1
				return
			end
			delete_storage(item[1])
		end
	end
end

## MAIN ##

# Twitter Config
puts "Deleted Tweets Archiver v0.2"
puts "Key:"
puts "\t '.' = Tweet recieved"
puts "\t '!' = Screenshot taken"
puts "\t '_' = Checking old tweet"
puts "\t 'D' = Deleted tweet found!"
puts "\t 'X' = Couldn't take screenshot, user is protected"
puts "\t 'V' = Discontinued tracking hour old tweet"
puts "\t 'T' = Talking to Twitter timed out"
puts "\t 'R' = Rate limit hit"


@stream.user do |object|
	case object
	when Twitter::Tweet
		tweet = object
		dbstatus = @checkdb.execute("INSERT INTO tweets (id, author, text, url, timestamp)
			VALUES (?, ?, ?, ?, ?)",
				[
					tweet.id,
					tweet.user.screen_name,
					tweet.full_text,
					tweet.uri.to_s,
					Time.now.to_s
				]
			)
		if tweet.user.protected?
			print "X"
		else
			#screenshot_tweet(tweet.id, tweet.uri.to_s)
			print "!"
			Backburner.enqueue ScreenshotJob, tweet.id, tweet.uri.to_s
		end
		print "."
	end
	check_db
end
