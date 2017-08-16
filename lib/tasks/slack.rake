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

  desc "Update and transfer messages from source to destination Slack instance"
  task :transfer_messages, [:source, :destination, :types] => [:environment] do |t, args|
    source      = args.fetch(:source)
    destination = args.fetch(:destination)
    types       = fetch_types(args, SlackUploader::DEFAULT_TYPES)
    SlackUpdater.transfer_messages(source, destination, types: types)
  end

  desc "Update and transfer messages in specified channels from source to destination Slack instance"
  task :transfer_channels, [:source, :destination, :channels] => [:environment] do |t, args|
    source      = args.fetch(:source)
    destination = args.fetch(:destination)
    channels    = [args.fetch(:channels), *args.extras]
    SlackUpdater.transfer_channels(source, destination, channels: channels)
  end

  desc "List channels in a slack instance"
  task :list_channels, [:source, :types] => [:environment] do |t, args|
    source = args.fetch(:source)
    types  = fetch_types(args, SlackDownloader::DEFAULT_TYPES)
    SlackUpdater.list_channels(source, types: types)
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
