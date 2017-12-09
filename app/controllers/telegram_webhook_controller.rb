class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext
  require 'json'
  context_to_action!

  BACK_WORD = '← Назад'.freeze

  OPEN_CURRENT_CATEGORY = 'Что в этой категории?'.freeze

  IN_CART_WORD = 'В корзину'.freeze

  CALLBACK_TYPE_ADD_VARIANT = 0
  CALLBACK_TYPE_DELETE_FROM_CART = 1
  CALLBACK_TYPE_DUPLICATE_ITEM = 2
  CALLBACK_TYPE_SAVED_ADDRESS = 3

  ORDER_STAGE_ADDRESS = 1
  ORDER_STAGE_DELIVERY_TIME = 2

  DELIVERY_TYPE = 'Доставка(200 рублей)'.freeze
  SELF_DELIVERY_TYPE = 'Заберу сам'.freeze
  STACK_TYPE = 'Оставить заявку в пуле заказов'.freeze

  def start(*)
    session[:cart] = []
    session[:messages_to_delete] = []
    session[:category_stack_id] = []
    Chat.create(chat_id: chat['id'])
    category
  end

  def category(*args)
    value = !args.empty? ? args.join(' ') : nil
    save_context :category
    if value
      if value == IN_CART_WORD
        cart
      elsif value == BACK_WORD
        session[:category_stack_id].pop
        respond_with :message, text: 'Снова тут :(',
                                       reply_markup: build_category_keyboard(session[:category_stack_id].last)
      elsif value == OPEN_CURRENT_CATEGORY
        category = Category.find(session[:category_stack_id].last)
        save_context :product
        respond_with :message, text: 'Можно выбирать!',
                                       reply_markup: build_products_keyboard(category.products)
      else
        category = Category.where(name: value).first
        if category
          if !category.inner_categories.empty?
            session[:category_stack_id].push(category.id)
            respond_with :message, text:"Продолжим!", reply_markup: build_category_keyboard(category.id)
          else
            save_context :product
            respond_with :message, text: "Теперь выберите что-то из категории #{value}",
                         reply_markup: build_products_keyboard(category.products)
          end
        else
          markup = build_category_keyboard(session[:category_stack_id].last)
          respond_with :message, text: "Категории #{value} нет. Выберите заново",
                                 reply_markup: markup
        end
      end
    else
      markup = build_category_keyboard(session[:category_stack_id].last)
      text_to_answer = session[:cart].empty? ? 'Я помогу с оформлением заказа' : 'Возможно, Вы хотите выбрать что-то еще'
      respond_with :message, text: text_to_answer, reply_markup: markup
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
          respond_with :photo, photo: product.image.url,
                       caption: product.description,
                       reply_markup: {
                          inline_keyboard: inline
                       } if product.image
        else
          respond_with :message, text: "#{value} нет в каталоге"
        end
      end
    end
  end

  def login(*args)
    value = !args.empty? ? args.join(' ') : nil
    contact = @_payload['contact']
    save_context :login
    if value == 'FIRSTTIME'
      respond_with_login_keyboard
    end
    if logged_in?
      order
    else
      if contact
        @user = User.find_or_create_by(phone: contact['phone_number'], name: contact['first_name'])
        session[:user_id] = @user.id
        order
      else
        respond_with :message, text: 'Вы отправили что-то не то'
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
      choose_order_type
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
        name = variant.name || variant.product.name
        text = "#{index + 1}. #{name} x #{quantity}"
        response = respond_with :message, text: text, reply_markup: {
            inline_keyboard: [
                [{text:'Дублировать позицию', callback_data: JSON.generate(type: CALLBACK_TYPE_DUPLICATE_ITEM, index: index)},
                           {text:'Удалить', callback_data: JSON.generate(type:CALLBACK_TYPE_DELETE_FROM_CART, index: index)}]
            ]
        }
        session[:messages_to_delete] = session[:messages_to_delete].push(response['result']['message_id'])
      end
      # if total_price < 500
      #   total_price += 200
      #   response = respond_with :message, text: 'Доставка платная при сумме заказа меньше 500 рублей. Стоимость 200 рублей'
      #   session[:messages_to_delete] = session[:messages_to_delete].push(response['result']['message_id'])
      # end
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

  def choose_order_type(*args)
    value = !args.empty? ? args.join(' ') : nil
    if value == DELIVERY_TYPE
      order
    elsif value == SELF_DELIVERY_TYPE
      order = build_order(DateTime.now, false)
      after_order_action unless order.errors.empty?
      respond_with :message, text: "Ваш заказ принят! Сумма заказа #{response[:order].total}" unless order.errors.empty?
    else
      save_context :choose_order_type
      respond_with :message, text: 'Выбери то, что по душе'
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
      login('FIRSTTIME')
    end
  end

  def help(*)
    respond_with :message, text: 'Просто введите /start!'
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
    respond_with :message, text: 'Такому меня еще не учили :('
  end

  def merchant(*args)
    phone = args.at(0)
    merchant = Merchant.where(phone: phone).first
    if merchant
      merchant.chat_id = chat['id']
      if merchant.save
        respond_with :message, text: 'Вы зарегестрированы как продавец!'
      else
        respond_with :message, text: 'Возникла какая-то ошибка, попробуйте еще'
      end
    else
      respond_with :message, text: 'Такой номер продавца не зарегестрирован :('
    end
  end

  private

  def after_order_action
    session[:cart] = []
    session[:order_stage] = 0
    respond_with :message, text: 'Возможно вы хотите что-то еще?'
    category
  end

  def types_keyboard
    kb = [
        [{text: SELF_DELIVERY_TYPE}],
        [{text: DELIVERY_TYPE}]
    ]
    {
        keyboard: kb,
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true
    }
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

  def build_order(delivery_time, with_delivery=true)
    if session[:cart].empty?
      respond_with :message, text: 'У Вас ничего нет в корзине'
      category
    end
    order = Order.create(user_id: @user.id, delivery_date: delivery_time,
                         shipping_address: with_delivery ? session[:shipping_address] : 'Самовывоз' )
    total_price = 0
    ids = session[:cart].map{ |item| item[:product]}
    variants = Variant.find(ids)
    variants.each_with_index do |variant, index|
      quantity = session[:cart].at(index)[:quantity]
      OrderLine.create(order_id:order.id, name: variant.name, price:variant.price, quantity: quantity)
      total_price += variant.price * quantity
    end
    if total_price < 500 && with_delivery
      OrderLine.create(name: 'Доставка', order_id: order.id, price: 200, quantity: 1)
      total_price += 200
    end
    order.total = total_price
    order.save
    send_notify(order)
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

  def build_category_keyboard(parent_id=nil)
    kb = []
    Category.where(parent_category_id: parent_id).each do |c|
      kb.append([c.name])
    end
    kb.append([IN_CART_WORD]) unless session[:cart].empty?
    kb.append([BACK_WORD]) if parent_id
    if parent_id
      c = Category.find(parent_id)
      kb.append([OPEN_CURRENT_CATEGORY]) unless c.products.empty?
    end
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

  def send_notify(order)
    text = "Заказ номер #{order.id}\n"
    text << "Адрес #{order.shipping_address}\n"
    order.order_lines.each_with_index do |ol, index|
      text << "#{index + 1}: #{ol.name} x #{ol.quantity}\n"
    end
    text << "Доставить в #{order.delivery_date}\n"
    text << "Общая стоимость #{order.total}\n"
    Merchant.all.each do |merchant|
      bot.send_message(chat_id: merchant.chat_id, text: text)
    end
  end
end
