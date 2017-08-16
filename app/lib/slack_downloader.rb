# coding: utf-8
class SlackDownloader
  DEFAULT_TYPES = [:channels, :groups, :ims]
  attr_reader :api, :slack

  def initialize(slack_instance)
    @slack = slack_instance
    @api = SlackAPI.new(slack_instance.api_key)
    @user_cache = {}
    @channel_cache = {}
  end

  def update(download_files: true, types: DEFAULT_TYPES)
    refresh_users

    Set.new([:channels, *types]).each do |type|
      refresh_channels(type)
    end

    types.each do |type|
      update_channels(type, download_files: download_files)
    end
  end

  # Update all channels of the specified type
  def update_channels(type, download_files: true)
    refresh_channels(type) unless @channel_cache[type].present?

    @channel_cache[type].each_value do |channel|
      SlackChannel.transaction do
        update_channel(channel, download_files: download_files)
      end
    end
  end

  # update the specified channel
  def update_channel(channel, download_files: true)
    @download_files = download_files
    last_message = channel.slack_messages.time_order.last
    fetch_from = last_message&.api_timestamp || SlackAPI::BEGINNING

    message_bodies = api.get_channel_history(channel.channel_type, channel.slack_id, from: fetch_from)
    message_bodies.each do |message_body|
      save_message(channel, message_body)
    end
  end

  def download_missing_files
    File.download_pending.find_each do |file|
      download_file(file)
    end
  end

  def refresh_users
    SlackUser.transaction do
      @user_cache = slack.slack_users.index_by(&:slack_id)

      user_bodies = api.list_users

      user_bodies.each do |user_body|
        user_id = user_body["id"]
        @user_cache[user_id] = save_user(user_body, cached: @user_cache[user_id])
      end

      @user_cache.values
    end
  end

  def refresh_channels(type)
    SlackChannel.transaction do
      # Note that multi-party IM aren't a real type here; they count as 'group'
      find_type = [type]
      find_type << :mpims if type == :groups
      cache = slack.slack_channels.where(channel_type: find_type).index_by(&:slack_id)
      @channel_cache[type] = cache

      channel_bodies = api.list_channels(type)

      channel_bodies.each do |channel_body|
        channel_id = channel_body["id"]
        cache[channel_id] = save_channel(type, channel_body, cached: cache[channel_id])
      end

      cache.values
    end
  end

  private

  def save_user(user_body, cached: nil)
    user_id = user_body["id"]
    user = cached || slack.slack_users.find_or_initialize_by(slack_id: user_id)
    user.user_name = user_body["name"]
    user.user_body = user_body
    user.save!
    user
  end

  def find_user(user_id)
    @user_cache[user_id] ||=
      begin
        user = slack.slack_users.find_by(slack_id: user_id)
        if user.nil?
          user_body = api.get_user(user_id)
          user = save_user(user_body)
        end
        user
      end
  rescue SlackAPI::Error => e
    return nil if e.reason == 'user_not_found'
    raise
  end

  def save_channel(type, channel_body, cached: nil)
    channel_id = channel_body["id"]
    channel = cached || slack.slack_channels.find_or_initialize_by(slack_id: channel_id)

    channel.channel_type =
      if channel_body["is_mpim"]
        "mpims"
      else
        type
      end

    channel.name =
      if channel_body["is_im"]
        find_user(channel_body["user"])&.user_name || "unknown user"
      else
        channel_body["name"]
      end

    channel.channel_body = channel_body
    channel.save!
    channel
  end

  def find_channel(type, channel_id)
    cache = (@channel_cache[type] ||= {})
    cache[channel_id] ||=
      begin
        channel = slack.slack_channels.find_by(slack_id: channel_id)
        if channel.nil?
          channel_body = api.get_channel(type, channel_id)
          channel = save_channel(type, channel_body)
        end
        channel
      end

  rescue SlackAPI::Error => e
    return nil if e.reason == 'channel_not_found'
    raise
  end

  def save_message(channel, message_body)
    user_id = message_body["user"] ||
              message_body.dig("comment", "user")

    ts_seconds, ts_fraction =
                message_body["ts"]
                  .split(".")
                  .map { |x| Integer(x, 10) }

    user = find_user(user_id) if user_id

    text =
      case
      when message_body["text"]
         message_body["text"]
      when message_body.has_key?("attachments")
        message_body["attachments"].map { |x| x["text"] }.compact.join("\n")
      else
        "--- Message lost in Slack"
      end

    text = clean_message_text(text)


    message = channel.slack_messages.build(
      timestamp_seconds:  ts_seconds,
      timestamp_fraction: ts_fraction,
      slack_user:         user,
      message_text:       text,
      message_body:       message_body)

    # Download and store file referenced in the message
    case message_body["subtype"]
    when "file_share"
      file_body = message_body["file"]
      message.slack_file = save_file(file_body)
    end

    message.save!
  end

  # Clean up unannotated cross-references in message text
  def clean_message_text(text)
    # Resolve usernames from id
    text = text.gsub(/<@([A-Z0-9]{9})>/) do |match|
      username = find_user($1)&.user_name || "unknown user"
      sprintf("<@%s|%s>", $1, username)
    end

    text.gsub!(/<#([A-Z0-9]{9})>/) do |match|
      channelname = find_channel(:channels, $1)&.name || "unknown channel"
      sprintf("<#%s|%s>", $1, channelname)
    end

    text
  end

  FILE_LOCATIONS = [
    "url_private_download",
    "thumb_1024", "thumb_960", "thumb_720",
    "thumb_480", "thumb_360", "thumb_160",
    "thumb_80", "thumb_64"]

  def save_file(file_body)
    file_id = file_body["id"]

    file = slack.slack_files.find_or_initialize_by(slack_id: file_id)

    if file.new_record?
      # Attempt to fetch Slack's mirror of the file, if it exists. External
      # files (e.g. Dropbox) aren't mirrored by Slack.
      slack_mirror_url = FILE_LOCATIONS.lazy
                           .map { |l| file_body[l] }
                           .drop_while(&:nil?)
                           .first

      file.name = file_body["name"]
      file.slack_mirror_url = slack_mirror_url
      file.file_body = file_body
      file.save!

      if @download_files && slack_mirror_url
        download_file(file)
      end
    end

    file
  end

  def download_file(file)
    if file.download_path.blank? && file.slack_mirror_url.present?
      uri      = URI(file.slack_mirror_url)
      basename = File.basename(file.name, ".*")[0...50]
      extname  = File.extname(file.name)

      Dir.mkdir(SlackFile::DOWNLOAD_PATH) unless Dir.exist?(SlackFile::DOWNLOAD_PATH)
      path = File.join(SlackFile::DOWNLOAD_PATH, "#{file.slack_id}-#{basename}#{extname}")

      unless File.exist?(path)
        api.download_file(uri, path)
      end

      file.update(download_path: path)
    end
  end
end
