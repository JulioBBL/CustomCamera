import UIKit
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var zoomBar: UIProgressView!
    
    var captureSession = AVCaptureSession()
    
    var backCamera: AVCaptureDevice?
    var frontCamera: AVCaptureDevice?
    var currentDevice: AVCaptureDevice? {
        didSet{
            captureSession.stopRunning()
            setupInputOutput()
            captureSession.startRunning()
        }
    }
    var photoOutput: AVCapturePhotoOutput?
    var cameraPreviewLayer:AVCaptureVideoPreviewLayer?
    
    var image: UIImage?
    
    var isFrontFacing = false {
        didSet{
            if self.isFrontFacing {
                self.currentDevice = self.frontCamera
            } else {
                self.currentDevice = self.backCamera
            }
        }
    }
    
    var scale = CGFloat(1)
    var minScale = CGFloat(1)
    var maxScale = CGFloat(5)

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCaptureSession()
        setupDevice()
        setupPreviewLayer()
        captureSession.startRunning()
        styleCaptureButton()
    }

    func setupCaptureSession() {
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
    }
    
    func setupDevice() {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
        let devices = deviceDiscoverySession.devices
        
        for device in devices {
            if device.position == AVCaptureDevice.Position.back {
                backCamera = device
            } else if device.position == AVCaptureDevice.Position.front {
                frontCamera = device
            }
        }
        currentDevice = backCamera
    }
    
    func setupInputOutput() {
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: currentDevice!)
            
            // if there are inputs already, remove them
            if let input = captureSession.inputs.first {
                captureSession.removeInput(input)
            }
            captureSession.addInput(captureDeviceInput)
            
            photoOutput = AVCapturePhotoOutput()
            photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
            
            // if there are outputs already, remove them
            if let output = captureSession.outputs.first {
                captureSession.removeOutput(output)
            }
            captureSession.addOutput(photoOutput!)
            
        } catch {
            print(error)
        }
    }
    
    func setupPreviewLayer() {
        self.cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.cameraPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.cameraPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        self.cameraPreviewLayer?.frame = view.frame
        self.view.layer.insertSublayer(self.cameraPreviewLayer!, at: 0)
    }
    
    @IBAction func cameraButton_TouchUpInside(_ sender: Any) {
        let settings = AVCapturePhotoSettings()
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
    }
    
    @IBAction func flipButton(_ sender: Any) {
        self.isFrontFacing = !self.isFrontFacing
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Preview_Segue" {
            let previewViewController = segue.destination as! PreviewViewController
            previewViewController.image = self.image
        }
    }
    
    @IBAction func didPinch(_ sender: UIPinchGestureRecognizer) {
        do{
            try currentDevice?.lockForConfiguration()
            switch sender.state {
            case .began:
                self.scale = (currentDevice?.videoZoomFactor)!
            case .changed:
                var factor = self.scale * sender.scale
                factor = max(1, min(factor, (currentDevice?.activeFormat.videoMaxZoomFactor)!))
                
                if factor > self.maxScale {
                    factor = self.maxScale
                }
                
                currentDevice?.videoZoomFactor = factor
                
                self.zoomBar.progress = Float((CGFloat(factor) - self.minScale)/(self.maxScale - self.minScale))
            default:
                break
            }
            
            currentDevice?.unlockForConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func styleCaptureButton() {
        cameraButton.layer.borderColor = UIColor.white.cgColor
        cameraButton.layer.borderWidth = 5
        cameraButton.clipsToBounds = true
        cameraButton.layer.cornerRadius = min(cameraButton.frame.width, cameraButton.frame.height) / 2
    }
}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation() {
            self.image = UIImage(data: imageData)
            performSegue(withIdentifier: "Preview_Segue", sender: nil)
        }
    }
}
