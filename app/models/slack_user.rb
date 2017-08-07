class SlackUser < ApplicationRecord
  serialize :user_body, JSON

  belongs_to :slack_instance
  has_many :slack_messages, dependent: :nullify
end
