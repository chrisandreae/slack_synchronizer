class AddChannelSync < ActiveRecord::Migration[5.1]
  def change
    create_table :channel_syncs do |t|
      t.references :slack_instance, foreign_key: true, index: true
      t.references :slack_channel, foreign_key: true, index: true
      t.string :target_channel_id, null: false
      t.integer :last_timestamp_seconds,  null: false, default: 0
      t.integer :last_timestamp_fraction, null: false, default: 1
    end
  end
end
