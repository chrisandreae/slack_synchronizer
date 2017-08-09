class SlackInstance < ApplicationRecord
  has_many :slack_channels, dependent: :destroy
  has_many :slack_users, dependent: :destroy
  has_many :slack_files, dependent: :destroy

  # Channels from other slacks, synchronized to this one.
  has_many :channel_syncs, dependent: :destroy
end
