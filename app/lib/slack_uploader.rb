class SlackUploader
  DEFAULT_TYPES = [:channels, :groups]
  attr_reader :source_slack, :destination_slack, :api, :known_channels, :source_usernames

  def initialize(source_slack, destination_slack)
    @source_slack      = source_slack
    @destination_slack = destination_slack

    @source_usernames = source_slack.slack_users.pluck(:slack_id, :user_name).to_h

    @api = SlackAPI.new(destination_slack.api_key)
    @known_channels = {}

    DEFAULT_TYPES.each do |type|
      api.list_channels(type).each do |cd|
        known_channels[cd["name"]] = cd
      end
    end
  end

  def upload(types: DEFAULT_TYPES)
    types.each do |type|
      upload_channels(type)
    end
  end

  def upload_channels(type)
    source_slack.slack_channels.where(channel_type: type).each do |channel|
      upload_channel(channel)
    end
  end

  # Upload to a new channel. If the channel name conflicts, create a channel
  # "_ex_X", otherwise create directly.
  def upload_channel(channel)
    sync_record = destination_slack.channel_syncs.find_or_initialize_by(slack_channel_id: channel.id)
    if sync_record.new_record?
      name = channel.name

      if known_channels.has_key?(channel.name)
        name = "_ex_#{name}"[0...21]
      end

      target_channel = api.create_channel(channel.channel_type, name)
      sync_record.target_channel_id = target_channel["id"]
      sync_record.save!
    end

    upload_messages(channel, sync_record)
  end

  def upload_direct_messages(channel, target_users)
    target_users = Array.wrap(target_users)

    sync_record = destination_slack.channel_syncs.find_or_initialize_by(slack_channel_id: channel.id)
    if sync_record.new_record?
      target_channel =
        if target_users.size > 1
          api.open_mpim(target_users.map(&:slack_id))
        else
          api.open_im(target_users.first.slack_id)
        end

      sync_record.target_channel_id = target_channel["id"]
      sync_record.save!
    end

    upload_messages(channel, sync_record)
  end

  def upload_messages(channel, sync_record)
    channel.slack_messages
      .includes(:slack_user)
      .after(sync_record.last_timestamp_seconds, sync_record.last_timestamp_fraction)
      .time_order
      .each do |old_message|
        new_message_body = convert_message(old_message)
        api.post_message(sync_record.target_channel_id, new_message_body)

        # Uploading messages is a slow process. We'd like to be able to cancel
        # and continue any time, so keep the last timestamp up to date
        # throughout the process.
        sync_record.last_timestamp_seconds  = old_message.timestamp_seconds
        sync_record.last_timestamp_fraction = old_message.timestamp_fraction
        sync_record.save!
    end
  end

  def convert_message(old_message)
    old_message_body = old_message.message_body
    new_message = {}

    if (user = old_message.slack_user)
      # message from a user
      new_message[:username] = user.user_name
      new_message[:icon_url] = user.user_body["profile"]["image_48"]
    else
      # Something else, such as a bot
      new_message[:username] = old_message_body["username"] || "slack"
      if old_message_body["icons"]
        if old_message_body["icons"].has_key?("emoji")
          new_message[:icon_emoji] = old_message_body["icons"]["emoji"]
        else
          # attempt to grab the largest image
          image_key = old_message_body["icons"].keys.select { |x| /image_/ =~ x }.sort.last
          new_message[:icon_url] = old_message_body["icons"][image_key] if image_key
        end
      end
    end

    text = old_message_body["text"]

    # flatten user references
    text.gsub!(/<@([A-Z0-9]{9})(\|\w+)?>/){ |m| "@" + (source_usernames[$1] || "unknown_user") }

    new_message[:text] = text

    # Lightly attempt to keep attachments
    if old_message_body.has_key?("attachments")
      new_message[:attachments] = JSON.dump(old_message_body["attachments"])

    elsif old_message_body.has_key?("file") &&
          ["png", "jpg"].include?(old_message_body["file"]["filetype"])

      new_message[:attachments] = JSON.dump(
        [{ "fallback"  => old_message_body["file"]["name"],
           "title"     => old_message_body["file"]["name"],
           "image_url" => old_message_body["file"]["url"],
           "thumb_url" => old_message_body["file"]["thumb_80"]}])

    end

    new_message
  end
end
