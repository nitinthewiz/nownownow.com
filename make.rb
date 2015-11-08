#!/usr/bin/env ruby
require 'erb'
require 'pg'
require 'net/http'

DB = PG::Connection.new(port: 5433, hostaddr: '127.0.0.1', dbname: 'd50b', user: 'd50b')

# UPDATE
res = DB.exec("SELECT id, short FROM now.urls WHERE long IS NULL")
res.each do |r|
	id = r['id']
	u = r['short']
	url = 'http://' + u
	res = Net::HTTP.get_response(URI(url))
	if res.code == '200'
		DB.exec_params("UPDATE now.urls SET long=$1, updated_at=NOW() WHERE id=$2", [url, id])
	elsif %w(301 302).include? res.code
		if res['location'].start_with? 'http'
			url = res['location'].gsub('blogspot.co.nz', 'blogspot.com')
		else
			url = 'http://' + URI(url).host + res['location']
		end
		DB.exec_params("UPDATE now.urls SET long=$1, updated_at=NOW() WHERE id=$2", [url, id])
	elsif res.code == '404'
		url = 'http://www.' + u
		res = Net::HTTP.get_response(URI(url))
		if res.code == '200'
			DB.exec_params("UPDATE now.urls SET long=$1, updated_at=NOW() WHERE id=$2", [url, id])
		else
			puts url + "\t" + res.inspect
		end
	else
		puts url + "\t" + res.inspect
	end
end

@urls = []
res = DB.exec("SELECT tiny, short, long FROM now.urls WHERE long IS NOT NULL ORDER BY short")
res.each do |r|
	url = {long: r['long'], short: r['short'], profile: ''}
	profile_link = 'p/' + r['tiny']
	if File.exist?('site/' + profile_link)
		url[:profile] = ' (<a href="%s">+</a>)' % profile_link
	end
	@urls << url
end

template = File.read('templates/index.erb')
File.open('site/index.html', 'w') do |f|
	f.puts ERB.new(template, nil, '>').result
end

