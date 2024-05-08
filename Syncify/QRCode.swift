import Foundation
import UIKit
class QRCode: UIViewController {
    // Assuming pcGlobal is a global variable containing the QR code content
    // and qrCodeImageView is an IBOutlet connected to an image view in your storyboard or nib
    var partyCode: String?
    @IBOutlet weak var qrCodeImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let qrCodeImage = generateQRCode(from: partyCode!)
        qrCodeImageView.image = qrCodeImage
    }
    
    // Example function to generate a QR code from a given string
    
}
