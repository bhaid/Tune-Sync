import Foundation
import SpotifyiOS
let accessTokenKey = "access-token-key"
let redirectUri = URL(string:"syncify://")!
let spotifyClientId = "c324e57356784d8a9808389ef629b11d"
let spotifyClientSecretKey = "66aa7b36e40f454aae411f48c28512fb"
var globalTimeVar: Double = 0
var parties: [PartyInfo] = []

/*
Scopes let you specify exactly what types of data your application wants to
access, and the set of scopes you pass in your call determines what access
permissions the user is asked to grant.
For more information, see https://developer.spotify.com/web-api/using-scopes/.
*/
let scopes: SPTScope = [
                            .userReadEmail, .userReadPrivate,
                            .userReadPlaybackState, .userModifyPlaybackState, .userReadCurrentlyPlaying,
                            .streaming, .appRemoteControl,
                            .playlistReadCollaborative, .playlistModifyPublic, .playlistReadPrivate, .playlistModifyPrivate,
                            .userLibraryModify, .userLibraryRead,
                            .userTopRead, .userReadPlaybackState, .userReadCurrentlyPlaying,
                            .userFollowRead, .userFollowModify,
                        ]
let stringScopes = [
                        "user-read-email", "user-read-private",
                        "user-read-playback-state", "user-modify-playback-state", "user-read-currently-playing",
                        "streaming", "app-remote-control",
                        "playlist-read-collaborative", "playlist-modify-public", "playlist-read-private", "playlist-modify-private",
                        "user-library-modify", "user-library-read",
                        "user-top-read", "user-read-playback-position", "user-read-recently-played",
                        "user-follow-read", "user-follow-modify",
                    ]

func generateQRCode(from string: String) -> UIImage? {
    let data = Data(string.utf8)
    let filter = CIFilter(name: "CIQRCodeGenerator")
    
    filter?.setValue(data, forKey: "inputMessage")
    let transform = CGAffineTransform(scaleX: 3, y: 3)
    
    if let output = filter?.outputImage?.transformed(by: transform) {
        return UIImage(ciImage: output)
    }
    
    return nil
}

func appendToRecentParties(newParty: String) {
    // Fetch the current array
    var recentParties = UserDefaults.standard.array(forKey: "recentParties") as? [String] ?? []
    // Append the new item
    recentParties.append(newParty)
    // Save the updated array back to UserDefaults
    UserDefaults.standard.set(recentParties, forKey: "recentParties")
}
func getRecentParties() -> [String] {
    // Retrieve and return the array
    return UserDefaults.standard.array(forKey: "recentParties") as? [String] ?? []
}
func clearRecentParties()
{
    UserDefaults.standard.removeObject(forKey: "recentParties")
}
func setPcGlobal(_ value: String) {
    UserDefaults.standard.set(value, forKey: "pcGlobal")
}
func getPcGlobal() -> String {
    return UserDefaults.standard.string(forKey: "pcGlobal") ?? ""
}
func downloadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let data = data {
            completion(UIImage(data: data))
        } else {
            completion(nil)
        }
    }
    task.resume()
}

struct PartyInfo {
    let name: String
    let imageUrl: String
    let code: String
    var image: UIImage? // Initially nil, will be set after the image is downloaded
}

