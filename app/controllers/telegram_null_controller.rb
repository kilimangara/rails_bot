class TelegramNullController < Telegram::Bot::UpdatesController

  def start(*)
    respond_with :message, text: 'Я буду готов Вам помогать только в понедельник!'
  end

  def message(message)
    respond_with :message, text: 'Я буду готов Вам помогать только в понедельник!'
  end

  def action_missing(action, *_args)
    respond_with :message, text: 'Такому меня еще не учили :('
  end


end