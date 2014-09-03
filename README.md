Delete That Tweet
====================

Monitors a Twitter stream and saves off any tweet that is deleted.

This repo has both the cloner (deletethattweet.rb) and a twitter bot (ideletedthat.rb).
Both require an Twitter app be created and auth tokens be generated.
The twitter bot is the only one that requires `read/write` privs.

~~ Clean up happens everywhere but the deleted tweets. (text and images/deleted) ~~
~~ The images can get to 1 MB or more so depending on your followers this could  ~~
~~ fill up your hard driver quite quickly. ~~

## Dependencies

### Beanstalk Install

```
sudo apt-get install beanstalkd libsqlite3-dev build-essential
```
You then need to edit the `/etc/default/beanstalkd` config file. Uncomment `#START=yes` and I would recommend only listening locally on `127.0.0.1`

### Gems

```
gem install twitter sqlite3 backburner screencap --no-rdoc --no-ri
```

### Known Issues

On Kali Linux there is an issue where the screencap gem can't identify the platform, a fix will be posted here in the next few days.

## DeleteThatTweet.rb

### Configure

Under the `#Twitter Config` comment you need to supply ckey, csec, akey, and asec.

### Run

Should be as simple as: `ruby deletethattweet.rb`, make sure you have a few workers to handle the screenshots.

## dtt_worker.rb

### Configure

Only thing should need configuring is the beanstalk config if it's changed.

### Run

Just `ruby dtt_worker.rb &` to toss it into the background. I would suggest running a few.

## IDeletedThat.rb

### Configure and Run

Same with DeleteThatTweet, you need to configure the Twitter API variables but that should be about it. `ruby ideletedthat.rb`

