//
//  ViewController.swift
//  Speech to Text - IOS
//
//  Created by Siti Hafsah on 19/09/23.
//

import UIKit
import Speech
import NaturalLanguage

class ViewController: UIViewController {

    @IBOutlet weak var startStopBtn: UIButton!
    @IBOutlet weak var segmentDetectLanguage: UISegmentedControl!
    @IBOutlet weak var textView: UITextView!

    private var speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "id-ID"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var audioEngine = AVAudioEngine()
    var lang: String = "id-ID"

    override func viewDidLoad() {
        super.viewDidLoad()
        startStopBtn.isEnabled = false
        speechRecognizer?.delegate = self as? SFSpeechRecognizerDelegate
        speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: lang))
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
                // Menambahkan default case untuk mengatasi nilai-nilai tambahan yang belum dikenali
                print("Unknown authorization status")
            }
            OperationQueue.main.addOperation() {
                self.startStopBtn.isEnabled = isButtonEnabled
            }
        }
    }

    @IBAction func segmentLanguageAct(_ sender: Any) {
        switch segmentDetectLanguage.selectedSegmentIndex {
            case 0:
                lang = "id-ID"
                break
            case 1:
                lang = "en-US"
                break
            default:
                lang = "id-ID"
                break
        }
        speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: lang))
    }

    // MARK: - Action: Start/Stop Button
    @IBAction func startStopBtnAct(_ sender: Any) {
        // Update the speech recognizer with the selected locale in segmentLanguageAct
//        speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: lang))
        if audioEngine.isRunning {
            // If the audio engine is running, stop it and end the recognition request
            audioEngine.stop()
            recognitionRequest?.endAudio()
            startStopBtn.isEnabled = false
            startStopBtn.setTitle("Start Recording", for: .normal)
        } else {
            // If the audio engine is not running, start recording
            startRecording()
            startStopBtn.setTitle("Stop Recording", for: .normal)
        }
    }

    // MARK: - Recording Function
    func startRecording() {
        // Check if there is a speech recognition task currently running, if so, cancel the task.
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        // Access and configure the audio session settings using AVAudioSession.
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.record)
            try audioSession.setMode(AVAudioSession.Mode.measurement)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            // If there is an error in configuring the audio session, print an error message.
            print("audioSession properties weren't set because of an error.")
        }

        // Create a speech recognition request using SFSpeechAudioBufferRecognitionRequest.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        // Access the input audio node from the audioEngine.
        let inputNode = audioEngine.inputNode

        // Check if the recognitionRequest has been successfully created; if not, trigger a fatal error.
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }

        // Set options to report recognition results as they are processed.
        recognitionRequest.shouldReportPartialResults = true

        // Create a speech recognition task using speechRecognizer and recognitionRequest.
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            // Initialize the isFinal variable to determine if the result is final.
            var isFinal = false

            // If the recognition result is not nil.
            if result != nil {
                // Identify the language in the recognized text using Natural Language Processing.
                if let resultText = result?.bestTranscription.formattedString {
                    let languageIdentifier = NLLanguageRecognizer.dominantLanguage(for: resultText)
                    if let languageCode = languageIdentifier?.rawValue {
                        // If the recognized language is Indonesian, print "Indonesian Language."
                        if languageCode == "id" {
                            print("Indonesian Language")
                        }
                        // If the recognized language is English, print "English Language."
                        else if languageCode == "en" {
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
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.startStopBtn.isEnabled = true
            }
        })
        
        // Set the recording format for the inputNode.
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install an audio tap on the inputNode to append audio data to the recognitionRequest.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }

        // Prepare and start the audioEngine for recording.
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }

        // Set the initial text in the textView as "Please say something."
        textView.text = "Please say something"
    }


    // MARK: - Speech Recognizer Availability
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            startStopBtn.isEnabled = true
        } else {
            startStopBtn.isEnabled = false
        }
    }
}

