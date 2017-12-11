class TelegramWebhookController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext
  require 'json'
  context_to_action!

  BACK_WORD = '← Назад'.freeze

  OPEN_CURRENT_CATEGORY = 'Что в этой категории?'.freeze

  IN_CART_WORD = 'В корзину'.freeze

  BUNDLES_WORD = 'Акции'.freeze

  PHOTO1 = 'https://s3.eu-central-1.amazonaws.com/statictgbot/static/guide0.jpg'.freeze

  PHOTO2 = 'https://s3.eu-central-1.amazonaws.com/statictgbot/static/guide1.jpg'.freeze

  PHOTO3 = 'https://s3.eu-central-1.amazonaws.com/statictgbot/static/guide2.jpg'.freeze

  CALLBACK_TYPE_ADD_VARIANT = 0
  CALLBACK_TYPE_DELETE_FROM_CART = 1
  CALLBACK_TYPE_DUPLICATE_ITEM = 2
  CALLBACK_TYPE_SAVED_ADDRESS = 3
  CALLBACK_TYPE_CANCEL_ORDER = 4
  CALLBACK_TYPE_ADD_BUNDLE = 5

  ORDER_STAGE_ADDRESS = 1
  ORDER_STAGE_DELIVERY_TIME = 2

  IN_5_MINUTES = 'Пулей'.freeze
  IN_30_MINUTES = 'Через 10 минут'.freeze
  IN_1_HOUR = 'Через 20 минут'.freeze
  IN_2_HOURS = 'Через 30 минут'.freeze

  SHAURMA_SERVICE = 'Шаурма у МИФИ'.freeze

  BUNDLE_RULES = 'Условия АКЦИИ:
        1)Вас должно быть 3 человека
        2)Подпишитесь на ВПомощь || МИФИ
        3)Зарегистрируйтесь в боте - войдите в него и введите "/start"
        4)Закажите 3 шаурмы по цене одной! '.freeze

  BUNDLE_ADD_TEXTS = [
      'Добавить в корзину',
      'Добавить в корзину',
      'Добавить в корзину',
      'Добавить в корзину',
      'Добавить в корзину',
      'Добавить в корзину',
      'Добавить в корзину',
      'Добавить в корзину',
      'Добавить в корзину',
      'Добавить в корзину',
      'Добавить в корзину',
      'Добавить в корзину',
      'Добавить в корзину',
      'Добавить в корзину',
      'Да, норм',
      'Да, норм',
      'Да, норм',
      'Да, норм',
      'Заебись, беру!'
  ].sample

  INTRO = 'Привет! Я Бот ВПомощь.
Я собираю в себе полезные сервисы и услуги для студентов МИФИ!
Сегодня у нас МЕГА АКЦИЯ - 3 шаурмы по цене одной. Жми "Шаурма у МИФИ" '.freeze

  INTRO_SHAURMA = 'Оформи заказ и забери его без очередей и ожидания!
МЕГА АКЦИЯ! 3 шаурмы по цене одной!
Только сегодня по адресу ул. Святослава Рихтера 44к1 (возле чайной)
Жми "АКЦИИ"! '.freeze

  DELIVERY_TYPE = 'Доставка(200 рублей)'.freeze
  SELF_DELIVERY_TYPE = 'Заберу сам'.freeze
  STACK_TYPE = 'Оставить заявку в пуле заказов'.freeze

  def start(*args)
    value = !args.empty? ? args.join(' ') : nil
    Chat.create(chat_id: chat['id'])
    save_context :start
    if value == SHAURMA_SERVICE
      shaurma
    else
      respond_with :message, text: INTRO, reply_markup: {
          keyboard: [
              [{text:SHAURMA_SERVICE}]
          ],
          resize_keyboard: true,
          one_time_keyboard: true,
          selective: true
      }
    end
  end

  def shaurma(*)
    session[:cart] = []
    session[:bundle_cart] = []
    session[:messages_to_delete] = []
    session[:category_stack_id] = []
    category
  end

  def history(*)
    if logged_in?
      active_orders = Order.where('delivery_date >= ?', DateTime.now).where(canceled: false, user_id:@user.id)
      respond_with :message, text: 'У вас нет активных заказов' if active_orders.empty?
      active_orders.each do |o|
        text = format_history_element(o, false)
        callback_data = JSON.generate({ type: CALLBACK_TYPE_CANCEL_ORDER, id: o.id })
        respond_with :message, text: text, reply_markup: {
            inline_keyboard: [
                [{text:'Отменить этот заказ', callback_data: callback_data}]
            ]
        }
      end
    else
      login_to_history("FIRSTTIME")
    end

  end

  def bundle(*args)
    value = !args.empty? ? args.join(' ') : nil
    save_context :bundle
    if value
      if value == IN_CART_WORD
        cart
      elsif value == BACK_WORD
        category
      else
        bundle = Bundle.where(name: value).first
        if bundle
          callback_data = JSON.generate({type: CALLBACK_TYPE_ADD_BUNDLE, id: bundle.id})
          photo = bundle.variants.first.product.image
          inline = [
              [{text: BUNDLE_ADD_TEXTS, callback_data: callback_data}]
          ]
          respond_with :photo, photo: photo,
                       caption: bundle.name,
                       reply_markup: {
                           inline_keyboard: inline
                       } if photo
        else
          respond_with :message, text:'Что-то я не вижу такой акции',
                       reply_markup: build_bundle_keyboard
        end
      end
    else
      respond_with :message, text:BUNDLE_RULES,
                   reply_markup: build_bundle_keyboard
    end
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
      elsif value == BUNDLES_WORD
        bundle
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
      text_to_answer = session[:cart].empty? && session[:bundle_cart].empty? || !user_exist? ? INTRO_SHAURMA
                           : 'Возможно, Вы хотите выбрать что-то еще. Если выбор уже сделан, переходи в корзину.'
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
            inline.append([{ text: "#{v.product.name} #{v.name} Цена: #{v.price}", callback_data: callback_data }])
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
      return
    end
    if logged_in?
      choose_order_type
    else
      if contact
        @user = User.find_or_create_by(phone: contact['phone_number'], name: contact['first_name'])
        session[:user_id] = @user.id
        choose_order_type
      end
    end
  end

  def login_to_history(*args)
    value = !args.empty? ? args.join(' ') : nil
    contact = @_payload['contact']
    save_context :login_to_history
    if value == 'FIRSTTIME'
      respond_with_login_keyboard
      return
    end
    if logged_in?
      history
    else
      if contact
        @user = User.find_or_create_by(phone: contact['phone_number'], name: contact['first_name'])
        session[:user_id] = @user.id
        history
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
    elsif session[:cart].empty? && session[:bundle_cart].empty?
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
      ids = !session[:cart].empty? ? session[:cart].map { |item| item[:product] } : []
      variants = ids.empty? ? [] : Variant.find(ids)
      variants.each_with_index do |variant, index|
        quantity = session[:cart].at(index)[:quantity]
        total_price += variant.price * quantity
        text = "#{index + 1}.#{variant.product.name} #{variant.name} x #{quantity}"
        response = respond_with :message, text: text, reply_markup: {
            inline_keyboard: [
                [{text:'Дублировать позицию', callback_data: JSON.generate(type: CALLBACK_TYPE_DUPLICATE_ITEM, index: index, is_bundle: false)},
                           {text:'Удалить', callback_data: JSON.generate(type:CALLBACK_TYPE_DELETE_FROM_CART, index: index, is_bundle: false)}]
            ]
        }
        session[:messages_to_delete] = session[:messages_to_delete].push(response['result']['message_id'])
      end

      ids = !session[:bundle_cart].empty? ? session[:bundle_cart].map { |item| item[:bundle] } : []
      variants = ids.empty? ? [] : Bundle.find(ids)
      variants.each_with_index do |bundle, index|
        quantity = session[:bundle_cart].at(index)[:quantity]
        total_price += bundle.price * quantity
        text = "#{index + 1}.#{bundle.name} x #{quantity}"
        response = respond_with :message, text: text, reply_markup: {
            inline_keyboard: [
                [{text:'Дублировать позицию', callback_data: JSON.generate(type: CALLBACK_TYPE_DUPLICATE_ITEM, index: index, is_bundle: true)},
                 {text:'Удалить', callback_data: JSON.generate(type:CALLBACK_TYPE_DELETE_FROM_CART, index: index, is_bundle: true)}]
            ]
        }
        session[:messages_to_delete] = session[:messages_to_delete].push(response['result']['message_id'])
      end
      # if total_price < 500
      #   total_price += 200
      #   response = respond_with :message, text: 'Доставка платная при сумме заказа меньше 500 рублей. Стоимость 200 рублей'
      #   session[:messages_to_delete] = session[:messages_to_delete].push(response['result']['message_id'])
      # end
      response = respond_with :message, text: "Сумма заказа #{total_price} рублей", reply_markup: {
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
    if logged_in?
      if value == DELIVERY_TYPE
        order
      elsif value == SELF_DELIVERY_TYPE
        save_context :self_delivery
        respond_with :message, text: "Выбери время, когда заберешь, или введи сам в формате 14:00",
                     reply_markup: time_choice_kb
      else
        save_context :choose_order_type
        respond_with :message, text: 'Выбери то, что по душе', reply_markup: types_keyboard
      end
    else
      login("FIRSTTIME")
    end
  end

  def self_delivery(*args)
    value = !args.empty? ? args.join(' ') : nil
    if logged_in?
      save_context :self_delivery
      if value == IN_5_MINUTES
        order = build_order(DateTime.now + 5.minutes, false)
        respond_with :message, text: "Ваш заказ принят! Сумма заказа #{order.total}.\n Номер заказа #{order.id}"
        after_order_action
      elsif value == IN_30_MINUTES
        order = build_order(DateTime.now + 10.minutes, false)
        respond_with :message, text: "Ваш заказ принят! Сумма заказа #{order.total}.\n Номер заказа #{order.id}"
        after_order_action
      elsif value == IN_1_HOUR
        order = build_order(DateTime.now + 20.minutes, false)
        respond_with :message, text: "Ваш заказ принят! Сумма заказа #{order.total}.\n Номер заказа #{order.id}"
        after_order_action
      elsif value == IN_2_HOURS
        order = build_order(DateTime.now + 30.minutes, false)
        respond_with :message, text: "Ваш заказ принят! Сумма заказа #{order.total}.\n Номер заказа #{order.id}"
        after_order_action
      else
        if valid_time?(value)
          str_time = parse_time(value)
          delivery_time = Time.zone.parse(str_time)
          if delivery_time < DateTime.now
            respond_with :message, text: 'Нельзя уйти в прошлое!', reply_markup: time_choice_kb
          else
            order = build_order(delivery_time, false)
            respond_with :message, text: "Ваш заказ принят! Сумма заказа #{order.total}.\n Номер заказа #{order.id}"
            after_order_action
          end
        else
          respond_with :message, text: 'Плохой формат', reply_markup: time_choice_kb
        end
      end
    else
      login("FIRSTTIME")
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
            respond_with :message,
                         text: "Ваш заказ принят! Сумма заказа #{response[:order].total}" if response[:ok]
            after_order_action if response[:ok]
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
      login("FIRSTTIME")
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
          answer_callback_query  "#{i.name} добавлено в корзину", show_alert: true
        when CALLBACK_TYPE_DUPLICATE_ITEM
          item = !json_data['is_bundle'] ? session[:cart].at(json_data['index'])
                    : session[:bundle_cart].at(json_data['index'])
          item[:quantity] += 1
          answer_callback_query "Теперь в корзине #{item[:quantity]} шт.", show_alert: true
          delete_messages
          cart
        when CALLBACK_TYPE_DELETE_FROM_CART
          if json_data['is_bundle']
            session[:bundle_cart].delete_at(json_data['index'])
          else
            session[:cart].delete_at(json_data['index'])
          end
          answer_callback_query 'Позиция удалена', show_alert:true
          delete_messages
          cart
        when CALLBACK_TYPE_CANCEL_ORDER
          order_to_cancel = Order.where(id: json_data['id']).first
          if order_to_cancel
            order_to_cancel.canceled = true
            order_to_cancel.save
            answer_callback_query "Заказ №#{order_to_cancel.id} отменен", show_alert: true
            send_notify_cancel order_to_cancel
          end
        when CALLBACK_TYPE_ADD_BUNDLE
          b = Bundle.find(json_data['id'])
          add_bundle(b.id, 1)
          edit_message :reply_markup, reply_markup: {
              inline_keyboard: [[]]
          }
          category
          answer_callback_query "#{b.name} добавлено в корзину", show_alert: true
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
    session[:bundle_cart] = []
    session[:order_stage] = 0
    category
  end

  def types_keyboard
    kb = [
        [{text: SELF_DELIVERY_TYPE}],
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
    if session[:cart].empty? && session[:bundle_cart].empty?
      respond_with :message, text: 'У Вас ничего нет в корзине'
      category
      return
    end
    order = Order.create(user_id: @user.id, delivery_date: delivery_time,
                         shipping_address: with_delivery ? session[:shipping_address] : 'Самовывоз' )
    total_price = 0
    ids = !session[:cart].empty? ? session[:cart].map { |item| item[:product] } : []
    variants = ids.empty? ? [] : Variant.find(ids)
    variants.each_with_index do |variant, index|
      quantity = session[:cart].at(index)[:quantity]
      name = "#{variant.product.name} #{variant.name}"
      OrderLine.create(order_id:order.id, name: name, price: variant.price, quantity: quantity)
      total_price += variant.price * quantity
    end
    ids = !session[:bundle_cart].empty? ? session[:bundle_cart].map { |item| item[:bundle] } : []
    variants = ids.empty? ? [] : Bundle.find(ids)
    variants.each_with_index do |bundle, index|
      quantity = session[:bundle_cart].at(index)[:quantity]
      name = "#{bundle.name} "
      OrderLine.create(order_id: order.id, name: name, price: bundle.price, quantity: quantity)
      total_price += bundle.price * quantity
    end
    if total_price < 500 && with_delivery
      OrderLine.create(name: 'Доставка', order_id: order.id, price: 200, quantity: 1)
      total_price += 200
    end
    order.total = total_price
    order.save
    send_notify(order, with_delivery)
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

  def add_bundle(bundle_id, quantity)
    index = session[:bundle_cart].index { |item| item[:bundle] == bundle_id}
    if index
      session[:bundle_cart].at(index)[:quantity] += 1
    else
      session[:bundle_cart] = session[:bundle_cart].push(bundle: bundle_id,
                                                          quantity: quantity)
    end
  end

  def time_choice_kb
    kb = [
        [{text: IN_5_MINUTES}],
        [{text: IN_30_MINUTES}],
        [{text: IN_1_HOUR}],
        [{text: IN_2_HOURS}]
    ]
    {
        keyboard: kb,
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true
    }
  end

  def respond_with_login_keyboard
    respond_with :message, text: 'Могут быть баги на устройствах с маленьким экраном. Воспользуйтесь этим гайдом'
    respond_with :photo, photo: PHOTO1
    respond_with :photo, photo: PHOTO2
    respond_with :photo, photo: PHOTO3
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
    kb.append([BUNDLES_WORD]) unless Bundle.where(active: true).empty?
    Category.where(parent_category_id: parent_id).each do |c|
      kb.append([c.name])
    end
    kb.append([IN_CART_WORD]) unless session[:cart].empty? && session[:bundle_cart].empty?
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

  def build_bundle_keyboard
    kb = []
    Bundle.where(active:true).each do |bundle|
      kb.append([bundle.name])
    end
    kb.append([BACK_WORD])
    kb.append([IN_CART_WORD]) unless session[:cart].empty? && session[:bundle_cart].empty?
    {
        keyboard: kb,
        resize_keyboard: true, one_time_keyboard: true,
        selective: true
    }
  end

  def build_products_keyboard(products)
    kb = []
    products.each do |p|
      kb.append([p.name])
    end
    kb.append([BACK_WORD])
    kb.append([IN_CART_WORD]) unless session[:cart].empty? && session[:bundle_cart].empty?
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

  def valid_time?(time)
    !/[\d]{2}:[\d]{2}/.match(time).to_s.empty?
  end

  def parse_time(time)
    /[\d]{2}:[\d]{2}/.match(time).to_s
  end

  def logged_in?
    @user ||= User.where(id: session[:user_id]).first
  end

  def send_notify(order, with_delivery)
    text = "Заказ номер #{order.id}\n"
    if with_delivery
      text << "Адрес #{order.shipping_address}\n"
      text << "Доставить в #{order.delivery_date.time.to_formatted_s(:db)}\n"
    else
      text << "Заберет в #{order.delivery_date.time.to_formatted_s(:db)}\n"
    end
    order.order_lines.each_with_index do |ol, index|
      text << "#{index + 1}: #{ol.name} x #{ol.quantity}\n"
    end
    text << "Общая стоимость #{order.total}\n"
    Merchant.all.each do |merchant|
      bot.send_message(chat_id: merchant.chat_id, text: text) if merchant.chat_id
    end
  end

  def send_notify_cancel(order)
    Merchant.all.each do |merchant|
      bot.send_message(chat_id: merchant.chat_id, text: "Заказ №#{order.id} отменен") if merchant.chat_id
    end
  end

  def format_history_element(order, with_delivery)
    text = "Заказ номер #{order.id}\n"
    if with_delivery
      text << "Адрес #{order.shipping_address}\n"
      text << "Доставить в #{order.delivery_date.time.to_formatted_s(:db)}\n"
    else
      text << "Заберу в #{order.delivery_date.time.to_formatted_s(:db)}\n"
    end
    order.order_lines.each_with_index do |ol, index|
      text << "#{index + 1}: #{ol.name} x #{ol.quantity}\n"
    end
    text << "Общая стоимость #{order.total}\n"
  end

  def user_exist?
    Chat.where(chat_id: chat['id']).first
  end
end
