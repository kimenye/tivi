require 'rubygems'
require 'sinatra'
require 'rack/gridfs'

class MediaApp < Sinatra::Base
  db = 'tivi'

  binding.pry
  if ENV['MONGOHQ_URL']
    uri = URI.parse(ENV['MONGOHQ_URL'])
    MongoMapper.connection = Mongo::Connection.from_uri(ENV['MONGOHQ_URL'])
    db = uri.path.gsub(/^\//, '')
  end

  puts ">>> DB is #{db}"

  use Rack::GridFS, :database => db, :prefix => 'images'

  get /.*/ do
    "The URL did not match a file in GridFS."
  end
end
