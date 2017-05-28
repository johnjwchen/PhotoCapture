//
//  VideoPreviewView.swift
//  PhotoCapture
//
//  Created by JIAWEI CHEN on 5/27/17.
//  Copyright © 2017 John. All rights reserved.
//

import UIKit
import AVFoundation

class VideoPreviewView: UIView {
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    var session: AVCaptureSession? {
        get { return videoPreviewLayer.session }
        set { videoPreviewLayer.session = newValue }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    static let orientationMap: [UIDeviceOrientation : AVCaptureVideoOrientation] = [
        .portrait           : .portrait,
        .portraitUpsideDown : .portraitUpsideDown,
        .landscapeLeft      : .landscapeRight,
        .landscapeRight     : .landscapeLeft,
    ]
    
    func updateVideoOrientationForDeviceOrientation() {
        if let videoPreviewLayerConnection = videoPreviewLayer.connection {
            let deviceOrientation = UIDevice.current.orientation
            guard let newVideoOrientation = VideoPreviewView.orientationMap[deviceOrientation], deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
                return
            }
            videoPreviewLayerConnection.videoOrientation = newVideoOrientation
        }
    }

}
