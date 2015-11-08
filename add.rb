#!/usr/bin/env ruby
require 'pg'
DB = PG::Connection.new(port: 5433, hostaddr: '127.0.0.1', dbname: 'd50b', user: 'd50b')
raise 'bad URL' unless /\S+\.\S+/ === ARGV[0]
res = DB.exec_params("INSERT INTO now.urls (short) VALUES ($1) RETURNING *", [ARGV[0]])
puts res[0].inspect
