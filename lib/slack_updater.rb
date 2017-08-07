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
end
