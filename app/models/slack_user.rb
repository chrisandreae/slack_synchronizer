# == Schema Information
#
# Table name: slack_users
#
#  id                :integer          not null, primary key
#  slack_instance_id :integer          not null
#  slack_id          :string           not null
#  user_name         :string           not null
#  user_body         :text             not null
#

class SlackUser < ApplicationRecord
  serialize :user_body, JSON

  belongs_to :slack_instance
  has_many :slack_messages, dependent: :nullify

  # Best effort to name the user
  def name
    if (real_name = user_body["real_name"]).present?
      real_name
    else
      user_name
    end
  end
end
