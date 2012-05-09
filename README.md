# Basecamp Next to Codebase Importer

This script will import your discussions from Basecamp Next to Codebase.

## Requirements

This importer relies on the new Basecamp API, documented here: 
https://github.com/37signals/bcx-api. Therefore, this importer will only work
with a Basecamp Next account. 

Tested on Ruby 1.9.2p290. Requires JSON and Hpricot gems. To install run:

    gem install json
    gem install hpricot

## Usage

You should have all users involved in your discussions created in Codebase 
prior to running this script. The importer will attempt to make a match between
users based upon their primary email addresses. If no match is found for that
user, the name will still be copied correctly, but there will be no link to
that user, and entries will show up as "Unknown Entity" in your Codebase
activity feed.

Edit the script and enter your Basecamp and Codebase credentials in the 
appropriate constants.

Execute bcx_importer.rb:

    ruby -rubygems bcx_importer.rb

## Improvements

Please feel free to improve this script to include new functionality (such as
converting Basecamp todos to Codebase tickets) or bugfixes. Just submit a pull
request when you're done.