# == Schema Information
#
# Table name: slack_files
#
#  id                :integer          not null, primary key
#  slack_instance_id :integer          not null
#  slack_id          :string           not null
#  name              :text             not null
#  slack_mirror_url  :text
#  download_path     :text
#  file_body         :text             not null
#

class SlackFile < ApplicationRecord
  DOWNLOAD_PATH = File.join(Rails.root, "tmp/slack_files")

  serialize :file_body, JSON

  belongs_to :slack_instance
  has_many :slack_messages, dependent: :nullify

  scope :download_pending, ->{ where(download_path: nil).where("slack_mirror_url IS NOT NULL") }
end
