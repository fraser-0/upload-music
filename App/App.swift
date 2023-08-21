import SwiftUI
import Foundation
import MusicKit

@main
struct App: SwiftUI.App {
  /// The state of the uploading.
  @State
  var uploading: Bool = false
  
  /// The playlists that need to be added to the users Apple Music library.
  @State
  var playlistsToAdd: Array<PlaylistModel> = []
  
  /// The current authorization status of MusicKit.
  @State
  var musicAuthorizationStatus: MusicAuthorization.Status
  
  /// Opens a URL using the appropriate system service.
  @Environment(\.openURL)
  private var openURL
  
  init() {
    let authorizationStatus = MusicAuthorization.currentStatus
    self._musicAuthorizationStatus = State(initialValue: authorizationStatus)
  }
  
  var body: some Scene {
    WindowGroup {
      VStack {
        Spacer()
        
        Text("Upload Music")
        
        Spacer().frame(height: 20.0)
        
        if musicAuthorizationStatus == .notDetermined || musicAuthorizationStatus == .denied {
          Button(action: handleAuthorization) {
            buttonText
              .padding([.leading, .trailing], 10)
          }
          .buttonStyle(.bordered)
          .colorScheme(.light)
        } else if musicAuthorizationStatus == .authorized {
          Button {
            Task {
              await run()
            }
          } label: {
            buttonText
              .padding([.leading, .trailing], 10)
          }
          .disabled(uploading)
          .buttonStyle(.bordered)
          .colorScheme(.light)
        }
        
        Spacer()
      }
    }
  }
  
  /// A button that the user taps to continue using the app according to the current
  /// authorization status.
  private var buttonText: Text {
    let buttonText: Text
    
    if uploading {
      buttonText = Text("Uploading...")
    } else {
      switch musicAuthorizationStatus {
        case .notDetermined:
          buttonText = Text("Authorize")
        case .denied:
          buttonText = Text("Open Settings")
        case .authorized:
          buttonText = Text("Start Upload")
        default:
          fatalError("No button should be displayed for current authorization status: \(musicAuthorizationStatus).")
      }
    }
    
    return buttonText
  }
  
  /// Allows the user to authorize Apple Music usage when tapping the Continue/Open Setting button.
  private func handleAuthorization() {
    switch musicAuthorizationStatus {
      case .notDetermined:
        Task {
          let musicAuthorizationStatus = await MusicAuthorization.request()
          await updateAuthorizationState(with: musicAuthorizationStatus)
        }
      case .denied:
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
          openURL(settingsURL)
        }
      default:
        fatalError("No button should be displayed for current authorization status: \(musicAuthorizationStatus).")
    }
  }
  
  
  /// Safely updates the `musicAuthorizationStatus` property on the main thread.
  @MainActor
  private func updateAuthorizationState(with musicAuthorizationStatus: MusicAuthorization.Status) {
    withAnimation {
      self.musicAuthorizationStatus = musicAuthorizationStatus
    }
  }
  
  /// Read all the files in the Playlists directory and add them to the `playlistsToAdd`.
  @MainActor
  func readPlaylistJSONFiles() {
    if var url = Bundle.main.resourceURL {
      do {
        url = URL(string: url.absoluteString + "Playlists")!
        let fileURLs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        let fileNames = fileURLs.map { $0.lastPathComponent }
        
        // create a decoder to be used to parse the files
        let decoder = JSONDecoder()
        
        // loop through the files, parse and save them
        for fileName in fileNames {
          parseFile(
            fileName: fileName.replacingOccurrences(of: ".json", with: ""),
            with: decoder
          )
        }
        
        // sort the files alphabetically
        playlistsToAdd.sort { $0.name!.lowercased() < $1.name!.lowercased() }
        
        print("All playlists read from the directory.")
      } catch {
        print("Error playlists: \(error)")
      }
    } else {
      print("App bundle URL not found.")
    }
  }
  
  /// Parse a playlist JSON file and add it to `playlistsToAdd`.
  func parseFile(
    fileName: String,
    with decoder: JSONDecoder
  ) {
    if let fileURL = Bundle.main.url(forResource: "Playlists/\(fileName)", withExtension: "json") {
      do {
        let fileContentsData = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        var playlist = try decoder.decode(PlaylistModel.self, from: fileContentsData)
        
        // update the playlist name to the file name
        playlist.name = fileName
        
        // add to the playlists
        playlistsToAdd.append(playlist)
      } catch {
        print("Error reading playlist file: \(error)")
      }
    } else {
      print("Playlist not found.")
    }
  }
  
  /// Read the users current playlists.
  ///
  /// Use if you want to upload to existing playlists.
  func readPlaylists() async -> LibraryPlaylists? {
    do {
      let libraryPlaylistsURL = URL(string: "https://api.music.apple.com/v1/me/library/playlists")
      
      guard let libraryPlaylistsURL else { return nil }
      
      /// make the request to Apple Music API
      let request = MusicDataRequest(urlRequest: URLRequest(url: libraryPlaylistsURL))
      let response = try await request.response()
      
      // parse and return the playlists
      return try JSONDecoder().decode(LibraryPlaylists.self, from: response.data)
    } catch let error {
      print("Failed to read the user's playlists: \(error)")
      return nil
    }
  }
  
  /// Create a playlist in the users Apple Music library.
  ///
  /// If you want a simplier approach use `MusicLibrary.shared.createPlaylist`
  /// however that will add the app as the author name of the library.
  func createPlaylist(name: String) async -> LibraryPlaylist? {
    do {
      let libraryPlaylistsURL = URL(string: "https://api.music.apple.com/v1/me/library/playlists")
      
      guard let libraryPlaylistsURL else { return nil }
      
      // build the request to Apple Music API
      var urlRequest = URLRequest(url: libraryPlaylistsURL)
      urlRequest.httpMethod = "POST"
      urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
      let data = try JSONEncoder().encode(["attributes": ["name": name]])
      urlRequest.httpBody = data
      
      // make the request to Apple Music API
      let request = MusicDataRequest(urlRequest: urlRequest)
      let response = try await request.response()
      
      // parse the response
      let responseBody = try JSONDecoder().decode(LibraryPlaylists.self, from: response.data)
      
      // return the first playlist where the name matches
      // this is unsafe if there are multiple matching names
      // for my use there are no clashes
      return responseBody.first(where: {$0.attributes.name == name})
    } catch let error {
      print("Failed to create playlist \(name): \(error)")
      return nil
    }
  }
  
  /// Search for a song using a term and return the first result.
  ///
  /// There are specific requirements for the search term which can be found
  /// [here](https://developer.apple.com/documentation/applemusicapi/search_for_catalog_resources).
  /// The country code may need to be replaced if not in Australia.
  /// Details of country codes can be found [here](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2).
  func searchForSong(term: String) async -> SongResult? {
    do {
      let libraryPlaylistsURL = URL(string: "https://api.music.apple.com/v1/catalog/au/search?term=\(term)&limit=1&types=songs")
      
      guard let libraryPlaylistsURL else { return nil }
      
      // make the request to Apple Music API
      let request = MusicDataRequest(urlRequest: URLRequest(url: libraryPlaylistsURL))
      let response = try await request.response()
      
      // parse the response
      let responseBody = try JSONDecoder().decode(SearchResponse.self, from: response.data)
      
      // return the first song
      return responseBody.results.songs.data.first
    } catch let error {
      print("\(term) errored.")
      print("Failed to search for \(term): \(error)")
      return nil
    }
  }
  
  /// Add tracks to a playlist.
  func addTracks(
    playlistId: MusicItemID,
    songIds: Array<MusicItemID>
  ) async {
    // build the tracks output
    var output = AddTracksRequest()
    for id in songIds {
      output.data.append(TrackRequestData(id: id))
    }
    
    do {
      let addTracksURL = URL(string: "https://api.music.apple.com/v1/me/library/playlists/\(playlistId)/tracks")
      
      guard let addTracksURL else { return }
      
      // build the request to Apple Music API
      var urlRequest = URLRequest(url: addTracksURL)
      urlRequest.httpMethod = "POST"
      urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
      let data = try JSONEncoder().encode(output)
      urlRequest.httpBody = data
      
      // make the request to Apple Music API
      let request = MusicDataRequest(urlRequest: urlRequest)
      let response = try await request.response()
    } catch let error {
      print("Failed to added \(songIds.count) to \(playlistId): \(error)")
    }
  }
  
  @MainActor
  func run() async {
    // start processing
    uploading = true
    
    // read all the playlist files
    readPlaylistJSONFiles()
    
    // for each of the playlists to add
    for playlistToAdd in playlistsToAdd {
      // unsafely get the name
      // this shouldn't fail it was lazy encoding on the type
      let playlistName = playlistToAdd.name!
      
      printStartOfPlaylistUpload(
        playlistName: playlistName,
        numberOfTracks: playlistToAdd.tracks.count
      )
      
      // store the ids of the songs to add to the playlist
      var songIds: Array<MusicItemID> = []
      
      // loop through all the tracks
      // search for them
      // add to them to be added to playlist
      for track in playlistToAdd.tracks {
        // pull out the song details
        let trackName = track.trackName
        let artistName = track.artistName
        let albumName = track.albumName
        
        print("Starting search for \(trackName) by \(artistName).")
        
        // build and clean the search term
        let term = "\(trackName) \(artistName) \(albumName)"
          .replacingOccurrences(of: " ", with: "+")
          .replacingOccurrences(of: "&", with: "and")
          .replacingOccurrences(of: "'", with: "")
          .replacingOccurrences(of: ".", with: "")
          .replacingOccurrences(of: ",", with: "")
          .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        
        // safely unwrap the term
        guard let term = term else {
          print("Could not encode \(trackName) by \(artistName) for search.")
          continue
        }
        
        print("The search term is \(term)")
        
        // search for the song and unwrap it
        let song = await searchForSong(term: term)
        guard let song = song else {
          print("Could not find \(trackName) by \(artistName).")
          continue
        }
        
        print("Found \(trackName) by \(track.artistName).")
        songIds.append(song.id)
      }
      
      // create the playlist
      // doing this here so we can kill the app and not have to clean a bunch of playlists
      let playlist = await createPlaylist(name: playlistName)
      guard let playlist = playlist else {
        print("\(playlistName) was not created.")
        uploading = false
        return
      }
      
      print("\(playlistName) playlist created.")
      
      // add tracks
      print("Adding \(songIds.count) out of \(playlistToAdd.tracks.count)...")
      await addTracks(playlistId: playlist.id, songIds: songIds)
      
      printEndOfPlaylistUpload(
        playlistName: playlistName,
        numberOfTracksAdded: songIds.count,
        numberOfTracksExpected: playlistToAdd.tracks.count
      )
    }
    
    uploading = true
  }
  
  /// Read and print a file as a String.
  ///
  /// To be used for testing.
  func readAndPrintFileAsAString(fileURL: URL) throws {
    let fileContentsString = try String(contentsOf: fileURL)
    print("File contents: \(fileContentsString)")
  }
  
  /// Read and print a file as a Data.
  ///
  /// To be used for testing.
  func readAndPrintFileAsAData(fileURL: URL) throws {
    let fileContentsData = try Data(contentsOf: fileURL, options: .mappedIfSafe)
    print("File contents: \(fileContentsData)")
  }
  
  /// Print the start of a new playlist upload.
  func printStartOfPlaylistUpload(
    playlistName: String,
    numberOfTracks: Int
  ) {
    print("---")
    print("Running for: \(playlistName)")
    print("\(numberOfTracks) songs to add")
    print("---")
  }
  
  /// Print the end of a new playlist upload.
  func printEndOfPlaylistUpload(
    playlistName: String,
    numberOfTracksAdded: Int,
    numberOfTracksExpected: Int
  ) {
    print("---")
    print("Finished for: \(playlistName)")
    print("\(numberOfTracksAdded) out of \(numberOfTracksExpected) added.")
    print("---")
    print("")
  }
}
