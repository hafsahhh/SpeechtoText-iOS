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
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            startStopBtn.isEnabled = false
            startStopBtn.setTitle("Listen...", for: .normal)
            
            // Clear the audio wave visualization
            audioWavePath.removeAllPoints()
            audioWaveLayer?.path = nil
        } else {
            startRecording()
            startStopBtn.setTitle("Stop", for: .normal)
        }
    }
    
    // MARK: - Audio Recording Function
    func startRecording() {
        // Check if there is an existing recognition task, cancel it, and set it to nil.
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Access the shared AVAudioSession instance and configure it for recording.
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.record)
            try audioSession.setMode(AVAudioSession.Mode.measurement)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            // Handle errors if audio session configuration fails
            print("audioSession properties weren't set because of an error.")
        }
        
        // Create a speech recognition request using SFSpeechAudioBufferRecognitionRequest.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        // Check if the recognition request has been successfully created; if not, exit with a fatal error.
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        // Set options to report recognition results as they are processed
        recognitionRequest.shouldReportPartialResults = true
        
        // Create a speech recognition task using speechRecognizer and recognitionRequest.
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            var isFinal = false
            
            if result != nil {
                // If a recognition result is available, process it
                if let resultText = result?.bestTranscription.formattedString {
                    // Identify the language in the recognized text using Natural Language Processing.
                    let languageIdentifier = NLLanguageRecognizer.dominantLanguage(for: resultText)
                    if let languageCode = languageIdentifier?.rawValue {
                        // If the recognized language is Indonesian, print "Indonesian Language."
                        if languageCode == "id" {
                            print("Indonesian Language")
                            // If the recognized language is English, print "English Language."
                        } else if languageCode == "en" {
                            print("English Language")
                        }
                    }
                }
                
                // Set the textView's text to the recognized text.
                self.textView.text = result?.bestTranscription.formattedString
                // Update the isFinal variable based on whether the result is final.
                isFinal = (result?.isFinal)!
            }
            
            // If there is an error or the result is final, stop the audioEngine and clean up.
            if error != nil || isFinal {
                self.audioEngine.stop()
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.startStopBtn.isEnabled = true
            }
        })
        
        // Access the input audio node from the audioEngine.
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install an audio tap on the inputNode to append audio data to the recognitionRequest.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
            // Update the audio wave visualization with the audio buffer
            self.updateAudioWave(withBuffer: buffer)
        }
        
        // Prepare and start the audioEngine for recording
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            // Handle errors if the audioEngine couldn't start.
            print("audioEngine couldn't start because of an error.")
        }
        
        textView.text = "Please say something"
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
            
            // Calculate the new X and Y coordinates for drawing the audio wave.
            let x = CGFloat(self.audioWavePath.currentPoint.x + 1.0)
            let viewHeight = self.audioWaveView.bounds.height
            let newY = viewHeight - CGFloat(maxAmplitude) * (viewHeight)

            
            // Move the path to the new point and add a line segment to represent the audio wave.
            self.audioWavePath.move(to: CGPoint(x: x, y: newY))
            self.audioWavePath.addLine(to: CGPoint(x: x, y: viewHeight))

            
            // Set the updated path to the CAShapeLayer for visualizing the audio wave.
            self.audioWaveLayer?.path = self.audioWavePath.cgPath
            
            // Check if the X value has exceeded the width of the audioWaveView.
            if x > self.audioWaveView.bounds.width {
                // If so, reset the path to clear the visualization.
                self.audioWavePath.removeAllPoints()
                self.audioWaveLayer?.path = nil
            }
            
            print("Max Amplitude: \(maxAmplitude)")
            print("x: \(x), newY: \(newY)")
        }
    }
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            startStopBtn.isEnabled = true
        } else {
            startStopBtn.isEnabled = false
        }
    }
}


