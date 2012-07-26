require 'curb'
require 'json'


class AfricasTalkingGatewayAuthenticationError < Exception
end

class AfricasTalkingGatewayUnexpectedError < Exception
end

class SMSMessage
  attr_accessor :id, :text, :from, :date

  def initialize(m_id, m_text,m_from, m_to ,m_date)
    @id = m_id
    @text = m_text
    @from = m_from
    @to = m_to
    @date = m_date
  end
end

class MessageStatusReport

  attr_accessor :message, :total_number, :number_successful, :total_cost, :status_reports

  def initialize(json_text)
    json = JSON.parse(json_text)
    status_text = json["SMSMessageData"]["Message"]
    @total_cost = status_text.split(/KES /)[1].to_f
    @number_successful = status_text.split(/\//)[0].split(/Sent to /)[1].to_i
    @total_number = status_text.split(/\//)[1].split(/ Total/)[0].to_i
    @message = status_text

    @status_reports = json["SMSMessageData"]["Recipients"].collect { |status|
      StatusReport.new(status["number"], status["status"], status["cost"])
    }
  end
end

class StatusReport
  attr_accessor :number, :status, :cost

  def initialize(m_number, m_status, m_cost)
    @number = m_number
    @status = m_status
    @cost = m_cost
  end
end

class AfricasTalkingGateway

  #Constants
  URL = 'https://api.africastalking.com/version1/messaging'
  ACCEPT_TYPE = 'application/json'

  def initialize(user_name,api_key)
    @user_name = user_name
    @api_key = api_key
  end

  def send_message(recipients, message)
    data = nil
    response_code = nil

    post_body = {:username => @user_name, :message => message, :to => recipients }

    http = Curl.post(URL, post_body) do |curl|
      curl.headers['Accept'] = ACCEPT_TYPE
      curl.headers['apiKey'] = @api_key
      curl.verbose = true

      curl.on_body { |body|
        data = body
        body.to_s.length
      }
      curl.on_complete { |resp| response_code = resp.response_code }
    end

    raise AfricasTalkingGatewayAuthenticationError if response_code == 401
    raise AfricasTalkingGatewayUnexpectedError "Unexpected error occured" if response_code != 201 or data.nil?
  end

  def fetch_messages(last_received_id)
    data = nil
    response_code = nil

    http = Curl.get("#{URL}?username=#{@user_name}&lastReceivedId=#{last_received_id}") do |curl|
      curl.headers['Accept'] = ACCEPT_TYPE
      curl.headers['apiKey'] = @api_key
      curl.verbose = false
      curl.on_body { |body|
        data = body
        body.to_s.length
      }
      curl.on_complete { |resp| response_code = resp.response_code }
    end

    raise AfricasTalkingGatewayAuthenticationError if response_code == 401
    raise AfricasTalkingGatewayUnexpectedError "Data is nil for some unexpected reason" if response_code != 200 or data.nil?

    messages = JSON.parse(data)["SMSMessageData"]["Messages"].collect { |msg|
      SMSMessage.new msg["id"], msg["text"], msg["from"] , msg["to"], msg["date"]
    }
  end

  #def fetch_messages (service, last_received_message_id=get_latest_received_message_id)
  #  msgs = service.fetch_messages(last_received_message_id).reject! { |msg|
  #    msg.text.downcase.match(/tivi/).nil? or !SMSLog.find_by_external_id(msg.id.to_i).nil?
  #  }
  #end

  #def poll_subscribers (service)
  #  messages = fetch_messages(service)
  #  subscriptions = messages.collect { |message|
  #    sub = create_subscription(message)
  #  }
  #  subscriptions.reject { |sub| sub.nil? }.length
  #end

  #def send_reminders(api,duration=5,from=Time.now)
  #  reminders = get_reminders(duration, from)
  #  status_messages = []
  #  if production?
  #    status_messages = reminders.each { |reminder|
  #      api.send_message(reminder[:to], reminder[:message])
  #    }
  #  else
  #    status_messages = reminders.collect { |reminder|
  #      MessageStatusReport.new({
  #                                  :SMSMessageData => {
  #                                      :Message => "Sent to 1\/1 Total Cost: KES 1.50",
  #                                      :Recipients => [
  #                                          {
  #                                              :number => reminder[:to],
  #                                              :status => "Success",
  #                                              :cost => "KES 1.50"
  #                                          }
  #                                      ]
  #                                  }
  #                              }.to_json)
  #    }
  #  end
  #  status_messages
  #end
end
