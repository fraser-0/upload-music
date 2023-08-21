import SwiftUI
import Foundation
import MusicKit

@main
struct App: SwiftUI.App {
  @State var playlistsToAdd: Array<PlaylistModel> = []
  
  /// The current authorization status of MusicKit.
  @State var musicAuthorizationStatus: MusicAuthorization.Status
  
  /// Opens a URL using the appropriate system service.
  @Environment(\.openURL) private var openURL
  
  init() {
    let authorizationStatus = MusicAuthorization.currentStatus
    self._musicAuthorizationStatus = State(initialValue: authorizationStatus)
  }
  
  var body: some Scene {
    WindowGroup {
      VStack {
        Spacer()
        Text("Upload Music")
        Spacer()
          .frame(height: 20.0)
        if musicAuthorizationStatus == .notDetermined || musicAuthorizationStatus == .denied {
          Button(action: handleButtonPressed) {
            buttonText
              .padding([.leading, .trailing], 10)
          }
          .buttonStyle(.automatic)
          .colorScheme(.light)
        } else if musicAuthorizationStatus == .authorized {
          Button(action: handleButtonPressed) {
            buttonText
              .padding([.leading, .trailing], 10)
          }
          .buttonStyle(.automatic)
          .colorScheme(.light)
        }
        Spacer()
      }
      .onAppear() {
        Task {
          // Uncomment to run
          // await run()
        }
      }
    }
  }
  
  /// A button that the user taps to continue using the app according to the current
  /// authorization status.
  private var buttonText: Text {
    let buttonText: Text
    switch musicAuthorizationStatus {
      case .notDetermined:
        buttonText = Text("Continue")
      case .denied:
        buttonText = Text("Open Settings")
      case .authorized:
        buttonText = Text("Sync")
      default:
        fatalError("No button should be displayed for current authorization status: \(musicAuthorizationStatus).")
    }
    return buttonText
  }
  
  /// Allows the user to authorize Apple Music usage when tapping the Continue/Open Setting button.
  private func handleButtonPressed() {
    switch musicAuthorizationStatus {
      case .notDetermined:
        Task {
          let musicAuthorizationStatus = await MusicAuthorization.request()
          await update(with: musicAuthorizationStatus)
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
  private func update(with musicAuthorizationStatus: MusicAuthorization.Status) {
    withAnimation {
      self.musicAuthorizationStatus = musicAuthorizationStatus
    }
  }
  @MainActor
  func readFiles() {
    // if let fileURL = Bundle.main.url(forResource: "Playlists/Blink 182 Cover Band", withExtension: "json") {
    //   do {
    //     let fileContents = try String(contentsOf: fileURL)
    //     print("File contents: \(fileContents)")
    //   } catch {
    //     print("Error reading file: \(error)")
    //   }
    // } else {
    //   print("File not found in the app bundle.")
    // }
    
    if var url = Bundle.main.resourceURL {
      do {
        url = URL(string: url.absoluteString + "Playlists")!
        let fileURLs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        let fileNames = fileURLs.map { $0.lastPathComponent }
        for fileName in fileNames {
          readFile(fileName.replacingOccurrences(of: ".json", with: ""))
        }
        // print(playlistsToAdd.map { $0.name })
        playlistsToAdd.sort { $0.name!.lowercased() < $1.name!.lowercased() }
        // print(playlistsToAdd.map { $0.name })
        print("All files read.")
      } catch {
        print("Error reading app bundle folder: \(error)")
      }
    } else {
      print("App bundle URL not found.")
    }
  }
  
  func readFile(_ fileName: String) {
    let decoder = JSONDecoder()
    if let fileURL = Bundle.main.url(forResource: "Playlists/\(fileName)", withExtension: "json") {
      do {
        let fileContentsString = try String(contentsOf: fileURL)
        // print("File contents: \(fileContentsString)")
        let fileContentsData = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        // print("File contents: \(fileContentsData)")
        var playlist = try decoder.decode(PlaylistModel.self, from: fileContentsData)
        playlist.name = fileName
        playlistsToAdd.append(playlist)
      } catch {
        print("Error reading file: \(error)")
      }
    } else {
      print("File not found in the app bundle.")
    }
  }
  
  func readPlaylists() async {
    do {
      let libraryPlaylistsURL = URL(string: "https://api.music.apple.com/v1/me/library/playlists")
  
      guard let libraryPlaylistsURL else { return }
      let request = MusicDataRequest(urlRequest: URLRequest(url: libraryPlaylistsURL))
      let response = try await request.response()
      let playlists = try JSONDecoder().decode(LibraryPlaylists.self, from: response.data)
  
      // print(playlists.first)
      // print(playlists.first.attributes.canEdit)
      
      // guard let playlist = playlists.first else { return }
    } catch let error {
      print(error)
    }
  }
  
  func createPlaylist(name: String) async -> LibraryPlaylist? {
    do {
      // This works but it will set the author as the App name
      // Even with nil it will still set the App name as the author name and it can't be overwritten
      // let newPlaylist = try await MusicLibrary.shared.createPlaylist(name: "Test", authorDisplayName: nil)
      // print(newPlaylist)
      
      // This works and doesn't set the author name
      
      let libraryPlaylistsURL = URL(string: "https://api.music.apple.com/v1/me/library/playlists")
      
      guard let libraryPlaylistsURL else { return nil }
      
      var urlRequest = URLRequest(url: libraryPlaylistsURL)
      urlRequest.httpMethod = "POST"
      urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
      let data = try JSONEncoder().encode(["attributes": ["name": name]])
      urlRequest.httpBody = data
      
      let request = MusicDataRequest(urlRequest: urlRequest)
      let response = try await request.response()
      let responseBody = try JSONDecoder().decode(LibraryPlaylists.self, from: response.data)
      // print(response.urlResponse.statusCode)
      
      return responseBody.first(where: {$0.attributes.name == name})
    } catch let error {
      print(error)
      return nil
    }
  }
  
  /// https://developer.apple.com/documentation/applemusicapi/search_for_catalog_resources
  /// https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
  func searchForSong(term: String) async -> SongResult? {
    do {
      // var libraryPlaylistsURL = URL(string: "https://api.music.apple.com/v1/catalog/au/search?term=\(term.replacingOccurrences(of: " ", with: "+"))&limit=1&types=songs")
      
      let libraryPlaylistsURL = URL(string: "https://api.music.apple.com/v1/catalog/au/search?term=\(term)&limit=1&types=songs")
      
      guard let libraryPlaylistsURL else { return nil }
      
      let request = MusicDataRequest(urlRequest: URLRequest(url: libraryPlaylistsURL))
      let response = try await request.response()
      let responseBody = try JSONDecoder().decode(SearchResponse.self, from: response.data)
      // print(responseBody)
      
      return responseBody.results.songs.data.first
  
      // guard let playlist = playlists.first else { return }
  
      // print(playlist)
      // print(playlist.attributes.canEdit)
      
      // print("https://api.music.apple.com/v1/catalog/au/search?term=\(term.replacingOccurrences(of: " ", with: "+"))&limit=1&types=songs")
    } catch let error {
      print(error)
      print("Errored on \(term)")
      return nil
    }
  }
  
  func addTracks(
    playlistId: MusicItemID,
    songIds: Array<MusicItemID>
  ) async {
    var output = AddTracksRequest()
    for id in songIds {
      output.data.append(TrackRequestData(id: id))
    }
    
    do {
      let addTracksURL = URL(string: "https://api.music.apple.com/v1/me/library/playlists/\(playlistId)/tracks")
      
      guard let addTracksURL else { return }
      
      var urlRequest = URLRequest(url: addTracksURL)
      urlRequest.httpMethod = "POST"
      urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
      let data = try JSONEncoder().encode(output)
      urlRequest.httpBody = data
      
      let request = MusicDataRequest(urlRequest: urlRequest)
      let response = try await request.response()
      print("Added to playlist response is \(response.urlResponse.statusCode)")
    } catch let error {
      print(error)
    }
  }
  
  func test() async {
    print("Running test")
    let playlist = await createPlaylist(name: "123")
    guard let playlist = playlist else {
      print("No playlist")
      return
    }
    let song = await searchForSong(term: "I miss you blink-182 blink-182")
    guard let song = song else {
      print("No song")
      return
    }
    let songIds = [song.id]
    await addTracks(playlistId: playlist.id, songIds: songIds)
  }
  
  func run() async {
    await readFiles()
    for playlistToAdd in playlistsToAdd {
      let playlistName = playlistToAdd.name!
      print("---")
      print("Running for: \(playlistName)")
      print("\(playlistToAdd.tracks.count) songs to add")
      print("---")
      var songIds: Array<MusicItemID> = []
      for track in playlistToAdd.tracks {
        // let trackName = track.trackName.replacingOccurrences(of: "&", with: "&amp;")
        // let artistName = track.artistName.replacingOccurrences(of: "&", with: "&amp;")
        // let albumName = track.albumName.replacingOccurrences(of: "&", with: "&amp;")
        let trackName = track.trackName
        let artistName = track.artistName
        let albumName = track.albumName
        let term = "\(trackName) \(artistName) \(albumName)"
          .replacingOccurrences(of: " ", with: "+")
          // .replacingOccurrences(of: "&", with: "&amp;")
          // .replacingOccurrences(of: "(", with: "")
          // .replacingOccurrences(of: ")", with: "")
          .replacingOccurrences(of: "&", with: "and")
          .replacingOccurrences(of: "'", with: "")
          .replacingOccurrences(of: ".", with: "")
          .replacingOccurrences(of: ",", with: "")
          .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        guard let term = term else {
          print("Term isn't encoded for URL")
          return
        }
        print("Term is \(term)")
        let song = await searchForSong(term: term)
        guard let song = song else {
          print("Could not find \(track.trackName) by \(track.artistName).")
          continue
        }
        print("Found \(track.trackName) by \(track.artistName).")
        songIds.append(song.id)
      }
      let playlist = await createPlaylist(name: playlistName)
      guard let playlist = playlist else {
        print("No playlist")
        return
      }
      print("\(playlistName) playlist created.")
      print("Adding \(songIds.count) out of \(playlistToAdd.tracks.count)...")
      await addTracks(playlistId: playlist.id, songIds: songIds)
      print("---")
      print("Finished for: \(playlistName)")
      print("\(songIds.count) out of \(playlistToAdd.tracks.count) added.")
      print("---")
      print("")
    }
  }
}
