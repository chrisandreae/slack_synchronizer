# == Schema Information
#
# Table name: slack_channels
#
#  id                :integer          not null, primary key
#  slack_instance_id :integer          not null
#  slack_id          :string           not null
#  channel_type      :string           not null
#  name              :string           not null
#  channel_body      :text             not null
#

class SlackChannel < ApplicationRecord
  serialize :channel_body, JSON

  belongs_to :slack_instance
  has_many :slack_messages, dependent: :destroy

  def self.refine_channel_type(type, channel_body)
    if channel_body["is_mpim"]
      :mpims
    else
      type
    end
  end

  def member_ids
    case channel_type
    when "ims"
      [channel_body["user"]]
    else
      channel_body["members"]
    end
  end
end
