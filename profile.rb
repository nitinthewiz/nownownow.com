require 'pg'
require 'erb'
DB = PG::Connection.new(port: 5433, hostaddr: '127.0.0.1', dbname: 'd50b', user: 'd50b')

class String
	def autolink
		self.gsub(/(http\S*)/, '<a href="\1">\1</a>')
	end
end

def h(str)
	ERB::Util.html_escape(str)
end

template = File.read('templates/profile.erb')

# for each person_id that has profile info...
res = DB.exec("SELECT person_id FROM peeps.stats WHERE statkey='now-title'")
res.map{|r| r['person_id'].to_i}.each do |person_id|
	puts person_id
	# get person info
	res = DB.exec("SELECT p.name, p.city, p.state, c.name AS country FROM peeps.people p JOIN peeps.countries c ON p.country=c.code WHERE id=#{person_id}")
	@person = res[0]
	# get now.url
	res = DB.exec("SELECT tiny, short, long FROM now.urls WHERE person_id=#{person_id}")
	@now = res[0]
	# get other urls
	res = DB.exec("SELECT url FROM peeps.urls WHERE person_id=#{person_id} ORDER BY main DESC NULLS LAST, id")
	@urls = res.map{|r| r['url']}
	# get profile answers
	res = DB.exec("SELECT statkey, statvalue FROM peeps.stats WHERE person_id=#{person_id} AND statkey LIKE 'now-%'")
	@profile = {}
	res.each do |r|
		# save in hash skipping the "now-" part of key: liner, red, thought, title, why
		@profile[r['statkey'][4..-1]] = r['statvalue']
	end
	# merge into template, saving as tiny.html
	File.open('site/p/' + @now['tiny'], 'w') do |f|
		f.puts ERB.new(template).result
	end
end
