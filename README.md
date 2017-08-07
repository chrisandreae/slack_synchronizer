# README

This Rails app provides basic backup functionality and sync for Slack accounts.
After initializing the database with `rails db:setup`, add your Slack accounts
with `rake slack:add[name,api_key]`.

## Backup

Download new messages and files from Slack API: `rake slack:update[types]`

Download only messages from Slack API: `rake slack:update_messages[types]`

`types` is optional, and may be any subset of `channels`, `groups`, and `ims`

## Sync

Update and transfer messages from source to destination Slack instance:
`rake slack:transfer_messages[source,destination,types]`

`types` is optional, and may be any subset of `channels` and `groups`.
