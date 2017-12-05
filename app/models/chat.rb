class Chat < ApplicationRecord
  validates_uniqueness_of :chat_id
end
