//
//  ViewController.swift
//  PhotoCapture
//
//  Created by JIAWEI CHEN on 5/27/17.
//  Copyright © 2017 John. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class ViewController: UIViewController {
    fileprivate let sessionQueue = DispatchQueue(label: "Photo capture session queue")
    private let captureSession = AVCaptureSession()
    
    var capturePhotoOutput: AVCapturePhotoOutput!
    private var isCaptureSessionConfigured = false
    
    @IBOutlet weak var previewView: VideoPreviewView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.previewView.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
    }
    
    @IBAction func takePicture(_ sender: Any) {
        guard let capturePhotoOutput = self.capturePhotoOutput else {
            return
        }
        
        self.sessionQueue.async {[unowned self] in
            
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.flashMode = .off
            photoSettings.isAutoStillImageStabilizationEnabled = true
            photoSettings.isHighResolutionPhotoEnabled = true
            
            capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    // MARK Photo Sample Buffer
    fileprivate var photoSampleBuffer: CMSampleBuffer!
    fileprivate var previewPhotoSampleBuffer: CMSampleBuffer?
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        stopSession()
    }

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        startSession()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.previewView.updateVideoOrientationForDeviceOrientation()
        
        // also update photooutput connection video orientation
        self.sessionQueue.async {[unowned self] in
            guard let capturePhotoOutputConnection = self.capturePhotoOutput.connection(withMediaType: AVMediaTypeVideo) else {
                return
            }
            if let newVideoOrientation = VideoPreviewView.orientationMap[UIDevice.current.orientation] {
                capturePhotoOutputConnection.videoOrientation = newVideoOrientation
            }
        }
    }
    
    private func stopSession() {
        self.sessionQueue.async {[unowned self] in
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
    
    private func startSession() {
        if self.isCaptureSessionConfigured {
            self.sessionQueue.async {[unowned self] in
                self.captureSession.startRunning()
            }
            return
        }
        self.sessionQueue.async {
            // first time: request camera access
            self.checkCameraAuthorization({ authorized in
                guard authorized else {
                    print("permission to use camera denied.")
                    return
                }
                
                self.configureCaptureSession({ sucess in
                    guard sucess else { return }
                    self.isCaptureSessionConfigured = true
                    self.captureSession.startRunning()
                    DispatchQueue.main.async {
                        self.previewView.session = self.captureSession
                        self.previewView.updateVideoOrientationForDeviceOrientation()
                    }
                })
            })
        }
    }
    
    
    func configureCaptureSession(_ completionHandler: ((_ success: Bool) -> Void)) {
        var success = false
        defer { completionHandler(success)}
        
        let videoCaptureDevice = defaultDevice()
        
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            print("Unable to obtain video input from default camera.")
            return
        }
        
        let capturePhotoOutput = AVCapturePhotoOutput()
        capturePhotoOutput.isHighResolutionCaptureEnabled = true
        capturePhotoOutput.isLivePhotoCaptureEnabled = capturePhotoOutput.isLivePhotoCaptureSupported
        
        guard self.captureSession.canAddInput(videoInput) else {
            return
        }
        
        guard self.captureSession.canAddOutput(capturePhotoOutput) else {
            return
        }
        
        // Configure the session.
        self.captureSession.beginConfiguration()
        self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        self.captureSession.addInput(videoInput)
        self.captureSession.addOutput(capturePhotoOutput)
        self.captureSession.commitConfiguration()
        
        self.capturePhotoOutput = capturePhotoOutput
        
        success = true
    }
    
    func defaultDevice() -> AVCaptureDevice {
        if let device = AVCaptureDevice.defaultDevice(withDeviceType: AVCaptureDeviceType.builtInDualCamera, mediaType: AVMediaTypeVideo, position: .front) {
            return device
        }
        else if let device = AVCaptureDevice.defaultDevice(withDeviceType: AVCaptureDeviceType.builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front) {
            return device
        }
        else {
            fatalError("no device.")
        }
    }
    
    func checkPhotoLibraryAuthorization(_ completionHandler: @escaping ((_ authorized: Bool) -> Void)) {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            completionHandler(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ status in
                completionHandler(status == .authorized)
            })
        case .denied:
            completionHandler(false)
        case .restricted:
            completionHandler(false)
        }
    }
    
    func checkCameraAuthorization(_ completionHandler: @escaping ((_ authorized: Bool) -> Void)) {
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
        case .authorized:
            completionHandler(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (authorized) in
                completionHandler(authorized)
            })
        case .denied:
            completionHandler(false)
        case .restricted:
            completionHandler(false)
        }
    }
}


extension ViewController: AVCapturePhotoCaptureDelegate {
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        guard error == nil, let photoSampleBuffer = photoSampleBuffer else {
            print(error.debugDescription)
            return
        }
        
        self.photoSampleBuffer = photoSampleBuffer
        self.previewPhotoSampleBuffer = previewPhotoSampleBuffer
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        guard error == nil else {
            print("Error in capturing \(error.debugDescription)")
            return
        }
        
        self.sessionQueue.async {
            self.processPhoto()
        }

    }
    
    func processPhoto() {
        guard let jpegData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: self.photoSampleBuffer, previewPhotoSampleBuffer: self.previewPhotoSampleBuffer) else {
            print("Unable to create JPEG data.")
            return
        }
        
        self.checkPhotoLibraryAuthorization { authorized in
            guard authorized else {
                print("Permission to access photo library denied.")
                return
            }
            // Save photo to library.
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: jpegData, options: nil)
            }, completionHandler: { (success, error) in
                if success {
                    print("Added JPEG photo to library.")
                }
                else {
                    print("Error adding JPEG photo to library: \(error.debugDescription)")
                }
            })
        }
    }
}

