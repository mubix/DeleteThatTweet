#!/usr/bin/env ruby

require 'twitter'
require 'sqlite3'
require 'pry'
require 'base64'

@client = Twitter::REST::Client.new do |config|
  config.consumer_key        = ""
  config.consumer_secret     = ""
  config.access_token        = ""
  config.access_token_secret = ""
end

@botdb = SQLite3::Database.new('bot.db')
@botdb.execute <<SQL

CREATE TABLE IF NOT EXISTS tweets (
        key INTEGER PRIMARY KEY,
        id INTEGER UNIQUE
        );
SQL

def get_unique_list
	idarr = []
	dbarr = []
	done = @botdb.execute('SELECT id from tweets')
	done.each do |d|
		dbarr << d[0].to_s
	end
	textfiles = Dir.entries('text')
	textfiles.shift
	textfiles.shift
	textfiles.each do |x|
		idarr << x.split('.')[0]
	end
	idarr.delete_if { |a| dbarr.include? a }
	return idarr
end

def send_tweet(id)
	deleted = []
	if File.exists? "text/#{id}.txt"
		textfile = File.open("text/#{id}.txt", 'r')
		textfile.each_line do |line|
			deleted << line.strip
		end
		user = deleted.find { |e| /https\:\/\/twitter\.com\// =~ e}
		user = user.split('//')[1].split('/')[1]
		if File.exists? "imgs/deleted/#{id}.png"
			puts "Deleted tweet/RT \##{id} by #{user}"
			@client.update_with_media("Deleted tweet/retweet by #{Base64.encode64(user)}: \##{id}", File.open("imgs/deleted/#{id}.png", 'r'))
			dbstatus = @botdb.execute("INSERT INTO tweets (id) VALUES (?)", [id])
		end
	end
end

while true
	left = get_unique_list
	left.each do |id|
		send_tweet(id)
	end
	puts "Sleeping..."
	sleep(30)
end
