# Upload Music

Created on 20 August 2023.  
Last updated on 21 August 2023.

This project uses MusicKit (and its connection to Apple Music API) 
to upload playlists to the users Apple Music library. This app works
but is intended for running locally. It needs refactoring and optimization 
to make it production ready.

## Requirements
- Apple Music subscription (for user running app)
- MusicKit service enabled on the app identifier
- Playlists stored in `Playlists` directory in JSON files (check Models.swift for the types)

## Run

Run the app, authorize MusicKit by hitting the button.
After authorization hit the upload button to begin the process.
The app will read all the playlists in the `Playlists` directory
and upload them to the user's library. The playlist name will be
the file name. The songs will be matched by name, artist and album.

The app loops through each playlist and each song in the playlist.
Each song will be searched for in Apple Music and then adds 
the first result to the playlist. If the song is not found, 
it will be skipped. If there is an error searching for the song
the app will continue but log the error to the console.
Progress of the upload can be monitored in the console.

## Resources

Ordered by relevance.
- [MusicKit documentation](https://developer.apple.com/documentation/musickit)
- [Apple Music API documentation](https://developer.apple.com/documentation/applemusicapi)
- [Meet MusicKit for Swift](https://developer.apple.com/videos/play/wwdc2021/10294/)
- [MusicKit](https://developer.apple.com/musickit/)