class SlackChannel < ApplicationRecord
  serialize :channel_body, JSON

  belongs_to :slack_instance
  has_many :slack_messages, dependent: :destroy
end
