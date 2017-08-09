class SlackMessage < ApplicationRecord
  serialize :message_body, JSON
  belongs_to :slack_channel
  belongs_to :slack_user, optional: true
  belongs_to :slack_file, optional: true

  scope :time_order, ->{ order(:timestamp_seconds, :timestamp_fraction) }
  scope :after, ->(seconds, fraction) do
    where("(timestamp_seconds > ? OR (timestamp_seconds = ? AND timestamp_fraction > ?))", seconds, seconds, fraction)
  end

  def api_timestamp
    sprintf("%d.%06d", timestamp_seconds, timestamp_fraction)
  end

  # Discards the fractional part from the API timestamp, which doesn't appear
  # to correspond to actual elapsed time: probably a counter.
  def time
    Time.at(timestamp_seconds).utc
  end
end
