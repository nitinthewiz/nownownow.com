#!/usr/bin/env ruby
require 'pg'
require 'net/http'

DB = PG::Connection.new(port: 5433, hostaddr: '127.0.0.1', dbname: 'd50b', user: 'd50b')

header = <<STR
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>sites with a /now page</title>
  <meta name="description" content="list of URLs with a /now page">
  <meta name="author" content="Derek Sivers">
  <style type="text/css">
body { font-family: Georgia, serif; font-size: 18px; padding: 0 5px; margin: 0 auto; max-width: 40em; line-height: 1.6em; }
h1, h2, small { font-family: sans-serif; color: #900; }
small { display: block; font-size: 0.8em; margin-bottom: 1em;}
ul { margin: 0; padding: 0; }
li { list-style-type: none; margin-bottom: 0.75em; }
  </style>
</head>
<body>
<section id="content">
<h1>sites with a <a href="http://sivers.org/nowff">/now page</a>:</h1>
<small>
Re-load page to shuffle order.
Follow <a href="https://twitter.com/NowNowNow">@NowNowNow</a> for updates.
</small>
<ul>
STR

footer = <<STR
</ul>
<h2>Total count: %d</h2>
<p>To add one, email <a href="http://sivers.org/">me</a> at <a href="mailto:derek@sivers.org">derek@sivers.org</a></p>
<small>Last update: %s</small>
<small><a href="https://github.com/50pop/nownownow.com">See the code</a> that makes this site.</small>
</section>
<script>
var ul = document.getElementsByTagName('ul')[0];
var lis = ul.getElementsByTagName('li');
var lia = [];
var l = lis.length - 1;
for(l; l >= 0; l--) {
	lia.push(ul.removeChild(lis[l]));
}
var i = lia.length;
while (--i) {
	var j = Math.floor(Math.random() * (i + 1)),
		tmpi = lia[i],
		tmpj = lia[j];
	lia[i] = tmpj;
	lia[j] = tmpi;
}
i = lia.length;
while (--i) {
	ul.appendChild(lia.pop());
}
</script>
</body>
</html>
STR

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

res = DB.exec("SELECT tiny, short, long FROM now.urls WHERE long IS NOT NULL ORDER BY short")
File.open('site/index.html', 'w') do |f|
	f.puts header
	res.each do |r|
		profile_link = 'p/%s.html' % r['tiny']
		profile_show = ''
		if File.exist?('site/' + profile_link)
			profile_show = ' (<a href="%s">+</a>)' % profile_link
		end
		f.puts '<li><a href="%s">%s</a>%s</li>' % [r['long'], r['short'], profile_show]
	end
	f.puts footer % [res.ntuples, Time.now]
end

