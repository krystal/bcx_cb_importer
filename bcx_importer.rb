#!/usr/local/env ruby

## Imports Basecamp Discussions into Codebase Discussions

require 'json'
require 'net/http'

BASECAMP_ACCOUNT  = '' ## Basecamp account number
BASECAMP_USERNAME = '' ## Basecamp username
BASECAMP_PASSWORD = '' ## Basecamp password

CODEBASE_USERNAME = '' ## Codebase API username from profile page
CODEBASE_API_KEY  = '' ## Codebase API key from profile page

def run_import
	if [BASECAMP_ACCOUNT, BASECAMP_USERNAME, BASECAMP_PASSWORD, CODEBASE_USERNAME, CODEBASE_API_KEY].any? { |c| c.empty? }
		puts "Please edit the script to include your Codebase and Basecamp credentials"
		exit 1
	end

	## Build a user mapping BASECAMP_ID => CODEBASE_ID
	codebase_users = codebase_request('/users')
	basecamp_users = basecamp_request('/people.json')
	user_map = basecamp_users.inject(Hash.new) do |memo, basecamp_user| 
		# Find a user in Codebase with the same email address
		codebase_user = codebase_users.select {|user| user["user"]["email_address"] == basecamp_user["email_address"] }.first
		memo[basecamp_user["id"]] = codebase_user["user"]["id"] if codebase_user
		memo
	end

	basecamp_projects = basecamp_request('/projects.json')
	return unless basecamp_projects

	basecamp_projects.each do |basecamp_project|
		# Create the project in codebase
		codebase_project = codebase_request("/create_project", :post, {'project' => {'name' => basecamp_project["name"]}})
		return unless codebase_project

		discussions_page = 1
		begin
			basecamp_topicables = basecamp_request("/projects/#{basecamp_project["id"]}/topics.json?page=#{discussions_page}").select{|topic| topic["topicable"]["type"] == "Message"}
			return unless basecamp_topicables

			basecamp_topicables.each do |basecamp_topicable|
				basecamp_discussion = basecamp_request("/projects/#{basecamp_project["id"]}/messages/#{basecamp_topicable["topicable"]["id"]}.json")

				codebase_payload = {:discussion => {:subject => basecamp_discussion["subject"], :content => basecamp_discussion["content"],
					:created_at => basecamp_discussion["created_at"], :updated_at => basecamp_discussion["updated_at"] }}
				if codebase_user_id = user_map[basecamp_discussion["creator"]["id"]]
					codebase_payload[:discussion][:user_id] = codebase_user_id
				else
					codebase_actor_name = basecamp_discussion["creator"]["name"]
					codebase_payload[:discussion_post][:author_name] = codebase_actor_name
					codebase_payload[:discussion_post][:author_email] = ""
				end
				codebase_discussion = codebase_request("/#{codebase_project["project"]["permalink"]}/discussions", :post, codebase_payload)

				basecamp_discussion["comments"].each do |basecamp_update|

					codebase_payload = {:discussion_post => {:content => basecamp_update["content"], 
						:created_at => basecamp_update["created_at"], :updated_at => basecamp_update[:updated_at]}}
					if codebase_user_id = user_map[basecamp_update["creator"]["id"]] 
						codebase_payload[:discussion_post][:user_id] = codebase_user_id
					else
						codebase_actor_name = basecamp_update["creator"]["name"]
						codebase_payload[:discussion_post][:author_name] = codebase_actor_name
						codebase_payload[:discussion_post][:author_email] = ""
					end

					codebase_update = codebase_request("/#{codebase_project["project"]["permalink"]}/discussions/#{codebase_discussion["discussion"]["permalink"]}/posts", :post, codebase_payload)
				end
			end

			discussions_page += 1
		end while basecamp_topicables.length > 0
	end
end


def codebase_request(path, type = :get, payload = nil)
	if type == :get
		req = Net::HTTP::Get.new(path)
	elsif type == :post
		req = Net::HTTP::Post.new(path)
	end

	req.basic_auth(CODEBASE_USERNAME, CODEBASE_API_KEY)
	req['Content-Type'] = 'application/json'
	req['Accept'] = 'application/json'

	if payload.respond_to?(:to_json)
		req.body = payload.to_json
		puts req.body
	end
	

	if ENV["DEVELOPMENT"]
		res = Net::HTTP.new("api3.codebase.dev", 80)
	else
		res = Net::HTTP.new("api3.codebasehq.com", 443)
		res.use_ssl = true
		res.verify_mode = OpenSSL::SSL::VERIFY_NONE
	end

	request(res, req)
end

def basecamp_request(path)
	prefix_path = "/#{BASECAMP_ACCOUNT}/api/v1/"
	path = prefix_path + path

	req = Net::HTTP::Get.new(path);
	req.basic_auth(BASECAMP_USERNAME, BASECAMP_PASSWORD)
	req['User-Agent'] = "CodebaseHQ Importer (http://www.codebasehq.com/)"

	res = Net::HTTP.new("basecamp.com", 443)
	res.use_ssl = true
	res.verify_mode = OpenSSL::SSL::VERIFY_NONE

	request(res, req)
end

def request(res, req)
	puts "Requesting #{req.path}"
	case result = res.request(req)
	when Net::HTTPSuccess
		#json decode
		return JSON.parse(result.body)
	else
		puts result
		puts "Sorry, that request failed."
		puts result.body
		return false
	end
end

run_import