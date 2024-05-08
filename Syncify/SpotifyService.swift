import UIKit
import SpotifyiOS
class SpotifyService: NSObject {
    static let shared = SpotifyService()
    // MARK: - Spotify Authorization & Configuration
    var responseCode: String? {
        didSet {
            fetchAccessToken { (dictionary, error) in
                if let error = error {
                    print("Fetching token request error \(error)")
                    return
                }
                let accessToken = dictionary!["access_token"] as! String
                DispatchQueue.main.async {
                    self.accessToken = accessToken
                    self.appRemote.connectionParameters.accessToken = accessToken
                    self.appRemote.connect()
                }
            }
            
        }
    }

    lazy var appRemote: SPTAppRemote = {
        let appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        appRemote.connectionParameters.accessToken = self.accessToken
        appRemote.delegate = self
        return appRemote
    }()
    
    
    var accessToken: String? {
        get {
            return UserDefaults.standard.string(forKey: accessTokenKey)
        }
        set {
            if let newToken = newValue {
                UserDefaults.standard.set(newToken, forKey: accessTokenKey)
            }
        }
    }
    
    var refreshToken: String? {
            get { return UserDefaults.standard.string(forKey: "SpotifyRefreshToken") }
            set { UserDefaults.standard.set(newValue, forKey: "SpotifyRefreshToken") }
        }

    lazy var configuration: SPTConfiguration = {
        let configuration = SPTConfiguration(clientID: spotifyClientId, redirectURL: redirectUri)
        // Set the playURI to a non-nil value so that Spotify plays music after authenticating
        // otherwise another app switch will be required
        configuration.playURI = ""
        // Set these url's to your backend which contains the secret to exchange for an access token
        // You can use the provided ruby script spotify_token_swap.rb for testing purposes
        configuration.tokenSwapURL = URL(string: "http://localhost:1234/swap")
        configuration.tokenRefreshURL = URL(string: "http://localhost:1234/refresh")
        return configuration
    }()

    lazy var sessionManager: SPTSessionManager? = {
        let manager = SPTSessionManager(configuration: configuration, delegate: self)
        return manager
    }()

    private var lastPlayerState: SPTAppRemotePlayerState?


    // MARK: - Actions

    func login() {
        guard let sessionManager = sessionManager else { return }
        sessionManager.initiateSession(with: scopes, options: .clientOnly)
        appRemote.connectionParameters.accessToken = accessToken
        appRemote.connect()
        appRemote.playerAPI?.setShuffle(false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.appRemote.playerAPI?.pause()
        }
        
    }
    
    //MARK: Helper Methods
    func getPlaylistDuration(for playlistURI: String, completion: @escaping (Double?, Error?) -> Void) {
        guard let decodedUri = playlistURI.removingPercentEncoding else {
            return
        }

        let uriComponents = decodedUri.split(separator: ":")
        let playlistId = String(uriComponents.last ?? "")

        guard let url = URL(string: "https://api.spotify.com/v1/playlists/\(playlistId)/tracks") else {

            completion(nil, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey : "Invalid URL"]))
            return
        }
        var request = URLRequest(url: url)
        guard let validToken = accessToken else {
            print("No valid access token")
            return
        }
        request.addValue("Bearer \(validToken)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
            } else if let data = data {
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any]
                    let items = json?["items"] as? [[String: Any]]
                    var totalDuration = 0.0 // Change this to a Double

                    items?.forEach { item in
                        let track = item["track"] as? [String: Any]
                        let durationMs = track?["duration_ms"] as? Int ?? 0
                        
                        
                        totalDuration += Double(durationMs)
                    }
                    completion(totalDuration, nil)

                } catch {
                    completion(nil, error)
                }
            }
        }

        task.resume()
    }
    func findTrackIndex(for positionMs: Int, with durations: [Int]) -> (trackIndex: Int, trackPositionMs: Int) {
        var totalMs = 0
        var index = 0

        for duration in durations {
            totalMs += duration
            if totalMs > positionMs {
                break
            }
            index += 1
        }

        let trackPositionMs = positionMs - (totalMs - durations[index])
        
        return (index, trackPositionMs)
    }


    func getTrackDurations(for playlistId: String, completion: @escaping ([Int]?, Error?) -> Void) {
        // Extract the playlistId from the playlistUri
        let url = URL(string: "https://api.spotify.com/v1/playlists/\(playlistId)/tracks")!
        var request = URLRequest(url: url)
        guard let validToken = accessToken else {
            print("No valid access token")
            return
        }
        request.addValue("Bearer \(validToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
            } else if let data = data {
                do {
                    // Convert to String and print out the raw JSON
                    let jsonString = String(data: data, encoding: .utf8)
                    //print("JSON string is: \(jsonString ?? "nil")")
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    let items = json?["items"] as? [[String: Any]]
                    var durations = [Int]()

                    items?.forEach { item in
                        let track = item["track"] as? [String: Any]
                        if let durationMs = track?["duration_ms"] as? Int {
                            durations.append(durationMs)
                        }
                    }
                    completion(durations, nil)
                } catch let parseError {
                    completion(nil, parseError)
                }
            } else {
                completion(nil, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
            }
        }.resume()

    }

    
    /*    func getPlaylistDetails(from code: String, completion: @escaping (String?, String?) -> Void) {
            // Split the URI to extract the playlist ID and timestamp
            let splitURI = code.split(separator: "-")
            guard splitURI.count == 3,
                  let playlistURIPart = splitURI[1].removingPercentEncoding,
                  let playlistId = playlistURIPart.split(separator: ":").last else {
                print("Unable to extract playlistId from uri: \(uri)") // debug line
                completion(nil, nil)
                return
            }
    
            let url = URL(string: "https://api.spotify.com/v1/playlists/\(playlistId)")!
            var request = URLRequest(url: url)
            request.addValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error occurred during URLSession: \(error)") // debug line
                    completion(nil, nil)
                } else if let data = data {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                            let name = json["name"] as? String
                            let images = json["images"] as? [[String: Any]]
                            let imageUrl = images?.first?["url"] as? String
    
                            completion(name, imageUrl)
                        }
                    } catch {
                        completion(nil, nil)
                    }
                } else {
                    print("No data received from URLSession") // debug line
                    completion(nil, nil)
                }
            }
            task.resume()
        }
    */
    func getPlaylistDetails(from code: String, completion: @escaping (String?, String?, String?) -> Void) {
        // Utilize partyCodeConvert to extract the playlist ID
        guard let conversionResult = partyCodeConvert(fromPartyCode: code) else {
            print("Unable to extract playlistId from code: \(code)")
            completion(nil, nil, nil)
            return
        }
        let playlistId = conversionResult.playlistId
        let partyName = conversionResult.name
        // Now that we have the playlistId, proceed to fetch its details
        guard let accessToken = SpotifyService.shared.accessToken else {
            print("Access Token is nil")
            completion(nil, nil, nil)
            return
        }
        
        let url = URL(string: "https://api.spotify.com/v1/playlists/\(playlistId)")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error occurred during URLSession: \(error)") // debug line
                completion(nil, nil, nil)
            } else if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        let name = json["name"] as? String
                        let images = json["images"] as? [[String: Any]]
                        let imageUrl = images?.first?["url"] as? String

                        completion(name, imageUrl, partyName)
                    }
                } catch {
                    print("Error during JSON parsing: \(error)")
                    completion(nil, nil, nil)
                }
            } else {
                print("No data received from URLSession")
                completion(nil, nil, nil)
            }
        }
        task.resume()
    }
    func getPlaylistImageURL(from playlistId: String, completion: @escaping (String?) -> Void) {

        // Now that we have the playlistId, proceed to fetch its details
        guard let accessToken = SpotifyService.shared.accessToken else {
            print("Access Token is nil")
            completion(nil)
            return
        }
        
        let url = URL(string: "https://api.spotify.com/v1/playlists/\(playlistId)")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error occurred during URLSession: \(error)") // debug line
                completion(nil)
            } else if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        let images = json["images"] as? [[String: Any]]
                        let imageUrl = images?.first?["url"] as? String

                        completion(imageUrl)
                    }
                } catch {
                    print("Error during JSON parsing: \(error)")
                    completion(nil)
                }
            } else {
                print("No data received from URLSession")
                completion(nil)
            }
        }
        task.resume()
    }

    func partyCodeConvert(fromPartyCode partyCode: String) -> (playlistId: String, timestamp: Double, name: String)? {
        let splitCode = partyCode.split(separator: "-")
        // Expecting at least 4 components now: [name, playlistName, playlistURI, timestamp]
        guard splitCode.count >= 4,
              let decodedName = splitCode[0].removingPercentEncoding,
              let fullPlaylistId = splitCode[2].addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
              let decodedPlaylistId = fullPlaylistId.removingPercentEncoding else {
            print("Invalid party code")
            return nil
        }

        let parts = decodedPlaylistId.split(separator: ":")
        guard parts.count == 3 else {
            print("Invalid playlist id format")
            return nil
        }

        let playlistId = String(parts[2])
        
        // Convert the Unix timestamp string to a Double
        let timestampString = String(splitCode[3]) // Adjusted index for timestamp
        guard let timestamp = Double(timestampString) else {
            print("Unable to convert timestampString to Double")
            return nil
        }
        
        // Return the name along with playlistId and timestamp
        return (playlistId, timestamp, decodedName)
    }

    //MARK: Playback
    func playTrackAtIndex(_ index: Int, positionMs: Int, fromPlaylist playlistId: String) {
        // Construct the URI for the playlist
        let playlistUri = "spotify:playlist:\(playlistId)"
        // Play the playlist
        appRemote.playerAPI?.play(playlistUri, callback: { [weak self] (result, error) in
            if let error = error {
                //print("Error occurred while playing: \(error.localizedDescription)")
                return
            }
            // Skip to the desired track
            
            let dispatchGroup = DispatchGroup()
            //self?.appRemote.playerAPI?.setShuffle(false)
            for _ in 0..<index {
                dispatchGroup.enter()
                self?.appRemote.playerAPI?.skip(toNext: { (result, error) in
                    if let error = error {
                        //print("Error occurred while skipping to next track: \(error.localizedDescription)")
                    }
                    dispatchGroup.leave()
                })
            }

            dispatchGroup.notify(queue: .main) {
                let currentTime =  CFAbsoluteTimeGetCurrent()
                let elapsedSecondsBetweenFunctions = currentTime - globalTimeVar
                let elapsedMillisecondsBetweenFunctions = elapsedSecondsBetweenFunctions * 1000
                let newPositionMs = positionMs+Int(elapsedMillisecondsBetweenFunctions)
                self?.appRemote.playerAPI?.seek(toPosition: Int(newPositionMs), callback: { (result, error) in
                    if let error = error {
                        //print("Error occurred while seeking: \(error.localizedDescription)")
                    } else {
                        self?.appRemote.playerAPI?.resume(nil)
                    }
                })
            }
        })
    }


    func joinParty(withPartyCode partyCode: String, completion: @escaping (Error?) -> Void) {
        //appRemote.playerAPI?.setShuffle(false)
        let startTime = CFAbsoluteTimeGetCurrent()
        print("Start time: \(startTime)")
        guard let details = partyCodeConvert(fromPartyCode: partyCode) else {
            completion(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey : "Unable to extract playlist ID and timestamp"]))
            return
        }
        getPlaylistDuration(for: String(details.playlistId)) { (playlistDuration, error) in
                if let error = error {
                    completion(error)
                }
                
                guard let playlistDuration = playlistDuration else {
                    completion(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey : "Could not get playlist duration"]))
                    return
                }
                
                // Get the current time
            let currentTime = CFAbsoluteTimeGetCurrent()
            globalTimeVar = currentTime
            print ("Date(): \(currentTime)")
            print ("Details.timestamp: \(details.timestamp)")
            let differenceInSeconds = currentTime - details.timestamp
            let differenceInMilliseconds = Int(differenceInSeconds * 1000)
            
                
            // Find the starting point in the playlist
            guard playlistDuration != 0 else {
                print("Error: playlist duration is zero")
                completion(error) // Replace Error with an actual error object or type you have defined
                return
            }
            let startingPoint = differenceInMilliseconds % Int(playlistDuration)
                
            self.startPlayback(at: startingPoint, for: details.playlistId)
            }
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Calculate the elapsed time in milliseconds
        let elapsedTimeInMilliseconds = (endTime - startTime) * 1000
        
        // Print the elapsed time
        ("Elapsed time in milliseconds: \(elapsedTimeInMilliseconds)")
        }



            // This function handles seeking and starting the playback
    private func startPlayback(at positionMs: Int, for playlistId: String) {
        let playlistUri = "spotify:playlist:\(playlistId)"
/*
            // Request the player API to play the playlist
            appRemote.playerAPI?.play(playlistUri, callback: { (result, error) in
                if let error = error {
                    print("Error occurred while playing: \(error.localizedDescription)")
                }
            })
 */
        self.getTrackDurations(for: playlistId) { durations, error in
                if let error = error {
                } else if let durations = durations {
                    let trackDetails = self.findTrackIndex(for: positionMs, with: durations)
                    
                    self.playTrackAtIndex(trackDetails.trackIndex, positionMs: trackDetails.trackPositionMs, fromPlaylist: playlistId)

                }
            }
        
            }

}


// MARK: - SPTAppRemoteDelegate
extension SpotifyService: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { (success, error) in
            if let error = error {
                print("Error subscribing to player state:" + error.localizedDescription)
            }
        })
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        lastPlayerState = nil
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        lastPlayerState = nil
    }
}

// MARK: - SPTAppRemotePlayerAPIDelegate
extension SpotifyService: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        debugPrint("Spotify Track name: %@", playerState.track.name)
    }
}

// MARK: - SPTSessionManagerDelegate
extension SpotifyService: SPTSessionManagerDelegate {
    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        if error.localizedDescription == "The operation couldn’t be completed. (com.spotify.sdk.login error 1.)" {
            print("AUTHENTICATE with WEBAPI")
        }
    }

    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        appRemote.connectionParameters.accessToken = session.accessToken
        appRemote.connect()
    }
}

// MARK: - Networking
extension SpotifyService {

    func fetchAccessToken(completion: @escaping ([String: Any]?, Error?) -> Void) {
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let spotifyAuthKey = "Basic \((spotifyClientId + ":" + spotifyClientSecretKey).data(using: .utf8)!.base64EncodedString())"
        request.allHTTPHeaderFields = ["Authorization": spotifyAuthKey,
                                       "Content-Type": "application/x-www-form-urlencoded"]

        var requestBodyComponents = URLComponents()
        let scopeAsString = stringScopes.joined(separator: " ")

        requestBodyComponents.queryItems = [
            URLQueryItem(name: "client_id", value: spotifyClientId),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: responseCode!),
            URLQueryItem(name: "redirect_uri", value: redirectUri.absoluteString),
            URLQueryItem(name: "code_verifier", value: ""), // not currently used
            URLQueryItem(name: "scope", value: scopeAsString),
        ]

        request.httpBody = requestBodyComponents.query?.data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,                              // is there data
                  let response = response as? HTTPURLResponse,  // is there HTTP response
                  (200 ..< 300) ~= response.statusCode,         // is statusCode 2XX
                  error == nil else {                           // was there no error, otherwise ...
                      print("Error fetching token \(error?.localizedDescription ?? "")")
                      completion(nil, error)
                      return
                  }
            if let responseObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Save accessToken and refreshToken if available
                if let accessToken = responseObject["access_token"] as? String,
                   let expiresIn = responseObject["expires_in"] as? TimeInterval { // Spotify provides expiresIn in seconds
                    let expiryDate = Date().addingTimeInterval(expiresIn)
                    UserDefaults.standard.set(expiryDate.timeIntervalSince1970, forKey: "accessTokenExpiry")
                    UserDefaults.standard.set(accessToken, forKey: "accessToken")
                    // Optionally, save the refresh token if available
                    if let refreshToken = responseObject["refresh_token"] as? String {
                        UserDefaults.standard.set(refreshToken, forKey: "SpotifyRefreshToken")
                    }
                }
                completion(responseObject, nil)
            } else {
                completion(nil, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
            }
        }
        task.resume()
    }

    func refreshAccessToken(completion: @escaping (String?) -> Void) {
        guard let refreshToken = self.refreshToken, let url = URL(string: "https://accounts.spotify.com/api/token") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParameters = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=\(spotifyClientId)&client_secret=\(spotifyClientSecretKey)"
        request.httpBody = bodyParameters.data(using: String.Encoding.utf8)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let accessToken = json["access_token"] as? String,
               let expiresIn = json["expires_in"] as? TimeInterval {
                // Update the accessToken in UserDefaults
                UserDefaults.standard.set(accessToken, forKey: "accessToken")
                // Update the expiry date
                let expiryDate = Date().addingTimeInterval(expiresIn)
                UserDefaults.standard.set(expiryDate.timeIntervalSince1970, forKey: "accessTokenExpiry")
                completion(accessToken)
            } else {
                completion(nil)
            }
        }
        task.resume()
    }

    func ensureAccessTokenIsValid() {
        // Check if the accessToken is valid
        if isAccessTokenValid() {
            // The access token is valid, proceed with completion handler
        } else {
            // The access token is not valid, refresh it
            refreshAccessToken { [weak self] newAccessToken in
                if let newAccessToken = newAccessToken {
                    // Successfully refreshed the access token
                    // Update the appRemote with the new access token
                    self?.appRemote.connectionParameters.accessToken = newAccessToken
                    // Proceed with completion handler indicating success
                }
            }
        }
    }

    func isAccessTokenValid() -> Bool {
        // Retrieve the expiry timestamp from UserDefaults
        let expiryTimestamp = UserDefaults.standard.double(forKey: "accessTokenExpiry")
        
        // Check if a value was actually set (it returns 0.0 if not)
        if expiryTimestamp > 0 {
            let currentTimestamp = Date().timeIntervalSince1970
            // Consider the token as invalid a bit before its actual expiry to account for any requests in flight
            let buffer = 300.0 // 5 minutes buffer
            return (expiryTimestamp - buffer) > currentTimestamp
        } else {
            // No expiry timestamp was found, so assume the token is not valid
            return false
        }
    }
    


}
