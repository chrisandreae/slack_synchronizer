class SlackFile < ApplicationRecord
  DOWNLOAD_PATH = File.join(Rails.root, "tmp/slack_files")

  serialize :file_body, JSON

  belongs_to :slack_instance
  has_many :slack_messages, dependent: :nullify

  scope :download_pending, ->{ where(download_path: nil).where("slack_mirror_url IS NOT NULL") }
end
