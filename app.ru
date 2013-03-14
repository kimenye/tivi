#To use with thin
# thin start -p PORT -R config.ru

require 'sinatra'

# include our Application code
require File.join(File.dirname(__FILE__), 'app.rb')
require File.join(File.dirname(__FILE__), 'api_application.rb')
require File.join(File.dirname(__FILE__), 'admin.rb')
require File.join(File.dirname(__FILE__), 'guide.rb')
require File.join(File.dirname(__FILE__), 'media.rb')

# disable sinatra's auto-application starting
disable :run

#sync logs
$stdout.sync = true

# we're in dev mode
#set :environment, :production

# Mount our Main class with a base url of /
map "/" do
  run TiviApp
end

# Mount our Blog class with a base url of /blog
map "/api" do
  run ApiApplication
end

map "/admin" do
  run AdminApp
end

map "/media" do
  run MediaApp
end

# Mount our Guide class with a base url of /guide
map "/guide" do
  run GuideApp
end