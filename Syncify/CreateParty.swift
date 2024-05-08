import UIKit
import SpotifyiOS

class CreateParty: UIViewController, UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate {
    var appRemote: SPTAppRemote?
    var playlistURI: String?
    var playlistName: String?
    var partyCode: String?
    var dataSource: [String] = []
    var dataSourceURIs: [String] = []
    var selectedPlaylistName: String = ""
    var selectedPlaylistURI: String = ""
    @IBOutlet weak var PartyName: UITextField!
    @IBOutlet weak var CreatePartyButton: UIButton!
    @IBOutlet weak var recentlyPlayed: UICollectionView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.isHidden=true
        textField.layer.cornerRadius = 0
        textField.delegate = self
        PartyName.delegate = self
        //textField.becomeFirstResponder()
        tableView.delegate = self
        tableView.dataSource = self
        CreatePartyButton.layer.cornerRadius = 15
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PlaylistCell")
        // Listen for changes in the text field's text
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        SpotifyService.shared.refreshAccessToken { newAccessToken in
            if let newAccessToken = newAccessToken {
                print("Successfully refreshed access token: \(newAccessToken)")
            } else {
                print("Failed to refresh access token")
            }
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var pcglobal = getPcGlobal()
        // Check the identifier to make sure it's the segue you want to handle
        if segue.identifier == "JoinPartySegue",
           // Cast the destination view controller to the specific class
           let joinPartyViewController = segue.destination as? Party {
            DispatchQueue.global().async {
                SpotifyService.shared.getPlaylistDetails(from: pcglobal) { (name, imageUrl, partyName) in
                    DispatchQueue.main.async {
                        if let name = name {
                            joinPartyViewController.PlaylistNameLabel.isHidden = false
                            joinPartyViewController.resyncButton.isHidden = false
                            joinPartyViewController.resyncButton.isEnabled = true
                            joinPartyViewController.QRCodeButton.isEnabled = true
                            joinPartyViewController.PlaylistNameLabel.text = name
                            joinPartyViewController.partyNameLabel.text = partyName
                            joinPartyViewController.partyCode = self.partyCode
                        }
                        
                        if let imageUrl = imageUrl, let url = URL(string: imageUrl) {
                            downloadImage(from: url) { image in
                                DispatchQueue.main.async {
                                    joinPartyViewController.imageView.image = image
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.isHidden = true
        textField.resignFirstResponder()
        print("Row \(indexPath.row) Selected")
        selectedPlaylistName = dataSource[indexPath.row]
        textField.text = selectedPlaylistName
        selectedPlaylistURI = dataSourceURIs[indexPath.row]// Retrieve the corresponding URI for the selected playlist
        
        // Call the existing code to create the party
        

    }
    
    @IBAction func createPartyPressed(_ sender: Any) {
        // Assuming selectedPlaylistName and selectedPlaylistURI are non-optionals
        if !selectedPlaylistName.isEmpty && !selectedPlaylistURI.isEmpty {
            // Only PartyName.text needs to be unwrapped as it's optional
            if let partyNameText = PartyName.text, !partyNameText.isEmpty {
                createParty(with: selectedPlaylistName, playlistURI: selectedPlaylistURI, partyName: partyNameText)
                performSegue(withIdentifier: "JoinPartySegue", sender: self)
            }
        }
    }


    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaylistCell", for: indexPath)
        let playlistName = dataSource[indexPath.row]
        cell.textLabel?.text = playlistName

        // Set default placeholder image
        cell.imageView?.image = UIImage(named: "Placeholder")

        // Set background color for the cell
        let customGreen = UIColor(red: 56/255, green: 196/255, blue: 92/255, alpha: 1.0)
        cell.backgroundColor = customGreen
        cell.textLabel?.font = UIFont(name: "Impact", size: 18)  // Example font

        // Attempt to load the playlist image
        let components = dataSourceURIs[indexPath.row].split(separator: ":")
        let playlistID = String(components.last!)
        SpotifyService.shared.getPlaylistImageURL(from: playlistID) { imageUrl in
                DispatchQueue.main.async {
                    if let updateCell = tableView.cellForRow(at: indexPath),
                       let imageUrl = imageUrl,
                       let url = URL(string: imageUrl),
                       let imageData = try? Data(contentsOf: url), // Fetch image data
                       let image = UIImage(data: imageData) { // Convert data to UIImage

                        updateCell.imageView?.image = image
                        updateCell.setNeedsLayout() // Refresh cell layout to display the image
                    }
                }
            }

        return cell
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == self.textField{
            tableView.isHidden = false
        }
        // Add any additional code to handle the search bar being focused
    }


    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()

            tableView.isHidden = true
            return true
        }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        guard let query = textField.text, !query.isEmpty else {
            // If the query is empty, you could hide the results, for example
            return
        }
        // This is where you'd call the function to search Spotify's API
        self.playlistName = query
        searchPlaylists(query)
    }
    
    func searchPlaylists(_ query: String) {
        // Ensure we have a valid access token
        guard let accessToken = SpotifyService.shared.accessToken else {
            print("Access token is nil")
            return
        }
        
        // Replace spaces with '+' for the URL
        let formattedQuery = query.replacingOccurrences(of: " ", with: "+")
        
        // Create the URL for the search API
        guard let url = URL(string: "https://api.spotify.com/v1/search?q=\(formattedQuery)&type=playlist&limit=5") else {
            print("Invalid url")
            return
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        // Make the request
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            // Handle the response here
            if let error = error {
                print("Error making request: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data returned")
                return
            }
            
            do {
                // Try to parse the data
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let playlists = json["playlists"] as? [String: Any],
                   let items = playlists["items"] as? [[String: Any]] {

                    let playlistNames = items.compactMap { $0["name"] as? String }
                    let playlistURIs = items.compactMap { $0["uri"] as? String }
                    
                    DispatchQueue.main.async {
                        // Update the data source for the table view
                        self.dataSource = playlistNames // Assuming dataSource is a property of your view controller
                        self.dataSourceURIs = playlistURIs
                        self.tableView.reloadData() // Refresh the table view
                        self.tableView.isHidden = false // Show the table view

                        if let index = playlistNames.firstIndex(of: query) {
                            // If exists, enable the create button and set the playlistURI to be used for playing
                            self.playlistURI = playlistURIs[index]
                        } else {
                            // If doesn't exist, disable the create button
                        }
                    }
                }
                else
                {
                    SpotifyService.shared.refreshAccessToken { newAccessToken in
                        if let newAccessToken = newAccessToken {
                            print("Successfully refreshed access token: \(newAccessToken)")
                        } else {
                            print("Failed to refresh access token")
                        }
                    }
                }
            } catch let parseError {
                print("Error parsing JSON: \(parseError)")
            }
        }
        task.resume()
    }
    
    func createParty(with playlistName: String, playlistURI: String, partyName: String) {
        var partyCode = ""
        let time = CFAbsoluteTimeGetCurrent() // epoch timestamp
        SpotifyService.shared.appRemote.playerAPI?.play(playlistURI)
        let safePlaylistName = playlistName.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        let safePartyName = partyName.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        partyCode = "\(safePartyName)-\(safePlaylistName)-\(playlistURI)-\(time)"
        setPcGlobal(partyCode)
        // Now you can use the partyCode
        print("Party Code: " + partyCode)

        self.partyCode = partyCode
        appendToRecentParties(newParty: partyCode)
    }

}




