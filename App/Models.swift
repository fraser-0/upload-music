import Foundation
import MusicKit

struct PlaylistModel: Codable {
  var name: String?
  let tracks: Array<TrackModel>
}

struct TrackModel: Codable {
  let trackNumber: Int
  let trackName: String
  let artistName: String
  let albumName: String
}

public typealias LibraryPlaylists = MusicItemCollection<LibraryPlaylist>

public struct LibraryPlaylist: Codable, MusicItem {
  public let id: MusicItemID
  public let attributes: Attributes
  
  public struct Attributes: Codable, Sendable {
    public let canEdit: Bool
    public let name: String
    public let isPublic: Bool
    public let hasCatalog: Bool
    public let playParams: PlayParameters
    public let description: Description?
    public let artwork: Artwork?
  }
  
  public struct Description: Codable, Sendable {
    public let standard: String
  }
  
  public struct PlayParameters: Codable, Sendable {
    public let id: MusicItemID
    public let isLibrary: Bool
    public let globalID: MusicItemID?
    
    enum CodingKeys: String, CodingKey {
      case id, isLibrary
      case globalID = "globalId"
    }
  }
  
  public var globalID: String? {
    attributes.playParams.globalID?.rawValue
  }
}

public struct SearchResponse: Codable {
  public let results: SearchResults
}

public struct SearchResults: Codable {
  public let songs: SongsSearchResults
}

public struct SongsSearchResults: Codable {
  public let data: Array<SongResult>
}

public struct SongResult: Codable, MusicItem {
  public let id: MusicItemID
  public let type: String
  public let href: String
  public let attributes: Attributes
  
  public struct Attributes: Codable, Sendable {
    public let name: String
    public let albumName: String
    public let artistName: String
    public let url: String
  }
}

public struct TrackRequestData: Codable, MusicItem {
  public var id: MusicItemID
  public var type: String = "songs"
}

public struct AddTracksRequest: Codable {
  public var data: Array<TrackRequestData> = []
}
