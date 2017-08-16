# == Schema Information
#
# Table name: channel_syncs
#
#  id                      :integer          not null, primary key
#  slack_instance_id       :integer
#  slack_channel_id        :integer
#  target_channel_id       :string           not null
#  last_timestamp_seconds  :integer          default(0), not null
#  last_timestamp_fraction :integer          default(1), not null
#

class ChannelSync < ApplicationRecord
  belongs_to :slack_instance
  belongs_to :slack_channel
end
