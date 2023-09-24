//
//  ViewController.swift
//  Speech to Text - IOS
//
//  Created by Siti Hafsah on 19/09/23.
//

import UIKit
import Speech
import NaturalLanguage
import AVFoundation


class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    
    @IBOutlet weak var startStopBtn: UIButton!
    @IBOutlet weak var segmentDetectLanguage: UISegmentedControl!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var audioWaveView: UIView!
    
    // MARK: - Speech Recognition Properties
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "id-ID"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    var lang: String = "id-ID"
    
    // MARK: - Audio Wave Visualization Properties
    var audioWaveLayer: CAShapeLayer?
    var audioWavePath = UIBezierPath()
    var audioWaveColor = UIColor.red.cgColor
    var audioWaveLineWidth: CGFloat = 2.0
    private var lastAudioReceivedTime: Date? = nil
    // Adjust this threshold as needed
    private let silenceThreshold: Float = 0.1
    // Adjust this threshold as needed
    private let silenceThresholdSeconds: TimeInterval = 1.0
    var isAudioInputReceived = false
    private var isRecording = false
    var animationLayer: CALayer?
    
    
    
    // MARK: - viewdidload
    override func viewDidLoad() {
        super.viewDidLoad()
        // Disable the start/stop button initially
        startStopBtn.isEnabled = false
        // Set the speech recognizer's delegate and initial locale
        speechRecognizer?.delegate = self
        speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: lang))
        
        // Request authorization for speech recognition
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            var isButtonEnabled = false
            switch authStatus {
            case .authorized:
                isButtonEnabled = true
            case .denied:
                isButtonEnabled = false
                print("User denied access to speech recognition")
            case .restricted:
                isButtonEnabled = false
                print("Speech recognition restricted on this device")
            case .notDetermined:
                isButtonEnabled = false
                print("Speech recognition not yet authorized")
            @unknown default:
                print("Unknown authorization status")
            }
            OperationQueue.main.addOperation() {
                self.startStopBtn.isEnabled = isButtonEnabled
            }
        }
        
        // Initialize the audio wave visualization layer
        audioWaveLayer = CAShapeLayer()
        audioWaveLayer?.frame = audioWaveView.bounds
        audioWaveLayer?.lineWidth = audioWaveLineWidth
        audioWaveLayer?.strokeColor = audioWaveColor
        audioWaveLayer?.fillColor = UIColor.clear.cgColor
        audioWaveView.layer.addSublayer(audioWaveLayer!)
        
        // Initialize the animation layer
        animationLayer = CALayer()
        animationLayer?.frame = audioWaveView.bounds
        audioWaveView.layer.addSublayer(animationLayer!)
    }
    
    // MARK: - Language Selection Action
    @IBAction func segmentLanguageAct(_ sender: Any) {
        switch segmentDetectLanguage.selectedSegmentIndex {
        case 0:
            lang = "id-ID"
        case 1:
            lang = "en-US"
        default:
            lang = "id-ID"
        }
        speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: lang))
    }
    
    // MARK: - Start/Stop Button Action
    @IBAction func startStopBtnAct(_ sender: Any) {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.record)
            try audioSession.setMode(AVAudioSession.Mode.measurement)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            var isFinal = false
            
            if result != nil {
                if let resultText = result?.bestTranscription.formattedString {
                    let languageIdentifier = NLLanguageRecognizer.dominantLanguage(for: resultText)
                    if let languageCode = languageIdentifier?.rawValue {
                        if languageCode == "id" {
                            print("Indonesian Language")
                        } else if languageCode == "en" {
                            print("English Language")
                        }
                    }
                    self.textView.text = resultText
                }
                
                isFinal = (result?.isFinal)!
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.startStopBtn.isEnabled = true
            }
        })
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
            self.isAudioInputReceived = true
            self.updateAudioWave(withBuffer: buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
        isRecording = true
        startStopBtn.setTitle("Stop", for: .normal)
        textView.text = "Please say something"
    }
    
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            startStopBtn.isEnabled = false
            startStopBtn.setTitle("Start", for: .normal)
            isRecording = false
            self.audioWavePath.removeAllPoints()
            self.audioWaveLayer?.removeFromSuperlayer()
            self.animationLayer?.removeFromSuperlayer()
        }
    }
    
    func updateAudioWave(withBuffer buffer: AVAudioPCMBuffer) {
        DispatchQueue.main.async {
            // Extract audio data from the buffer.
            let bufferData = buffer.floatChannelData?[0]
            let bufferSize = UInt(buffer.frameLength)
            var maxAmplitude: Float = 0.0

            // Iterate through the audio data to find the maximum amplitude.
            for i in 0..<Int(bufferSize) {
                let amplitude = fabsf(bufferData?[i] ?? 0.0)
                if amplitude > maxAmplitude {
                    maxAmplitude = amplitude
                }
            }

            // Set a maximum amplitude threshold (adjust as needed).
            let maxAllowedAmplitude: Float = 0.9

            // Limit the maximum amplitude to the threshold.
            maxAmplitude = min(maxAmplitude, maxAllowedAmplitude)

            // Calculate the new X and Y coordinate for drawing the audio wave.
            let x: CGFloat
            if self.audioWavePath.isEmpty {
                // If the path is empty, initialize it with the starting point.
                x = CGFloat(0.0)
                let viewHeight = self.audioWaveView.bounds.height
                let newY = min(viewHeight, viewHeight - CGFloat(maxAmplitude) * (viewHeight))
                self.audioWavePath.move(to: CGPoint(x: x, y: newY))
            } else {
                x = CGFloat(self.audioWavePath.currentPoint.x + 1.0)
            }
            
            let viewHeight = self.audioWaveView.bounds.height
            let newY = min(viewHeight, viewHeight - CGFloat(maxAmplitude) * (viewHeight))

            // Move the path to the new point and add a line segment to represent the audio wave.
            self.audioWavePath.move(to: CGPoint(x: x, y: newY))
            self.audioWavePath.addLine(to: CGPoint(x: x, y: viewHeight))
            self.audioWaveLayer?.path = self.audioWavePath.cgPath

            // Check if the X value has exceeded the width of the audioWaveView.
            if x > self.audioWaveView.bounds.width {
                // Calculate the offset to shift the path within the UIView.
                let xOffset = x - self.audioWaveView.bounds.width

                // Limit the xOffset to the width of the audioWaveView.
                let limitedXOffset = min(xOffset, self.audioWaveView.bounds.width)

                // Shift the path by the limitedXOffset.
                self.audioWavePath.apply(CGAffineTransform(translationX: -limitedXOffset, y: 0))
            }

            // Set the updated path to the CAShapeLayer for visualizing the audio wave.
            self.audioWaveLayer?.path = self.audioWavePath.cgPath

            // Check for audio silence and remove the wave if silence is detected.
            if maxAmplitude < self.silenceThreshold {
                if let lastAudioReceivedTime = self.lastAudioReceivedTime {
                    let currentTime = Date()
                    let timeSinceLastAudio = currentTime.timeIntervalSince(lastAudioReceivedTime)
                    if timeSinceLastAudio > self.silenceThresholdSeconds {
                        // Silence detected for more than silenceThresholdSeconds, remove the wave.
                        self.audioWavePath.removeAllPoints()
                        self.audioWaveLayer?.path = nil
                    }
                } else {
                    self.lastAudioReceivedTime = Date()
                }
            } else {
                self.lastAudioReceivedTime = Date()
            }

            // Create an animation to move the audio wave to the left.
            let animation = CABasicAnimation(keyPath: "transform.translation.x")
            animation.fromValue = 0
            animation.toValue = -x
            animation.duration = 0.1 // Adjust the animation speed as needed

            // Apply the animation to the animationLayer.
            self.animationLayer?.add(animation, forKey: "waveAnimation")
        }
    }

    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        startStopBtn.isEnabled = available
    }
}


