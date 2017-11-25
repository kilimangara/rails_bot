class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext
  context_to_action!

  before_action :try_to_login, unless: 'logged_in?'

  STATE_CATEGORY = 0
  STATE_PRODUCT = 1
  STATE_KORZINA = 2
  STATE_LOGIN = 3

  BACK_WORD = 'Назад'.freeze

  def start(*)
    if @user
      category
      save_context :category
    end
  end

  def category(*args)
    value = args.join(' ')
    if value
      category = Category.where(name: value).first
      if category
        save_context :product
        respond_with :message, text: "Теперь выберите что-то из категории #{value}",
                               reply_markup: build_products_keyboard(category.products)
      else
        markup = build_category_keyboard
        respond_with :message, text: "Категории #{value} нет. Выберите заново",
                     reply_markup: markup
      end
    else
      markup = build_category_keyboard
      respond_with :message, text: 'Приветсвую Вас, я помогу выбрать и сделать вам заказ.Выберите из категорий',
                             reply_markup: markup
    end
  end

  def product(*args)
    value = args.join ' '
    if value
      if value == BACK_WORD
        category
        save_context :category
      else
        product = Product.where(name: value).first
        if product
          respond_with :message, text: "Вы выбрали #{value}"
        else
          respond_with :message, text: "#{value} нет в каталоге"
        end
        save_context :product
        byebug
      end
    end
  end

  def login(*args)
    contact = @_payload['contact']
    if @user
      respond_with :message, text: "Вы уже залогинены, как #{@user.name}"
      start
      return
    end
    if contact
      @user = User.find_or_create_by(phone: contact['phone_number'], name: contact['first_name'])
      session[:user_id] = @user.id
      start
    else
      respond_with_login_keyboard
    end
  end

  def help(*)
    respond_with :message, text: t('.content')
  end

  def memo(*args)
    if args.any?
      session[:memo] = args.join(' ')
      respond_with :message, text: t('.notice')
    else
      respond_with :message, text: t('.prompt')
      save_context :memo
    end
  end

  def remind_me
    to_remind = session.delete(:memo)
    reply = to_remind || t('.nothing')
    respond_with :message, text: reply
  end

  def keyboard(value = nil, *)
    if value
      respond_with :message, text: t('.selected', value: value)
    else
      save_context :keyboard
      respond_with :message, text: t('.prompt'), reply_markup: {
        keyboard: [t('.buttons')],
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true
      }
    end
  end

  def inline_keyboard
    respond_with :message, text: t('.prompt'), reply_markup: {
      inline_keyboard: [
        [
          { text: t('.alert'), callback_data: 'alert' },
          { text: t('.no_alert'), callback_data: 'no_alert' }
        ],
        [{ text: t('.repo'), url: 'https://github.com/telegram-bot-rb/telegram-bot' }]
      ]
    }
  end

  def callback_query(data)
    if data == 'alert'
      answer_callback_query t('.alert'), show_alert: true
    else
      answer_callback_query t('.no_alert')
    end
  end

  def message(message)
    respond_with :message, text: t('.content', text: message['text'])
  end

  def inline_query(query, _offset)
    query = query.first(10) # it's just an example, don't use large queries.
    t_description = t('.description')
    t_content = t('.content')
    results = 5.times.map do |i|
      {
        type: :article,
        title: "#{query}-#{i}",
        id: "#{query}-#{i}",
        description: "#{t_description} #{i}",
        input_message_content: {
          message_text: "#{t_content} #{i}"
        }
      }
    end
    answer_inline_query results
  end

  # As there is no chat id in such requests, we can not respond instantly.
  # So we just save the result_id, and it's available then with `/last_chosen_inline_result`.
  def chosen_inline_result(result_id, _query)
    session[:last_chosen_inline_result] = result_id
  end

  def last_chosen_inline_result
    result_id = session[:last_chosen_inline_result]
    if result_id
      respond_with :message, text: t('.selected', result_id: result_id)
    else
      respond_with :message, text: t('.prompt')
    end
  end

  def action_missing(action, *_args)
    puts action
    if command?
      respond_with :message, text: t('telegram_webhook.action_missing.command', command: action)
    else
      respond_with :message, text: t('telegram_webhook.action_missing.feature', action: action)
    end
  end

  private

  def try_to_login
      save_context :login
      respond_with_login_keyboard
  end

  def respond_with_login_keyboard
    kb = [
      [{ text: 'Отправить контакт', request_contact: true }]
    ]
    markup = {
      keyboard: kb,
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true
    }
    respond_with :message, text: 'Отправьте контакт для авторизации', reply_markup: markup
  end

  def build_category_keyboard
    kb = []
    Category.all.each do |c|
      kb.append(c.name)
    end
    kb = [kb]
    {
      keyboard: kb,
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true
    }
  end

  def build_products_keyboard(products)
    kb = []
    products.each do |p|
      kb.append(p.name)
    end
    kb.append(BACK_WORD)
    kb = [kb]
    {
      keyboard: kb,
      resize_keyboard: true, one_time_keyboard: true,
      selective: true
    }
  end

  def logged_in?
    @user ||= User.where(id: session[:user_id]).first
  end

end
