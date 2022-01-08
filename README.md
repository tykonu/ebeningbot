# ebeningbot
### A Discord bot for playing preinstalled sounds in a voice channel.

## Ruby version
3.0.0

## Deployment
To start the bot, run the rake task `bundle exec rake bot:run`

## Upload sounds
Upload some sounds to the database. The sounds should be in the .mp3 format.

To upload, you can use the bot command `.uploadsounds [link]` or create them via the Rails console:
```
rails c
Sound.create(name: 'testname', file: '[YOUR FILE BINARY HERE]')
```
