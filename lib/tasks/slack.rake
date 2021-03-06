require 'slack_updater'

namespace :slack do
  desc "Add a new Slack instance"
  task :add, [:name, :api_key] => [:environment] do |t, args|
    name    = args.fetch(:name)
    api_key = args.fetch(:api_key)
    SlackUpdater.create_instance(name, api_key)
  end

  desc "Fetch new messages and files from Slack API"
  task :update, [:types] => [:environment] do |t, args|
    types = fetch_types(args, SlackDownloader::DEFAULT_TYPES)
    SlackUpdater.update_all(download_files: true, types: types)
  end

  desc "Fetch only messages from Slack API"
  task :update_messages, [:types] => [:environment] do |t, args|
    types = fetch_types(args, SlackDownloader::DEFAULT_TYPES)
    SlackUpdater.update_all(download_files: false, types: types)
  end

  desc "Update and transfer messages in all channels of specified type from source to destination Slack instance"
  task :transfer, [:source, :destination, :types] => [:environment] do |t, args|
    source      = args.fetch(:source)
    destination = args.fetch(:destination)
    types       = fetch_types(args, SlackUploader::DEFAULT_TYPES)
    SlackUpdater.transfer(source, destination, types: types)
  end

  desc "Update and transfer messages in specified channels from source to destination Slack instance"
  task :transfer_channels, [:source, :destination, :channels] => [:environment] do |t, args|
    source      = args.fetch(:source)
    destination = args.fetch(:destination)
    channels    = [args.fetch(:channels), *args.extras]
    SlackUpdater.transfer_channels(source, destination, channels: channels)
  end

  desc "Update and transfer direct messages in a single specified channel to the specified users in the destination slack"
  task :transfer_direct_messages, [:source, :destination, :channel, :users] => [:environment] do |t, args|
    source      = args.fetch(:source)
    destination = args.fetch(:destination)
    channel     = args.fetch(:channel)
    users       = [args.fetch(:users), *args.extras]
    SlackUpdater.transfer_direct_messages(source, destination, channel: channel, target_users: users)
  end

  desc "Show best-effort mapping for direct messages"
  task :show_direct_message_mapping, [:source, :destination] => [:environment] do |t, args|
    source      = args.fetch(:source)
    destination = args.fetch(:destination)
    SlackUpdater.show_direct_message_mapping(source, destination)
  end

  desc "List channels in a slack instance"
  task :list_channels, [:source, :types] => [:environment] do |t, args|
    source = args.fetch(:source)
    types  = fetch_types(args, SlackDownloader::DEFAULT_TYPES)
    SlackUpdater.list_channels(source, types: types)
  end

  desc "List users in a slack instance"
  task :list_users, [:source] => [:environment] do |t, args|
    source = args.fetch(:source)
    SlackUpdater.list_users(source)
  end

  private
  # Any number of types may be provided, varargs parameter is implemented using
  # `args.extras`.
  def fetch_types(args, default)
    if first = args[:types]
      [first, *args.extras].map(&:to_sym)
    else
      default
    end
  end
end
