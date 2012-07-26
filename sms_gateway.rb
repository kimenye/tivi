module SMSGateway

end

class RoamTechGateway
  include SMSGateway

  def receive_notification(params)
    from = params[:message_source]
    msg = params[:message_text]
    id = params[:trxID]

    if SMSLog.find_by_external_id(id.to_i).nil? then
      return SMSLog.create!(:from => from, :msg => msg, :external_id => id.to_i)
    end
  end
end