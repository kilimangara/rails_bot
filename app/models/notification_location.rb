class NotificationLocation < ApplicationRecord
  validates_presence_of :longitude
  validates_presence_of :latitude
  validates_presence_of :description

  after_create :send_location


  def send_location
    bot = Telegram::Bot::Client.new('415804146:AAFNk6ZZERN5tSuYoYXQf-qPQx1IAcg9FDc')
    Chat.all.each do |c|
      bot.send_location(chat_id: c.chat_id,
                                          longitude: self.longitude,
                                          latitude: self.latitude)
      bot.send_message(chat_id: c.chat_id, text: self.description)
    end
  end
end
