class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext
  require 'json'
  context_to_action!

  BACK_WORD = '← Назад'.freeze

  IN_CART_WORD = 'В корзину'.freeze

  CALLBACK_TYPE_ADD_VARIANT = 0
  CALLBACK_TYPE_DELETE_FROM_CART = 1
  CALLBACK_TYPE_DUPLICATE_ITEM = 2
  CALLBACK_TYPE_SAVED_ADDRESS = 3

  ORDER_STAGE_ADDRESS = 1
  ORDER_STAGE_DELIVERY_TIME = 2

  def start(*)
    session[:cart] = []
    session[:messages_to_delete] = []
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
      text_to_answer = session[:cart].empty? ? 'Я помогу с оформлением заказа' : 'Возможно, Вы хотите выбрать что-то еще'
      respond_with :message, text:  text_to_answer, reply_markup: markup
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
          variants = product.variants
          inline = []
          variants.each do |v|
            callback_data = JSON.generate(type: CALLBACK_TYPE_ADD_VARIANT, id: v.id)
            inline.append([{ text: "#{v.name} Цена: #{v.price}", callback_data: callback_data }])
          end
          category
          save_context :category
          # respond_with :photo, photo: 'https://s3.eu-central-1.amazonaws.com/statictgbot/static/ulitka.jpg'
          respond_with :photo, photo: product.url,
                       caption: product.description,
                       reply_markup: {
                          inline_keyboard: inline
                       }
        else
          respond_with :message, text: "#{value} нет в каталоге"
        end
      end
    end
  end

  def login(first_time=false)
    contact = @_payload['contact']
    if first_time
      respond_with :message, text: 'Отправьте свой контакт для авторизации.
        В мобильной версии нажмите на скрепку и там выберите пункт "Контакт".
        А в десктопной версии Вам надо выбрать зайти в свой профиль и там нажать соответствующую кнопку'
      return
    end
    if logged_in?
      order
    else
      if contact
        @user = User.find_or_create_by(phone: contact['phone_number'], name: contact['first_name'])
        session[:user_id] = @user.id
        order
      else
        respond_with :message, text:'Вы отправили что-то не то'
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
    elsif session[:cart].empty?
      respond_with :message, text: 'Корзина пуста', reply_markup: {
          keyboard: [
              ['Обратно в категории']
          ],
          resize_keyboard: true,
          one_time_keyboard: true,
          selective: true
      }
    else
      total_price = 0
      ids = session[:cart].map { |item| item[:product] }
      variants = Variant.find(ids)
      variants.each_with_index do |variant, index|
        quantity = session[:cart].at(index)[:quantity]
        total_price += variant.price * quantity
        text = "#{index + 1}. #{variant.name} x #{quantity}"
        response = respond_with :message, text: text, reply_markup: {
            inline_keyboard: [
                [{text:'Дублировать позицию', callback_data: JSON.generate(type: CALLBACK_TYPE_DUPLICATE_ITEM, index: index)},
                           {text:'Удалить', callback_data: JSON.generate(type:CALLBACK_TYPE_DELETE_FROM_CART, index: index)}]
            ]
        }
        session[:messages_to_delete] = session[:messages_to_delete].push(response['result']['message_id'])
      end
      if total_price < 500
        total_price += 200
        response = respond_with :message, text: 'Доставка платная при сумме заказа меньше 500 рублей. Стоимость 200 рублей'
        session[:messages_to_delete] = session[:messages_to_delete].push(response['result']['message_id'])
      end
      response = respond_with :message, text: "Сумма заказа #{total_price} рублей. С учетом доставки", reply_markup: {
        keyboard: [
          ['Оформить заказ'],
          ['Обратно в категории']
        ],
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true
      }
      session[:messages_to_delete] = session[:messages_to_delete].push(response['result']['message_id'])
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
      login(true)
    end
  end

  def help(*)
    response = respond_with :message, text: t('.content')
    binding.pry()
  end

  def callback_query(data)
    if data
      json_data = JSON.parse(data)
      case json_data['type']
        when CALLBACK_TYPE_ADD_VARIANT
          i = Variant.find(json_data['id'])
          add_product(i.id, 1)
          edit_message :reply_markup, reply_markup: {
            inline_keyboard: [[]]
          }
          category
          answer_callback_query  "#{i.name} добалено в корзину", show_alert: true
        when CALLBACK_TYPE_DUPLICATE_ITEM
          item = session[:cart].at(json_data['index'])
          item[:quantity] += 1
          variant = Variant.where(id: item[:product]).first
          text = variant ? "В корзине теперь: #{variant.name} #{item[:quantity]} шт "
                     : "Теперь в корзине #{item[:quantity]} шт."
          answer_callback_query text, show_alert: true
          delete_messages
          cart
        when CALLBACK_TYPE_DELETE_FROM_CART
          item = session[:cart].delete_at(json_data['index'])
          variant = Variant.where(id: item[:product]).first
          text = variant ? "Позиция #{variant.name} удалена" : "Позиция удалена"
          answer_callback_query text, show_alert:true
          delete_messages
          cart
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
    if session[:cart].empty?
      respond_with :message, text: 'У Вас ничего нет в корзине'
      category
    end
    order = Order.create(user_id: @user.id, delivery_date: delivery_time,
                         shipping_address: session[:shipping_address])
    total_price = 0
    ids = session[:cart].map{ |item| item[:product]}
    variants = Variant.find(ids)
    variants.each_with_index do |variant, index|
      quantity = session[:cart].at(index)[:quantity]
      OrderLine.create(order_id:order.id, name:variant.name, price:variant.price, quantity: quantity)
      total_price += variant.price * quantity
    end
    if total_price < 500
      OrderLine.create(name: 'Доставка', order_id: order.id, price: 200, quantity: 1)
      total_price += 200
    end
    order.total = total_price
    order.save
    order
  end

  def add_product(product_id, quantity)
    index = session[:cart].index { |item| item[:product] == product_id}
    if index
      session[:cart].at(index)[:quantity] += 1
    else
      session[:cart] = session[:cart].push(product: product_id,
                                           quantity: quantity)
    end
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

  def delete_messages
    session[:messages_to_delete].each do |message_id|
      bot.delete_message(chat_id: chat['id'], message_id: message_id)
    end
    session[:messages_to_delete] = []
  end

  def logged_in?
    @user ||= User.where(id: session[:user_id]).first
  end
end
