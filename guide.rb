require 'rubygems'
require 'sinatra'
require 'pry'
require 'haml'
require 'time'
require 'sinatra/reloader' if development? or test?

class GuideApp < Sinatra::Base

  helpers SchedulerHelper

  get '/' do

    channel_summary = Array.new
    channel_complete = Array.new
    show_description = Array.new
    channels = Channel.all
    channels.each do |channel|
      current_and_next_schedule = get_current_and_next_schedule(channel)
      channel_summary.push(current_and_next_schedule)
      schedule_for_rest_of_day = get_schedule_for_rest_of_day(channel)
      channel_complete.push(schedule_for_rest_of_day)
    end
    channel = Channel.find(params[:id])
    schedule = get_schedule_for_rest_of_day(channel)

    haml :"guide/mobile", :layout => :guide_layout, :locals => {:channel_summary => channel_summary, :channel_complete => channel_complete, :show_description => show_description }

  end
  
end