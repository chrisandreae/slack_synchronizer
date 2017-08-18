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

  def self.transfer(source_name, destination_name, types:)
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
    slack_channels = source.slack_channels.find_all_by!(:slack_id, channels)

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

  def self.transfer_direct_messages(source_name, destination_name, channel:, target_users:)
    source = SlackInstance.find_by!(name: source_name)
    destination = SlackInstance.find_by!(name: destination_name)

    slack_channel = source.slack_channels.find_by!(slack_id: channel)
    slack_users = destination.slack_users.find_all_by!(:slack_id, target_users)

    Rails.logger.debug("Synchronizing #{slack_channel.name}")
    Rails.logger.debug("Downloading from #{source.name}...")
    SlackDownloader.new(source).update_channel(slack_channel, download_files: false)
    Rails.logger.debug("Uploading to #{destination.name}...")
    SlackUploader.new(source, destination).upload_direct_messages(slack_channel, slack_users)
  end

  def self.show_direct_message_mapping(source_name, destination_name)
    source = SlackInstance.find_by!(name: source_name)
    destination = SlackInstance.find_by!(name: destination_name)

    SlackDownloader.new(destination).refresh_users

    source_dl = SlackDownloader.new(source)
    source_dl.refresh_users
    source_dl.refresh_channels(:ims)
    source_dl.refresh_channels(:mpims)

    source_users = source.slack_users.index_by(&:slack_id)
    destination_users = destination.slack_users.index_by(&:user_name)

    # For each channel, if we can map the users to users with identical usernames, sync.
    source.slack_channels.where(channel_type: [:ims, :mpims]).each do |channel|
      ids = channel.member_ids

      from = ids.map { |id| source_users[id] }
      to   = from.map { |user| destination_users[user&.user_name] }

      name = ->(usr){ usr.try { |u| "#{u.name} (#{u.user_name})" } || "<missing user>" }
      mapping = from.zip(to).map { |s, d| "#{name.(s)} => #{name.(d)}" }
      target_ids = to.map { |d| d&.slack_id || "____" }

      puts "Channel #{channel.name}: #{mapping.join(", ")}"
      puts "    rake 'slack:transfer_direct_messages[#{source_name},#{destination_name},#{channel.slack_id},#{target_ids.join(",")}]'"
      puts
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

  def self.list_users(source_name)
    source = SlackInstance.find_by!(name: source_name)
    dl = SlackDownloader.new(source)
    dl.refresh_users

    rows = source.slack_users.order(:user_name).map do |user|
      [user.slack_id, user.user_name]
    end

    puts Terminal::Table.new(rows: rows)
  end
end
