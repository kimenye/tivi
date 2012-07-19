require_relative 'models'

module SchedulerHelper
  def get_seconds_from_min min
    return min * 60
  end

  def _get_start_of_day(time)
    Time.local(time.year, time.month, time.day, 0, 0, 0)
  end

  def today_at_time(hour,min)
    today = _get_start_of_day(Time.now)
    return Time.local(today.year, today.month, today.day, hour, min, 0)
  end

  def _get_end_of_day(time)
    Time.local(time.year, time.month, time.day, 23,59,59)
  end

  def _get_show_name_from_text (text)
    text.downcase.split(/tivi/)[1].strip
  end

  def _get_start_of_the_week (day)
    start_of_week = day if day.sunday?

    while start_of_week.nil?
      day = day - (24 * 3600)
      start_of_week = day if day.sunday?
    end

    return start_of_week
  end

  def get_schedule_for_day(time, channel)
    start_of_day = _get_start_of_day(time)
    end_of_day = _get_end_of_day(time)
    Schedule.all(:start_time => { '$gte' => start_of_day.utc },:end_time => { '$lte' => end_of_day.utc }, :show_id => { '$in' => Show.all(:channel_id => channel.id).collect { |s| s.id }  })
  end

  def get_next_time_scheduled(show)
    Schedule.first(:show_id => show.id, :start_time => { '$gte' => Time.now.utc } , :order => :start_time)
  end

  def sync_shows (service, calendar, day=Time.now)
    start_of_day = _get_start_of_day(day)
    end_of_day = _get_end_of_day(day)

    events = GCal4Ruby::Event.find service, {}, {
        :calendar => calendar,
        'start-min'=> start_of_day.utc.xmlschema,
        'start-max' => end_of_day.utc.xmlschema }


    events.collect { |event|
      {
          :name =>  event.title,
          :start_time => event.start_time,
          :end_time => event.end_time
      }
    }
  end

  def sync_shows_for_week (service, calendar, from=_get_start_of_the_week(Time.now))
    shows = []
    (1..7).each { |idx|
       sync_shows(service, calendar, from + (idx * 24 * 3600)).each { |show|
          shows << show
       }
    }
    shows
  end

  def create_debug_shows (channel)
    nine_thirty_am_show = Show.create(:channel => channel, :name=> "9.30 AM Show", :description => "30 min show starting at 9.30 AM")
    ten_show = Show.create(:channel => channel, :name=> "10 AM Show", :description => "30 min show starting at 10.00 AM")
    ten_thirty_show = Show.create(:channel => channel, :name=> "10.30 AM Show", :description => "30 min show starting at 10.30 AM")

    Schedule.create!(:start_time => today_at_time(9,30), :end_time => today_at_time(10,00), :show => nine_thirty_am_show)
    Schedule.create!(:start_time => today_at_time(10,00), :end_time => today_at_time(10,30), :show => ten_show)
    Schedule.create!(:start_time => today_at_time(10,30), :end_time => today_at_time(11,00), :show => ten_thirty_show)
  end

  def create_schedule(service, channel, weekly=false)
    if weekly
      shows = sync_shows_for_week(service, channel.calendar_id)
    else
      shows = sync_shows(service, channel.calendar_id)
    end

    shows.each{ |_show|
      show = Show.find_by_name_and_channel_id(_show[:name], channel.id)
      if show.nil?
        show = Show.create(:name => _show[:name], :description => _show[:name], :channel => channel)
      end

      schedule = Show.find_by_show_id_and_start_time(show.id, _show[:start_time])
      if schedule.nil?
        schedule = Schedule.create!(:start_time => _show[:start_time], :end_time => _show[:end_time], :show => show)
      end
    }
  end

  def get_shows_starting_in_duration (duration=5, from=Time.now)
    start_time = from + get_seconds_from_min(duration)
    Schedule.find_all_by_start_time(start_time.utc)
  end

  def get_reminders (duration=5, from=Time.now)
    shows = get_shows_starting_in_duration(duration,from)
    reminders = []
    shows.each { |show|
      #find any subscriptions for these shows
      subscriptions = Subscription.find_all_by_show_id(show.show.id)
      reminders.concat(subscriptions.collect { |sub|
        {
            :to => sub.subscriber.phone_number,
            :message => "Your show #{sub.show.name} starts in 5 min"
        }
      })
    }
    reminders
  end

  def get_latest_received_message_id
    last_sms = SMSLog.empty? ? nil : SMSLog.last(:order => :external_id)
    last_sms.nil? ? 410 : last_sms.external_id
  end

  def fetch_messages (service, last_received_message_id=get_latest_received_message_id)
    msgs = service.fetch_messages(last_received_message_id).reject! { |msg|
      msg.text.downcase.match(/tivi/).nil? or !SMSLog.find_by_external_id(msg.id.to_i).nil?
    }
  end

  def poll_subscribers (service)
    messages = fetch_messages(service)
    subscriptions = messages.collect { |message|
      sub = create_subscription(message)
    }
    subscriptions.reject { |sub| sub.nil? }.length
  end

  def create_subscription(sms)
    show_name = _get_show_name_from_text(sms.text)
    subscriber = Subscriber.first_or_create(:phone_number => sms.from)

    show = Show.first(:name => {'$regex' => /#{show_name}/i })

    subscription = Subscription.new
    subscription.subscriber = subscriber
    subscription.show_name = show_name
    if !show.nil?
      existing = Subscription.find_by_show_id_and_subscriber_id_and_active(show.id, subscriber.id, true)
      if existing.nil?
        subscription.show = show
        subscription.active = true
        subscription.save!
      else
        subscription = nil
      end
    else
      existing_in_active = Subscription.find_by_subscriber_id_and_show_name_and_active(subscriber.id, {'$regex' => /#{show_name}/i}, false)
      if existing_in_active.nil?
        subscription.save!
      else
        subscription = nil
      end
    end
    subscription
  end

  def send_reminders(api,duration=5,from=Time.now)
    reminders = get_reminders(duration, from)
    status_messages = []
    if production?
      status_messages = reminders.each { |reminder|
        api.send_message(reminder[:to], reminder[:message])
      }
    else
      status_messages = reminders.collect { |reminder|
        MessageStatusReport.new({
                                    :SMSMessageData => {
                                        :Message => "Sent to 1\/1 Total Cost: KES 1.50",
                                        :Recipients => [
                                            {
                                                :number => reminder[:to],
                                                :status => "Success",
                                                :cost => "KES 1.50"
                                            }
                                        ]
                                    }
                                }.to_json)
      }
    end
    status_messages
  end
end

class Scheduler
  include SchedulerHelper
end