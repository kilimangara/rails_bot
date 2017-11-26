class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext
  require 'json'
  context_to_action!
  use_session!

  BACK_WORD = '← Назад'.freeze

  IN_CART_WORD = 'В корзину'.freeze

  CALLBACK_TYPE_ADD_INGRIDIENT = 0
  CALLBACK_TYPE_DELETE_FROM_CART = 1
  CALLBACK_TYPE_DUPLICATE_ITEM = 2

  def start(*)
    category
    session[:cart] = []
  end

  def category(*args)
    value = !args.empty? ? args.join(' ') : nil
    save_context :category
    if value
      if value == IN_CART_WORD
        cart
      else
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
      end
    else
      markup = build_category_keyboard
      respond_with :message, text: 'Я еще учусь!', reply_markup: markup
    end
  end

  def product(*args)
    value = !args.empty? ? args.join(' ') : nil
    if value
      if value == BACK_WORD
        category
        save_context :category
      elsif value == IN_CART_WORD
        cart
      else
        product = Product.where(name: value).first
        if product
          ingridients = product.ingridients
          inline = []
          ingridients.each do |i|
            callback_data = JSON.generate(type: CALLBACK_TYPE_ADD_INGRIDIENT, id: i.id)
            inline.append(text: "#{i.name} Цена: #{i.price}", callback_data: callback_data)
          end
          add_product(product.id, 1)
          category
          respond_with :message, text: "Вы выбрали #{value}", reply_markup: {
            inline_keyboard: [inline]
          }
        else
          respond_with :message, text: "#{value} нет в каталоге"
        end
        save_context :product
      end
    end
  end

  def login(*_args)
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

  def cart(*args)
    value = !args.empty? ? args.join(' ') : nil
    save_context :cart
    if value == 'Оформить заказ'
      respond_with :message, text: 'ВАУЧ'
    elsif value == 'Обратно в категории'
      category
    else
      total_price = 0
      session[:cart].each_with_index do |item, index|
        p = Product.find(item[:product])
        ingrs = Ingridient.find(item[:ingridients])
        total_price += count_price(p, ingrs)*item[:quantity]
        additional_text = ''
        ingrs.each { |ingr| additional_text += "#{ingr.name} "}
        text = additional_text.empty? ? "#{index + 1}. #{p.name} x #{item[:quantity]}"
                   : "#{index + 1}. #{p.name} x #{item[:quantity]} с #{additional_text}"
        respond_with :message, text: text, reply_markup: {
            inline_keyboard: [
                [{text:'Дублировать позицию', callback_data: JSON.generate(type: CALLBACK_TYPE_DUPLICATE_ITEM, index: index)},
                 {text:'Удалить', callback_data: JSON.generate(type:CALLBACK_TYPE_DELETE_FROM_CART, index: index)}]
            ]
        }
      end
      respond_with :message, text: "Сумма заказа #{total_price} рублей", reply_markup: {
        keyboard: [
          ['Оформить заказ'],
          ['Обратно в категории']
        ],
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true
      }
    end
  end

  def help(*)
    respond_with :message, text: t('.content')
  end

  def callback_query(data)
    if data
      json_data = JSON.parse(data)
      case json_data['type']
        when CALLBACK_TYPE_ADD_INGRIDIENT
          i = Ingridient.find(json_data['id'])
          add_ingridient(i.id)
          edit_message :reply_markup, reply_markup: {
            inline_keyboard: [[]]
          }
          answer_callback_query  'Добавлено', show_alert: true
        when CALLBACK_TYPE_DUPLICATE_ITEM
          session[:cart].at(json_data['index'])[:quantity] += 1
          cart
          answer_callback_query 'Изменено кол-во', show_alert: true
        when CALLBACK_TYPE_DELETE_FROM_CART
          session[:cart].delete_at(json_data['index'])
          edit_message :text, text: 'Удалено'
          answer_callback_query  'Добавлено', show_alert: true
        else answer_callback_query  'Произошла ошибка', show_alert: true
      end
    end
  end

  def message(message)
    respond_with :message, text: t('.content', text: message['text'])
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
    if command?
      respond_with :message, text: t('telegram_webhook.action_missing.command', command: action)
    else
      respond_with :message, text: t('telegram_webhook.action_missing.feature', action: action)
    end
  end

  private

  def count_price(product, ingridients)
    result = product.price
    ingridients.each do |i|
      result += i.price
    end
    result
  end

  def add_product(product_id, quantity)
    session[:last_added_product] = product_id
    session[:cart] = session[:cart].push(product: product_id,
                                         ingridients: [],
                                         quantity: quantity)
  end

  def add_ingridient(ingridient_id)
    product_id = session[:last_added_product]
    index = session[:cart].find_index { |obj| obj[:product] == product_id }
    if index
      product_hash = session[:cart].at(index)
      product_hash[:ingridients] = product_hash[:ingridients].push(ingridient_id)
    end
  end

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
      kb.append([c.name])
    end
    kb.append([IN_CART_WORD]) unless session[:cart].empty?
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
      kb.append([p.name])
    end
    kb.append([BACK_WORD])
    kb.append([IN_CART_WORD]) unless session[:cart].empty?
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
