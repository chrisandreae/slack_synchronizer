class SlackInstance < ApplicationRecord
  has_many :slack_channels, dependent: :destroy
  has_many :slack_users, dependent: :destroy
  has_many :slack_files, dependent: :destroy
end
