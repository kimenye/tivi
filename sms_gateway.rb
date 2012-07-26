require 'curb'
#require 'CGI'

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

  def send_message(recipient,msg,type=Message::TYPE_REMINDER,subscriber=nil, show=nil, real=false)
    send_url = "#{URL}username=#{@user_name}&password=#{@password}&sender=#{@sender}&msg=#{CGI::escape(msg)}&recipient=#{recipient}&type=0"
    puts ">> Called send message #{recipient}, #{msg}, #{real}"
    if real
      data = nil
      response_code = nil

      http = Curl.get(send_url) do |curl|
        curl.verbose = false
        curl.on_body { |body|
          data = body
          body.to_s.length
        }
        curl.on_complete { |resp| response_code = resp.response_code }
      end

      if response_code == 200
        id = process_response(data)
        return Message.create!(:external_id => id.to_i, :message_text => msg, :type => type, :subscriber => subscriber, :show => show)
      end
    else
      msg = Message.create!(:external_id => process_response("DN1701 | 870851").to_i, :message_text => msg, :type => type, :subscriber => subscriber, :show => show)
      return msg
    end
  end

  def process_response(msg)
    return msg.split('|')[1].strip
  end
end