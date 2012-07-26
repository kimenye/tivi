require 'curb'
require 'CGI'

class RoamTechGateway

  URL = "http://www.roamtech.com/api/mt/?"

  def initialize
    @user_name = "trevor"
    @password = "12345"
    @sender = "5366"
  end

  def receive_notification(params)
    from = params[:message_source]
    msg = params[:message_text]
    id = params[:trxID]

    if SMSLog.find_by_external_id(id.to_i).nil? then
      return SMSLog.create!(:from => from, :msg => msg, :external_id => id.to_i)
    end
  end

  def send_message(recipient,msg,type=Message::TYPE_REMINDER,subscription=nil, show=nil)
    send_url = "#{URL}username=#{@user_name}&password=#{@password}&sender=#{@sender}&msg=#{CGI::escape(msg)}&recipient=#{recipient}&type=0"
    if production?

      data = nil
      response_code = nil

      http = Curl.get() do |curl|
        curl.verbose = false
        curl.on_body { |body|
          data = body
          body.to_s.length
        }
        curl.on_complete { |resp| response_code = resp.response_code }
      end

      if response_code == 200
        id = process_response(data)
        return Message.create!(:external_id => id.to_id, :message_text => msg, :type => type, :subscription => subscription, :show => show)
      end
    else
      Message.create!(:external_id => process_response("DN1701 | 870851").to_i, :message_text => msg, :type => type)
      return send_url
    end
  end

  def process_response(msg)
    return msg.split('|')[1].strip
  end
end