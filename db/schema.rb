# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170809091519) do

  create_table "channel_syncs", force: :cascade do |t|
    t.integer "slack_instance_id"
    t.integer "slack_channel_id"
    t.string "target_channel_id", null: false
    t.integer "last_timestamp_seconds", default: 0, null: false
    t.integer "last_timestamp_fraction", default: 1, null: false
    t.index ["slack_channel_id"], name: "index_channel_syncs_on_slack_channel_id"
    t.index ["slack_instance_id"], name: "index_channel_syncs_on_slack_instance_id"
  end

  create_table "slack_channels", force: :cascade do |t|
    t.integer "slack_instance_id", null: false
    t.string "slack_id", null: false
    t.string "channel_type", null: false
    t.string "name", null: false
    t.text "channel_body", null: false
    t.index ["channel_type"], name: "index_slack_channels_on_channel_type"
    t.index ["slack_instance_id", "slack_id"], name: "index_slack_channels_on_slack_instance_id_and_slack_id", unique: true
    t.index ["slack_instance_id"], name: "index_slack_channels_on_slack_instance_id"
  end

  create_table "slack_files", force: :cascade do |t|
    t.integer "slack_instance_id", null: false
    t.string "slack_id", null: false
    t.text "name", null: false
    t.text "slack_mirror_url"
    t.text "download_path"
    t.text "file_body", null: false
    t.index ["slack_instance_id", "slack_id"], name: "index_slack_files_on_slack_instance_id_and_slack_id", unique: true
    t.index ["slack_instance_id"], name: "index_slack_files_on_slack_instance_id"
  end

  create_table "slack_instances", force: :cascade do |t|
    t.string "name", null: false
    t.string "api_key", null: false
    t.index ["name"], name: "index_slack_instances_on_name", unique: true
  end

  create_table "slack_messages", force: :cascade do |t|
    t.string "slack_channel_id", null: false
    t.string "slack_user_id"
    t.string "slack_file_id"
    t.integer "timestamp_seconds", null: false
    t.integer "timestamp_fraction", null: false
    t.text "message_text"
    t.text "message_body", null: false
    t.index ["slack_channel_id", "timestamp_seconds", "timestamp_fraction"], name: "index_slack_messages_on_channel_and_time", unique: true
    t.index ["slack_channel_id"], name: "index_slack_messages_on_slack_channel_id"
    t.index ["slack_file_id"], name: "index_slack_messages_on_slack_file_id"
    t.index ["slack_user_id"], name: "index_slack_messages_on_slack_user_id"
  end

  create_table "slack_users", force: :cascade do |t|
    t.integer "slack_instance_id", null: false
    t.string "slack_id", null: false
    t.string "user_name", null: false
    t.text "user_body", null: false
    t.index ["slack_instance_id", "slack_id"], name: "index_slack_users_on_slack_instance_id_and_slack_id", unique: true
    t.index ["slack_instance_id"], name: "index_slack_users_on_slack_instance_id"
  end

end
