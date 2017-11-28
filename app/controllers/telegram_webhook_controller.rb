class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext
  require 'json'
  context_to_action!

  BACK_WORD = '← Назад'.freeze

  IN_CART_WORD = 'В корзину'.freeze

  CALLBACK_TYPE_ADD_INGRIDIENT = 0
  CALLBACK_TYPE_DELETE_FROM_CART = 1
  CALLBACK_TYPE_DUPLICATE_ITEM = 2
  CALLBACK_TYPE_SAVED_ADDRESS = 3

  ORDER_STAGE_ADDRESS = 1
  ORDER_STAGE_DELIVERY_TIME = 2

  def start(*)
    session[:cart] = []
    category
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
        save_context :product
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
          save_context :category
          # respond_with :photo, photo: 'https://s3.eu-central-1.amazonaws.com/statictgbot/static/ulitka.jpg'
          respond_with :photo, photo: 'https://s3.eu-central-1.amazonaws.com/statictgbot/static/ulitka.jpg',
                       caption: "В корзину #{value}", reply_markup: {
            inline_keyboard: [inline]
          }
        else
          respond_with :message, text: "#{value} нет в каталоге"
        end
      end
    end
  end

  def login(*args)
    contact = @_payload['contact']
    if logged_in?
      order
    else
      if contact
        @user = User.find_or_create_by(phone: contact['phone_number'], name: contact['first_name'])
        session[:user_id] = @user.id
        order
      else
        respond_with_login_keyboard
      end
    end
  end

  def message(*args)
    start
  end

  def cart(*args)
    value = !args.empty? ? args.join(' ') : nil
    save_context :cart
    if value == 'Оформить заказ'
      order
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
      if total_price < 500
        total_price += 200
        respond_with :message, text: 'Доставка платная при сумме заказа меньше 500 рублей. Стоимость 200 рублей'
      end
      respond_with :message, text: "Сумма заказа #{total_price} рублей. С учетом доставки", reply_markup: {
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

  def order(*args)
    value = !args.empty? ? args.join(' ') : nil
    save_context :order
    if logged_in?
      if value
        case session[:order_stage]
          when ORDER_STAGE_DELIVERY_TIME
            response = order_time value
            after_order_action if response[:ok]
            respond_with :message,
                         text: "Ваш заказ принят! Сумма заказа #{response[:order].total}" if response[:ok]
          when ORDER_STAGE_ADDRESS
            session[:shipping_address] = value
            session[:order_stage] = ORDER_STAGE_DELIVERY_TIME
            respond_with :message, text: 'Введите время доставки в формате 24.11.2017 10:00'
          else session[:order_stage] = ORDER_STAGE_ADDRESS
        end
      else
        session[:order_stage] = ORDER_STAGE_ADDRESS
        respond_with :message, text: 'Выберите адрес доставки'
      end
    else
      login
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
          answer_callback_query  'Удалена позиция', show_alert: true
        else answer_callback_query  'Произошла ошибка', show_alert: true
      end
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

  def after_order_action
    session[:cart] = []
    session[:order_stage] = 0
    respond_with :message, text: 'Возможно вы хотите что-то еще?'
    category
  end

  def order_time(time)
    parsed_time = time.in_time_zone('Moscow')
    if parsed_time
      order = build_order(parsed_time)
      {ok: true, order: order}
    else
      respond_with :message, text: 'Неправильный формат, попробуйте еще раз'
      {ok: false}
    end
  end

  def build_order(delivery_time)
    order = Order.create(user_id: @user.id, delivery_date: delivery_time,
                         shipping_address: session[:shipping_address])
    total_price = 0
    session[:cart].each do |item|
      product = Product.find(item[:product])
      product_line = OrderLine.create(order_id: order.id, name: product.name, price: product.price,
                                      quantity: item[:quantity])
      total_price += product.price * item[:quantity]
      item[:ingridients].each do |ingr_id|
      ingr = Ingridient.find(ingr_id)
      OrderLine.create(order_id: order.id, name: ingr.name, price: ingr.price,
                       parent_order_line_id: product_line.id, quantity: 1)
      total_price += ingr.price
      end
    end
    if total_price < 500
      OrderLine.create(name: 'Доставка', order_id: order.id, price: 200, quantity: 1)
      total_price += 200
    end
    order.total = total_price
    order.save
    order
  end

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
