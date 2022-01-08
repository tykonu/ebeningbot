# ebeningbot
### A Discord bot for playing preinstalled sounds in a voice channel.

## Ruby version
3.0.0

## Create and build the development database
```
rails db:create
rails db:migrate
```

## Seed some sounds in your development database
Run the rake task `bundle exec rake copy_sounds:run`

This will convert the .mp3 sounds in the lib/assets/sounds directory and add them into your database.

## Uploading sounds via the Discord interface
The sounds should be in the .mp3 format. 

The sound name will be the same that you use to play them in Discord, so make sure that they are:
- **unique**, 
- **short**, 
- **lowercase** and
- **without any spaces or special characters**.

***BAD***: Ronaldo saying SIUUUUU!!!!!!.MP3

***GOOD***: siuu.mp3

To upload, you can use the bot command in Discord `.uploadsounds [LINK TO A DIRECT .ZIP FILE CONTAINING .MP3 FILES]`

## Deployment
To start the bot, run the rake task `bundle exec rake bot:run`


