class ChannelSync < ApplicationRecord
  belongs_to :slack_instance
  belongs_to :slack_channel
end
