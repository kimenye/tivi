require 'rubygems'
require 'sinatra'
require 'pry'
require 'haml'
require 'time'
require_relative 'api_application'
require 'sinatra/reloader' if development? or test?

class GuideApp < Sinatra::Base

  get '/mobile' do



  end

  get '/mobile/channel/:id' do

    channel = Channel.find(params[:id])
    schedule = get_schedule_for_rest_of_day(channel)

    haml :"admin/channel", :layout => :admin, :locals => {:channel => channel, :schedule => schedule, :day => day, :prev_day => prev_day, :next_day => next_day }

  end
  
end