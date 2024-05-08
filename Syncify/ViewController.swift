//
//  ViewController.swift
//  Syncify
//
//  Created by Brendan Haidinger on 6/21/23.
//

import UIKit
import SafariServices

class ViewController: UIViewController {
    
    @IBOutlet weak var LoginButton: UIButton!
    
    @IBOutlet weak var rejoinButton: UIButton!
    @IBOutlet weak var JoinPartyButton: UIButton!
    @IBOutlet weak var CreatePartyButton: UIButton!
    @IBOutlet weak var RecentPartiesButton: UIButton!
    @IBOutlet weak var isConnectedLabel: UILabel!
    var isReturningFromSpotifyAuth = false
    var isPlayerStateSubscribed: Bool?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        SpotifyService.shared.ensureAccessTokenIsValid()
        SpotifyService.shared.refreshAccessToken { newAccessToken in
            if let newAccessToken = newAccessToken {
                print("Successfully refreshed access token: \(newAccessToken)")
            } else {
                
                print("Failed to refresh access token")
            }
        }
        SpotifyService.shared.appRemote.playerAPI?.subscribe(toPlayerState: { [weak self] result, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error subscribing to player state: \(error)")
                    self.isPlayerStateSubscribed = false
                } else {
                    print("Successfully subscribed to player state.")
                    self.isPlayerStateSubscribed = true
                }
            })
        var pcglobal = getPcGlobal()
        isReturningFromSpotifyAuth = false
        if pcglobal != ""{
            self.rejoinButton.isEnabled = true
        }
        else{
            self.rejoinButton.isEnabled = false
        }
        if !SpotifyService.shared.appRemote.isConnected{
            self.isConnectedLabel.text = "Connecting..."
            self.isConnectedLabel.textColor = UIColor.red
            self.CreatePartyButton.isEnabled = false
            self.JoinPartyButton.isEnabled = false
            self.rejoinButton.isEnabled = false
        }
        else
        {
            self.isConnectedLabel.text = "Connected"
            self.isConnectedLabel.textColor = UIColor.green
            self.CreatePartyButton.isEnabled = true
        }
        // Do any additional setup after loading the view.
        LoginButton.layer.cornerRadius = 15
        
        let delaySeconds = 2.0 // Delay in seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) {
            // Place the code you want to execute after the delay here
            if SpotifyService.shared.appRemote.isConnected{
                self.JoinPartyButton.isEnabled = true
                self.CreatePartyButton.isEnabled = true
                self.isConnectedLabel.text = "Connected"
                self.isConnectedLabel.textColor = UIColor.green
            }
            else
            {
                self.isReturningFromSpotifyAuth = true
                SpotifyService.shared.login()
                self.JoinPartyButton.isEnabled = true
                self.CreatePartyButton.isEnabled = true
                self.isConnectedLabel.text = "Connected"
                self.isConnectedLabel.textColor = UIColor.green
            }
            if pcglobal != ""{
                self.rejoinButton.isEnabled = true
            }
            else{
                self.rejoinButton.isEnabled = false
            }
            
            
        }
        loadPartyDetails()
    }
    override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            // Remove observer when the view is about to disappear
            NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    @objc func appWillEnterForeground() {
        print("------ VC Entered Foreground------")
        if !isReturningFromSpotifyAuth{
            viewDidLoad()
        }
    }
    @IBAction func loginButtonPressed(_ sender:UIButton)
    {
        SpotifyService.shared.login()
        JoinPartyButton.isEnabled = true
        CreatePartyButton.isEnabled = true
        
        
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Check the identifier to make sure it's the segue you want to handle
        var pcglobal = getPcGlobal()
        if segue.identifier == "RejoinSegue",
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
                        SpotifyService.shared.joinParty(withPartyCode: pcglobal) { error in
                            if let error = error {
                                print("Error occurred: \(error)")
                            } else {
                                print("Successfully started playing playlist")
                            }
                        }
                    }
                }
            }
        }
        if segue.identifier == "Join", let joinPartyViewController = segue.destination as? Party {
                joinPartyViewController.scanButtonTapped()
        }
                
    }
            
        
        
        // Add a property for synchronization
        let lock = NSLock()
        
        /*func loadImages() {
         let codes = UserDefaults.standard.array(forKey: "recentParties") as? [String] ?? []
         
         // Iterate through each code
         for (index, code) in codes.enumerated() {
         // Proceed only if the index is greater than or equal to the count of names or images
         // This checks if we have already loaded data for this code
         if index >= recentNames.count || index >= recentImages.count {
         DispatchQueue.global().async {
         SpotifyService.shared.getPlaylistDetails(from: code) { [weak self] (name, imageUrl) in
         guard let self = self else { return }
         DispatchQueue.main.async {
         // Lock to synchronize data update
         self.lock.lock()
         
         // Append name if not nil and not already added for this code
         if let name = name, index >= recentNames.count {
         recentNames.append(name)
         }
         
         // Proceed to download and append image if URL is valid and not already added
         if let imageUrl = imageUrl, let url = URL(string: imageUrl), index >= recentImages.count {
         downloadImage(from: url) { image in
         DispatchQueue.main.async {
         if let image = image {
         recentImages.append(image)
         // Reload TableView or perform necessary UI updates here
         }
         }
         }
         }
         
         self.lock.unlock() // Unlock after update
         }
         }
         }
         }
         }
         }
         */
        func loadPartyDetails() {
            let savedCodes = UserDefaults.standard.array(forKey: "recentParties") as? [String] ?? []
            
            for code in savedCodes {
                DispatchQueue.global().async {
                    SpotifyService.shared.getPlaylistDetails(from: code) { [weak self] (name, imageUrl, partyName) in
                        guard let self = self, let name = name, let partyName = partyName, let imageUrl = imageUrl else { return }
                        
                        let party = PartyInfo(name: partyName, imageUrl: imageUrl, code: code, image: nil)
                        
                        DispatchQueue.main.async {
                            if !parties.contains(where: { $0.code == code }) {
                                parties.append(party)
                            }
                            self.downloadImageWithParty(for: party)
                        }
                    }
                }
            }
            
        }
        func downloadImageWithParty(for party: PartyInfo) {
            guard let url = URL(string: party.imageUrl) else { return }
            
            let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data = data, let image = UIImage(data: data) else { return }
                
                DispatchQueue.main.async {
                    if let index = parties.firstIndex(where: { $0.code == party.code }) {
                        parties[index].image = image
                        let indexPath = IndexPath(row: index, section: 0)
                    }
                }
            }
            task.resume()
        }
        
    
    }
    
    
    

