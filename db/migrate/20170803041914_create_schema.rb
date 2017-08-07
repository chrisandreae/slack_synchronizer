class CreateSchema < ActiveRecord::Migration[5.1]
  def change
    create_table :slack_instances do |t|
      t.string :name, null: false
      t.string :api_key, null: false
      t.index [:name], unique: true
    end

    create_table :slack_users do |t|
      t.references :slack_instance, null: false, index: true, foreign_key: true
      t.string :slack_id, null: false
      t.string :user_name, null: false
      t.text   :user_body, null: false
      t.index [:slack_instance_id, :slack_id], unique: true
    end

    create_table :slack_channels do |t|
      t.references :slack_instance, null: false, index: true, foreign_key: true
      t.string :slack_id, null: false
      t.string :channel_type, null: false, index: true
      t.string :name, null: false
      t.text   :channel_body, null: false
      t.index [:slack_instance_id, :slack_id], unique: true
    end

    create_table :slack_files do |t|
      t.references :slack_instance, null: false, index: true, foreign_key: true
      t.string :slack_id, null: false
      t.text :name, null: false
      t.text :slack_mirror_url
      t.text :download_path
      t.text :file_body, null: false
      t.index [:slack_instance_id, :slack_id], unique: true
    end

    create_table :slack_messages do |t|
      t.references :slack_channel, type: :string, null: false, index: true, foreign_key: true
      t.references :slack_user, null: true, type: :string, index: true, foreign_key: true
      t.references :slack_file, null: true, type: :string, index: true, foreign_key: true
      t.integer :timestamp_seconds, null: false
      t.integer :timestamp_fraction, null: false
      t.text :message_text
      t.text :message_body, null: false
      t.index [:slack_channel_id, :timestamp_seconds, :timestamp_fraction], unique: true, name: "index_slack_messages_on_channel_and_time"
    end
  end
end
