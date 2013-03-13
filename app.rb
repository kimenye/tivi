require 'rubygems'
require 'sinatra'
require 'haml'
require 'pry'
require 'sinatra/reloader' if development? or test?
require_relative 'api_application'
require 'sinatra/assetpack'

class TiviApp < Sinatra::Base

  set :root, File.dirname(__FILE__)
  register Sinatra::AssetPack

  assets do
    #js_compression :closure
    js_compression :uglify

    js :main, '/js/main.js', [
        '/js/vendor/*.js',
    ]

    css :main, [
        '/css/*.css'
    ]

    css :mobile, [
        '/css/mobile.css',
        '/css/foundation_stylesheets/foundation.min.css'
    ]

    css :embed, [
        '/css/embed.css'
    ]

    css :app, [
        '/css/'
    ]

    js :jquery, '/js/jquery.js', [
        #'/js/vendor/jquery.1.7.2.js'
    ]

    js :mobile, '/js/mobile.js', [
        #'/js/vendor/jquery.1.7.2.js',
        '/js/vendor/foundation_javascripts/modernizr.foundation.js',
        '/js/vendor/foundation_javascripts/jquery.foundation.accordion.js',
        '/js/vendor/foundation_javascripts/app.js',
        '/js/vendor/jquery.timeago.js',
        '/js/vendor/jquery.timeago.locale.js',
        '/js/vendor/shotgun.js',
        '/js/vendor/swipe.min.js',
        '/js/vendor/underscore-min.js',
        '/js/vendor/date.js',
        '/js/vendor/knockout.js',
        '/js/model.js',
        '/js/mobile_guide.js',
    ]

    js :foundation, '/js/foundation', [
        '/js/vendor/foundation_javascripts/modernizr.foundation.js',
        '/js/vendor/foundation_javascripts/jquery.foundation.accordion.js',
        '/js/vendor/foundation_javascripts/app.js'
    ]

    js :iframe, '/js/iframe', [
        '/js/seamless_iframe.js'
    ]


    css :foundation, '/css/home.css', [
        '/css/foundation_stylesheets/foundation.min.css'
    ]

    prebuild true
  end


  helpers SchedulerHelper

  configure do
    use Rack::Session::Pool, :expire_after => 86400 # 1 day
    set :protection, :except => :frame_options
    set :public_folder, Proc.new { File.join(root, "static") }
    enable :sessions
  end

  get '/' do
    haml :home, :layout => :layout
  end

  get '/m' do
    type = params[:embedded] == "true" ? "embedded" : "mobile"
    haml :'mobile/view', :layout => :mobile, :locals => { :type => type }
  end

end