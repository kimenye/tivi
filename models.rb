require 'mongo_mapper'

class Channel
  include MongoMapper::Document

  key :name, String, :required => true
  key :code, String, :required => true
  key :calendar_id, String
  key :created_at, Time, :default => Time.now
  many :shows
end

class Show
  include MongoMapper::Document

  key :name, String
  key :description, String
  key :created_at, Time, :default => Time.now
  belongs_to :channel
end

class Schedule
  include MongoMapper::Document

  key :start_time, Time
  key :end_time, Time
  key :promo_text, String
  belongs_to :show
end

class Subscription
  include MongoMapper::Document

  key :show_name, String
  key :active, Boolean, :default => false
  key :cancelled, Boolean, :default => false
  key :from, Time, :default => Time.now
  belongs_to :subscriber
  belongs_to :show
end

class SMSLog
  include MongoMapper::Document

  key :external_id, Integer
  key :from, String
  key :msg, String
  key :date, Time, :default => Time.now
end

class Message
  include MongoMapper::Document

  TYPE_REMINDER = "REMINDER"
  TYPE_ACKNOWLEDGEMENT = "ACKNOWLEDGEMENT"

  key :external_id, Integer
  key :message_text, String
  key :type, String, :in => [TYPE_REMINDER,TYPE_ACKNOWLEDGEMENT]
  key :sent, Time, :default => Time.now
  belongs_to :subscriber
  belongs_to :show

end

class Subscriber
  include MongoMapper::Document

  key :phone_number, String
end