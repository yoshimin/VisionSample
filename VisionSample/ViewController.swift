//
//  ViewController.swift
//  VisionSample
//
//  Created by Shingai Yoshimi
//  Copyright © 2017 yoshimi. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
    @IBOutlet var preview: UIView!
    
    let shapeLayer = CAShapeLayer()
    let videoQueue = DispatchQueue(label: "videoQueue")
    let mediaType: AVMediaType = .video
    
    var session: AVCaptureSession = AVCaptureSession()
    var devicePosition: AVCaptureDevice.Position = .front
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSession()
        setupPreview()
        setupShapeLayer()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = preview.bounds
        shapeLayer.frame = view.bounds
    }
}

extension ViewController {
    fileprivate func setupSession() {
        guard let device = findDevice(position: devicePosition),
            let input = try? AVCaptureDeviceInput(device: device) else {
                return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoQueue)
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        session.startRunning()
    }
    
    fileprivate func setupPreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        guard let previewLayer = previewLayer else {
            return
        }
        
        previewLayer.videoGravity = .resizeAspectFill
        preview.layer.addSublayer(previewLayer)
    }
    
    fileprivate func findDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: mediaType, position: position)
    }
    
    fileprivate func switchCameraPosition() {
        session.beginConfiguration()
        
        if let currentInput = session.inputs.first {
            session.removeInput(currentInput)
        }
        
        switch devicePosition {
        case .front:
            devicePosition = .back
        case .back, .unspecified:
            devicePosition = .front
        }
        
        if let newDevice = findDevice(position: devicePosition),
            let newInput = try? AVCaptureDeviceInput(device: newDevice),
            session.canAddInput(newInput) {
            session.addInput(newInput)
        }
        
        session.commitConfiguration()
    }
    
    fileprivate func setupShapeLayer() {
        view.layer.addSublayer(shapeLayer)
    }
}

extension ViewController {
    @IBAction func flipCamera(_ sender: Any) {
        switchCameraPosition()
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
        }
        
        let request = VNDetectFaceRectanglesRequest { [weak self] (request, error) in
            DispatchQueue.main.async {
                self?.shapeLayer.sublayers?.removeAll()
                for observation in request.results as! [VNFaceObservation] {
                    self?.drawFrame(observation: observation)
                }
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
    
    func drawFrame(observation: VNFaceObservation) {
        guard let previewLayer = previewLayer else {
            return
        }
        
        var box = observation.boundingBox
        box.origin.y = 1 - observation.boundingBox.maxY
        
        let rect = previewLayer.layerRectConverted(fromMetadataOutputRect: box)
        
        let newLayer = CAShapeLayer()
        newLayer.strokeColor = UIColor.red.cgColor
        newLayer.lineWidth = 2.0
        newLayer.fillColor = UIColor.clear.cgColor
        
        let path = UIBezierPath(rect: rect)
        newLayer.path = path.cgPath
        
        shapeLayer.addSublayer(newLayer)
    }
    
    func removeFrames() {
        for (_, view) in preview.subviews.enumerated() {
            view.removeFromSuperview()
        }
    }
}
