require 'rubygems'
require 'sinatra'
require 'rack/gridfs'

class MediaApp < Sinatra::Base
  configure do
    db = 'tivi'

    uri = nil
    if ENV['MONGOHQ_URL']
      uri = URI.parse(ENV['MONGOHQ_URL'])
      puts "URL : >>> #{uri}"
      MongoMapper.connection = Mongo::Connection.from_uri(ENV['MONGOHQ_URL'])
      db = uri.path.gsub(/^\//, '')
    end
    if production?
      use Rack::GridFS, :database => db, :hostname => uri.host, :password => uri.password, :port => uri.port, :username => uri.user, :prefix => 'images'
    else
      use Rack::GridFS, :database => db, :prefix => 'images'
    end
  end

  get /.*/ do
    "The URL did not match a file in GridFS."
  end
end
