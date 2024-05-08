import AVFoundation
import UIKit

class Party: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet weak var resyncButton: UIButton!
    @IBOutlet weak var PlaylistNameLabel: UILabel!
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var scannedCodeLabel: UILabel!
    @IBOutlet weak var QRCodeButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var partyNameLabel: UILabel!
    let backButton = UIButton(frame: CGRect(x: 20, y: 40, width: 80, height: 40))
    var partyCode: String?
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var isPlayerStateSubscribed: Bool?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        print("-----VIEW DID LOAD------")
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        scanButton.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        backButton.isHidden = true
        if partyCode == nil{
            QRCodeButton.isEnabled = false
        }
        PlaylistNameLabel.isHidden = true
        PlaylistNameLabel.layer.cornerRadius = 15
        resyncButton.isEnabled = false
        
    }
    override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if (captureSession?.isRunning == true) {
                captureSession.stopRunning()
            }
            // Remove observer when the view is about to disappear
            NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        }
    @objc func appWillEnterForeground() {
        print("------ Party Entered Foreground------")
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
        if let partyCode = self.partyCode{
            SpotifyService.shared.joinParty(withPartyCode: partyCode) { error in
                if let error = error {
                    print("Error occurred: \(error)")
                } else {
                    print("Successfully started playing playlist")
                }
            }
        }
    }
    func deactivate() {
        PlaylistNameLabel.isHidden = true
        imageView.isHidden = true
        partyNameLabel.isHidden = true
        resyncButton.isEnabled = false
        QRCodeButton.isEnabled = false
        scanButton.isEnabled = false
    }
    func activate() {
        PlaylistNameLabel.isHidden = false
        imageView.isHidden = false
        partyNameLabel.isHidden = false
        resyncButton.isEnabled = true
        QRCodeButton.isEnabled = true
        scanButton.isEnabled = true
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    @objc func scanButtonTapped() {
        startScanning()
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Check the identifier to make sure it's the segue you want to handle
        if segue.identifier == "QRCodeSegue",
           // Cast the destination view controller to the specific class
           let QRCodeViewController = segue.destination as? QRCode {
            QRCodeViewController.partyCode = self.partyCode!
        }
        
    }
    
    func startScanning() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            failed()
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        captureSession.startRunning()
        addBackButton()
    }
    private func addBackButton() {
        backButton.isHidden = false
        backButton.isEnabled = true
        backButton.setTitle("Back", for: .normal)
        backButton.backgroundColor = .systemBlue
        backButton.layer.cornerRadius = 5
        backButton.addTarget(self, action: #selector(backButtonPressed), for: .touchUpInside)
        view.addSubview(backButton)
        view.bringSubviewToFront(backButton) // Ensure button is on top of all other subviews
    }
    @objc func backButtonPressed() {
        SpotifyService.shared.appRemote.playerAPI?.pause()
        backButton.isHidden = true
        captureSession.stopRunning()
        self.previewLayer.removeFromSuperlayer()
    }
    
    
    
    @IBAction func resyncButtonPressed(_ sender: UIButton) {
        // Schedule the joining logic to run at the beginning of the next second
        print(partyCode)
        print(SpotifyService.shared.appRemote.isConnected)
        if let partyCode = self.partyCode {
            SpotifyService.shared.joinParty(withPartyCode: partyCode) { error in
                if let error = error {
                    print("Error occurred: \(error)")
                } else {
                    print("Successfully started playing playlist")
                }
            }
        } else
        {
            print("---Failed---")
            return
        }
        
    }
     
    
    func failed() {
        let alert = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
        captureSession = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if (captureSession?.isRunning == false) {
            captureSession.startRunning()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("-----VIEW DID APPEAR------")
    }

    
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        self.previewLayer.removeFromSuperlayer()
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            found(code: stringValue)
        }
        
        //dismiss(animated: true)
    }
    
    func found(code: String) {
        partyCode = code
        setPcGlobal(code)
        appendToRecentParties(newParty: code)
        // Stop the capture session
        resyncButton.isEnabled = true
        backButton.isHidden = true
        // Extract the playlist name from the code
        let components = code.components(separatedBy: "-")
        let playlistNameComponent = components.first ?? ""
        let playlistName = playlistNameComponent.replacingOccurrences(of: "Optional(\"", with: "").replacingOccurrences(of: "\")", with: "")
        DispatchQueue.global().async {
            SpotifyService.shared.getPlaylistDetails(from: code) { (name, imageUrl, partyName) in
                DispatchQueue.main.async {
                    if let name = name {
                        self.PlaylistNameLabel.isHidden = false
                        self.resyncButton.isHidden = false
                        self.QRCodeButton.isEnabled = true
                        self.PlaylistNameLabel.text = name
                        self.partyNameLabel.text = partyName
                    }
                    
                    if let imageUrl = imageUrl, let url = URL(string: imageUrl) {
                        downloadImage(from: url) { image in
                            DispatchQueue.main.async {
                                self.imageView.image = image
                            }
                        }
                    }
                }
            }
        }
        if let partyCode = self.partyCode {
            SpotifyService.shared.joinParty(withPartyCode: partyCode) { error in
                if let error = error {
                    print("Error occurred: \(error)")
                } else {
                    print("Successfully started playing playlist")
                }
            }
        } else
        {
            return
        }
    }


    

    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
