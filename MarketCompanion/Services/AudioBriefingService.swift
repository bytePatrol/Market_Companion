// AudioBriefingService.swift
// MarketCompanion
//
// Text-to-speech service for reading market reports aloud.
// Uses AVSpeechSynthesizer for macOS speech synthesis.

import AVFoundation

@MainActor
final class AudioBriefingService: NSObject, ObservableObject {
    @Published var isSpeaking = false

    /// Speech rate from 0.0 (slowest) to 1.0 (fastest).
    /// AVSpeechUtterance range: AVSpeechUtteranceMinimumSpeechRate to AVSpeechUtteranceMaximumSpeechRate
    @Published var speechRateSlider: Double = 0.5

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speak the given text aloud.
    func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let speechText = prepareSpeechText(text)
        let utterance = AVSpeechUtterance(string: speechText)

        // Map slider (0.0-1.0) to AVSpeech rate range
        let minRate = AVSpeechUtteranceDefaultSpeechRate * 0.6
        let maxRate = AVSpeechUtteranceDefaultSpeechRate * 1.8
        utterance.rate = minRate + (maxRate - minRate) * Float(speechRateSlider)
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1

        // Use a good English voice if available
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }

        synthesizer.speak(utterance)
        isSpeaking = true
    }

    /// Stop any current speech.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    /// Toggle between speaking and stopping.
    func toggle(_ text: String) {
        if isSpeaking {
            stop()
        } else {
            speak(text)
        }
    }

    // MARK: - Text Preparation

    /// Strip markdown formatting and prepare text for natural speech.
    private func prepareSpeechText(_ markdown: String) -> String {
        var text = markdown

        // Remove markdown headers
        text = text.replacingOccurrences(of: "####\\s*", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "###\\s*", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "##\\s*", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "#\\s*", with: "", options: .regularExpression)

        // Remove bold/italic markers
        text = text.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "_([^_]+)_", with: "$1", options: .regularExpression)

        // Remove blockquote markers (multiline)
        text = text.replacingOccurrences(of: "(?m)^>\\s*", with: "", options: .regularExpression)

        // Convert table rows to readable format
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var inTable = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip table separator rows
            if trimmed.hasPrefix("|") && trimmed.contains("---") {
                inTable = true
                continue
            }

            if trimmed.hasPrefix("|") {
                let cells = trimmed.split(separator: "|").map {
                    $0.trimmingCharacters(in: .whitespaces)
                }.filter { !$0.isEmpty }

                if cells.count >= 2 {
                    if inTable {
                        result.append("\(cells[0]): \(cells[1..<cells.count].joined(separator: ", "))")
                    } else {
                        // Header row
                        inTable = true
                        continue
                    }
                }
            } else {
                inTable = false

                // Convert list items
                if trimmed.hasPrefix("- ") {
                    result.append(String(trimmed.dropFirst(2)))
                } else if trimmed.hasPrefix("---") {
                    continue
                } else if !trimmed.isEmpty {
                    result.append(trimmed)
                }
            }
        }

        return result.joined(separator: ". ")
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AudioBriefingService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
