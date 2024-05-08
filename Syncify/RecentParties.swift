import Foundation
import UIKit
import SpotifyiOS

class RecentParties: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    
    var appRemote: SPTAppRemote?
    var playlistURI: String?
    var playlistName: String?
    var partyCode: String?
    
    
    @IBOutlet weak var TableView: UITableView!
    @IBOutlet weak var clearHistory: UIButton!
    
    override func viewDidLoad() {
        reorderPartiesBasedOnTimestamp()
        super.viewDidLoad()
        TableView.dataSource = self
        TableView.delegate = self
        clearHistory.layer.cornerRadius = 15
        // Load data into dataSource, for example, from UserDefaults
        TableView.register(UITableViewCell.self, forCellReuseIdentifier: "PartyCell")
        TableView.isHidden = false
        TableView.reloadData()
    }
    
    
    // MARK: - UITableViewDataSource Methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return parties.count
    }
    
    @IBAction func clearHistoryPressed(_ sender: Any) {
        clearRecentParties()
        parties.removeAll()
        TableView.reloadData()
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PartyCell", for: indexPath)
        let reversedIndex = parties.count - 1 - indexPath.row
        let party = parties[reversedIndex]
        
        cell.textLabel?.text = party.name
        cell.imageView?.image = party.image
        cell.textLabel?.font = UIFont(name: "Impact", size: 18)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.isHidden = true
        let reversedIndex = parties.count - 1 - indexPath.row
        let selectedParty = parties[reversedIndex]
        let selectedPlaylistName = selectedParty.name
        let selectedCode = selectedParty.code
        setPcGlobal(selectedCode)
        
        // Call the existing code to create the party
        SpotifyService.shared.joinParty(withPartyCode: selectedCode) { error in
            if let error = error {
                print("Error occurred: \(error)")
            } else {
                print("Successfully started playing playlist")
            }
        }
            performSegue(withIdentifier: "RecentPartySegue", sender: self)
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var pcglobal = getPcGlobal()
        // Check the identifier to make sure it's the segue you want to handle
        if segue.identifier == "RecentPartySegue",
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
                            joinPartyViewController.partyCode = pcglobal
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
    func reorderPartiesBasedOnTimestamp() {
        parties.sort { firstParty, secondParty in
            guard let firstDetails = SpotifyService.shared.partyCodeConvert(fromPartyCode: firstParty.code),
                  let secondDetails = SpotifyService.shared.partyCodeConvert(fromPartyCode: secondParty.code) else {
                return false
            }
            return firstDetails.timestamp < secondDetails.timestamp
        }
    }

     
}
