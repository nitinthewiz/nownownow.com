require 'erb'
require 'pg'
require 'net/http'

DB = PG::Connection.new(port: 5433, hostaddr: '127.0.0.1', dbname: 'd50b', user: 'd50b')

def h(str)
	ERB::Util.html_escape(str)
end

class String
	def autolink
		self.gsub(/(http\S*)/, '<a href="\1">\1</a>')
	end
end

desc 'visit short URLs to get real/long URL'
task :visit do
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
end

desc 'make profile pages'
task :profiles do
	template = File.read('templates/profile.erb')
	# for each person_id that has profile info...
	res = DB.exec("SELECT person_id FROM peeps.stats WHERE statkey='now-title'")
	res.map{|r| r['person_id'].to_i}.each do |person_id|
		puts person_id
		# get person info
		res = DB.exec("SELECT p.name, p.city, p.state, c.name AS country
			FROM peeps.people p JOIN peeps.countries c ON p.country=c.code
			WHERE id=#{person_id}")
		@person = res[0]
		# get now.url
		res = DB.exec("SELECT tiny, short, long FROM now.urls WHERE person_id=#{person_id}")
		@now = res[0]
		# get other urls
		res = DB.exec("SELECT url FROM peeps.urls WHERE person_id=#{person_id}
			ORDER BY main DESC NULLS LAST, id")
		@urls = res.map{|r| r['url']}
		# get profile answers
		res = DB.exec("SELECT statkey, statvalue FROM peeps.stats
			WHERE person_id=#{person_id} AND statkey LIKE 'now-%'")
		@profile = {}
		res.each do |r|
			# save in hash skipping the "now-" part of key: liner, red, thought, title, why
			@profile[r['statkey'][4..-1]] = r['statvalue']
		end
		# merge into template, saving as tiny
		File.open('site/p/' + @now['tiny'], 'w') do |f|
			f.puts ERB.new(template).result
		end
	end
end

desc 'write an updated index.html'
task :index do
	@urls = []
	res = DB.exec("SELECT tiny, short, long FROM now.urls
		WHERE tiny IS NOT NULL AND long IS NOT NULL ORDER BY short")
	res.each do |r|
		url = {long: r['long'], short: r['short'], profile: ''}
		profile_link = 'p/' + r['tiny']
		if File.exist?('site/' + profile_link)
			url[:profile] = ' (<a href="%s">+</a>)' % profile_link
		end
		@urls << url
	end
	File.open('site/index.html', 'w') do |f|
		f.puts ERB.new(File.read('templates/index.erb'), nil, '>').result
	end
end

desc 'add a new URL: rake add something.net/now'
task :add, [:a1, :a2] do |t, args|
	puts t.inspect
	puts args.inspect
	raise 'bad URL' unless /\S+\.\S+/ === short
	res = DB.exec_params("INSERT INTO now.urls (short) VALUES ($1) RETURNING *", [short])
	u = res[0]
	puts u.inspect
	Rake::Task['visit'].execute
	res = DB.exec("UPDATE now.urls
		SET tiny=SUBSTRING(short, 1, position('.' IN short) - 1)
		WHERE id=%d RETURNING *" % u['id'])
	puts res[0].inspect
	Rake::Task['index'].execute
	%x(git diff site/index.html)
end

