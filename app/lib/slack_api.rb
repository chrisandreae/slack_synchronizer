require 'json'
require 'net/http'

class SlackAPI
  DEBUG = true

  API_PREFIX = 'https://slack.com/api/'

  IM_LIST_API         = 'im.list'
  IM_HISTORY_API      = 'im.history'
  IM_OPEN_API         = 'im.open'

  MPIM_OPEN_API       = 'mpim.open'

  GROUP_LIST_API      = 'groups.list'
  GROUP_HISTORY_API   = 'groups.history'
  GROUP_CREATE_API    = 'groups.create'
  GROUP_INFO_API      = 'groups.info'

  CHANNEL_LIST_API    = 'channels.list'
  CHANNEL_HISTORY_API = 'channels.history'
  CHANNEL_CREATE_API  = 'channels.create'
  CHANNEL_INFO_API    = 'channels.info'

  LIST_USERS_API      = 'users.list'
  USERS_INFO_API      = 'users.info'

  POST_MESSAGE_API    = 'chat.postMessage'

  MESSAGE_APIS = {
    groups:   { list: GROUP_LIST_API,   history: GROUP_HISTORY_API,   create: GROUP_CREATE_API,   info: GROUP_INFO_API },
    channels: { list: CHANNEL_LIST_API, history: CHANNEL_HISTORY_API, create: CHANNEL_CREATE_API, info: CHANNEL_INFO_API },
    mpims:    { list: GROUP_LIST_API,   history: GROUP_HISTORY_API },
    ims:      { list: IM_LIST_API,      history: IM_HISTORY_API }
  }

  BEGINNING = "0.000001"

  attr_reader :api_key

  def initialize(api_key)
    @api_key = api_key
    @last_request = Time.at(0)
  end

  def list_users
    # In the future this API will require pagination
    api_get(LIST_USERS_API).fetch("members")
  end

  def get_user(id)
    api_get(USERS_INFO_API, user: id).fetch("user")
  end

  def post_message(channel_id, message_body)
    api_get(POST_MESSAGE_API, channel: channel_id, link_names: true, unfurl_media: true, **message_body)
  end

  def open_im(user_id)
    api_get(IM_OPEN_API, user: user_id, return_im: true).fetch("channel")
  end

  def open_mpim(user_ids)
    api_get(MPIM_OPEN_API, users: user_ids.join(",")).fetch("group")
  end

  def list_channels(chat_type)
    list_uri = MESSAGE_APIS.fetch(chat_type.to_sym)[:list]
    api_get(list_uri).fetch(chat_type.to_s)
  end

  def get_channel(chat_type, id)
    api = MESSAGE_APIS.fetch(chat_type.to_sym)[:info]
    api_get(api, channel: id).fetch(chat_type.to_s.singularize)
  end

  def create_channel(chat_type, name)
    create_uri = MESSAGE_APIS.fetch(chat_type.to_sym)[:create]
    api_get(create_uri, name: name, validate: true).fetch(chat_type.to_s.singularize)
  end

  def get_channel_history(chat_type, channel_id, from:)
    unless block_given?
      return enum_for(:get_channel_history, chat_type, channel_id, from: from)
    end
    history_uri = MESSAGE_APIS.fetch(chat_type.to_sym)[:history]

    debug "Fetching channel history of #{channel_id} since #{from}"
    messages = []
    loop do
      page = api_get(history_uri, channel: channel_id, oldest: from, count: 1000)
      page_messages = page.fetch("messages")
      break unless page_messages.size > 0

      # messages in a page are always returned in newest-to-oldest order, even
      # if paging forward
      latest_ts   = page_messages.first["ts"]
      earliest_ts = page_messages.last["ts"]
      debug "Got history page of #{page_messages.size} from #{earliest_ts} to #{latest_ts}"
      page_messages.reverse_each do |message_body|
        yield(message_body)
      end

      break unless page["has_more"]
      from = latest_ts
    end
    messages
  end

  # Given a SlackFile URL, download it to the target path with API credentials
  def download_file(uri, path)
    debug("Downloading: #{uri.to_s}")

    Net::HTTP.start(uri.host, uri.port, :use_ssl => (uri.scheme == 'https')) do |http|
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{api_key}"
      http.request(request) do |response|
        File.open(path, 'wb') do |io|
          response.read_body do |chunk|
            io.write chunk
          end
        end
      end
    end

    path
  rescue
    File.delete(path)
    raise
  end

  private

  class Error < RuntimeError
    attr_reader :reason
    def initialize(message, reason)
      super(message)
      @reason = reason
    end
  end

  # Fetch and parse a Slack API JSON endpoint
  def api_get(endpoint, **params)
    url = API_PREFIX + endpoint
    uri = URI.parse(url)
    uri.query = URI.encode_www_form(token: api_key, **params)

    delay_request

    debug "Fetching: #{uri.to_s}"
    response = Net::HTTP.get_response(uri)
    raise Error.new("Error: #{response}") unless response.is_a?(Net::HTTPSuccess)
    hash_response = JSON.parse(response.body)
    raise Error.new("API Error: #{hash_response.to_json}", hash_response["error"]) unless hash_response["ok"]

    hash_response
  end

  # Rate limit Slack API access: the API will cut us off if we hit it faster
  # than once per second.
  API_DELAY_TIME = 1.01
  def delay_request
    interval = Time.now - @last_request
    if interval < API_DELAY_TIME
      wait_time = API_DELAY_TIME - interval
      debug "Waiting #{wait_time}"
      sleep(wait_time)
    end
    @last_request = Time.now
  end

  def debug(str)
    Rails.logger.debug(str) if DEBUG
  end
end
