require 'terminal-table'

class SlackUpdater
  def self.create_instance(name, api_key)
    SlackInstance.create!(name: name, api_key: api_key)
  end

  def self.update_all(download_files:, types:)
    SlackInstance.all.each do |instance|
      SlackDownloader.new(instance).update(download_files: download_files, types: types)
    end
  end

  def self.transfer_messages(source_name, destination_name, types:)
    source = SlackInstance.find_by!(name: source_name)
    destination = SlackInstance.find_by!(name: destination_name)
    Rails.logger.debug("Downloading from #{source.name}...")
    SlackDownloader.new(source).update(download_files: false, types: types)
    Rails.logger.debug("Uploading to #{destination.name}...")
    SlackUploader.new(source, destination).upload(types: types)
  end

  def self.transfer_channels(source_name, destination_name, channels:)
    source         = SlackInstance.find_by!(name: source_name)
    destination    = SlackInstance.find_by!(name: destination_name)
    slack_channels = source.slack_channels.where(slack_id: channels).to_a

    unless channels.size == slack_channels.size
      missing = channels - slack_channels.map(&:slack_id)
      raise RuntimeError.new("Cannot find channel(s) with id(s) [#{missing.join(', ')}]")
    end

    dl = SlackDownloader.new(source)
    ul = SlackUploader.new(source, destination)
    slack_channels.each do |channel|
      Rails.logger.debug("Synchronizing #{channel.name}")
      Rails.logger.debug("Downloading from #{source.name}...")
      dl.update_channel(channel, download_files: false)
      Rails.logger.debug("Uploading to #{destination.name}...")
      ul.upload_channel(channel)
    end
  end

  def self.list_channels(source_name, types:)
    source = SlackInstance.find_by!(name: source_name)
    dl = SlackDownloader.new(source)

    types.each do |type|
      dl.refresh_channels(type)
    end

    rows = source.slack_channels
             .where(channel_type: types)
             .order(:channel_type)
             .map do |channel|
      [channel.slack_id, channel.channel_type, channel.name]
    end

    puts Terminal::Table.new(rows: rows)
  end
end
