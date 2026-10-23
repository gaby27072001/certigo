import Foundation

#if canImport(SwiftUI)
    import AVFoundation
    import CertigoData
    import CertigoDomain
    import Observation
    import SwiftUI
    import UIKit

    @MainActor
    struct NativeLessonAudioControls: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Environment(\.scenePhase) private var scenePhase
        @State private var speech = NativeLessonSpeech()
        let content: NativeLessonReadingContent
        let ownerID: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(copy[.audioReadAloud]).font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(
                    copy[.audioScopeNote]
                )
                .font(.subheadline).foregroundStyle(.secondary)
                Picker(copy[.audioVoice], selection: $speech.voiceID) {
                    Text(copy[.audioChooseVoice]).tag("")
                    ForEach(speech.voices, id: \.identifier) { voice in
                        Text("\(voice.name) · \(voice.language)").tag(voice.identifier)
                    }
                }
                .disabled(speech.state != .idle)
                if speech.voices.isEmpty {
                    Text(copy[.audioNoVoices])
                }
                Picker(copy[.audioSpeed], selection: $speech.rate) {
                    Text(copy[.audioSlower]).tag(AVSpeechUtteranceDefaultSpeechRate * 0.8)
                    Text(copy[.audioStandard]).tag(AVSpeechUtteranceDefaultSpeechRate)
                }
                .disabled(speech.state != .idle)
                Text(speech.state.label(copy)).font(.subheadline)
                    .accessibilityIdentifier("lesson-audio-state")
                ViewThatFits(in: .horizontal) {
                    HStack { playbackButtons }
                    VStack(alignment: .leading) { playbackButtons }
                }
                if let issue = speech.issue {
                    Text(copy[issue]).foregroundStyle(.primary)
                        .accessibilityIdentifier("lesson-audio-error")
                }
            }
            .onDisappear { speech.stop() }
            .onChange(of: content) { _, _ in speech.stop() }
            .onChange(of: ownerID) { _, _ in speech.reset() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { speech.stop() }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIAccessibility.voiceOverStatusDidChangeNotification)
            ) { _ in
                if UIAccessibility.isVoiceOverRunning { speech.stop() }
            }
        }

        @ViewBuilder private var playbackButtons: some View {
            switch speech.state {
            case .idle:
                Button(copy[.audioRead], systemImage: "speaker.wave.2") {
                    speech.read(content)
                }
                .frame(minHeight: 44)
            case .reading:
                Button(copy[.audioPause], systemImage: "pause") { speech.pause() }
                    .frame(minHeight: 44)
            case .paused:
                Button(copy[.audioResume], systemImage: "play") { speech.resume() }
                    .frame(minHeight: 44)
            }
            if speech.state != .idle {
                Button(copy[.audioStop], systemImage: "stop") { speech.stop() }
                    .frame(minHeight: 44)
            }
        }
    }

    @MainActor
    @Observable
    private final class NativeLessonSpeech: NSObject, AVSpeechSynthesizerDelegate {
        enum State {
            case idle, reading, paused

            func label(_ copy: AppInterfaceCopy) -> String {
                switch self {
                case .idle: copy[.audioStopped]
                case .reading: copy[.audioReading]
                case .paused: copy[.audioPaused]
                }
            }
        }

        let voices = AVSpeechSynthesisVoice.speechVoices().sorted {
            ($0.language, $0.name, $0.identifier) < ($1.language, $1.name, $1.identifier)
        }
        var voiceID = ""
        var rate = AVSpeechUtteranceDefaultSpeechRate
        private(set) var state = State.idle
        private(set) var issue: AppInterfaceCopy.Key?
        private let synthesizer = AVSpeechSynthesizer()
        private var utteranceID: ObjectIdentifier?

        override init() {
            super.init()
            synthesizer.delegate = self
            synthesizer.usesApplicationAudioSession = false
        }

        func read(_ content: NativeLessonReadingContent) {
            guard state == .idle else { return }
            issue = nil
            guard !voices.isEmpty else {
                issue = .audioNoVoices
                return
            }
            guard !UIAccessibility.isVoiceOverRunning else {
                issue = .audioVoiceOverRead
                return
            }
            guard !voiceID.isEmpty else {
                issue = .audioChooseVoiceFirst
                return
            }
            guard let voice = AVSpeechSynthesisVoice(identifier: voiceID) else {
                issue = .audioVoiceUnavailable
                return
            }
            let text: String
            do {
                text = try content.spokenText(
                    renderingMarkdown: NativeLessonReadingContent.plainText)
            } catch {
                issue = .audioPreparationFailed
                return
            }
            guard !text.isEmpty else {
                issue = .audioNoText
                return
            }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            utterance.rate = rate
            utteranceID = ObjectIdentifier(utterance)
            state = .reading
            synthesizer.speak(utterance)
        }

        func pause() {
            guard state == .reading else { return }
            if synthesizer.pauseSpeaking(at: .immediate) {
                state = .paused
            } else {
                issue = .audioPauseFailed
            }
        }

        func resume() {
            guard state == .paused else { return }
            guard !UIAccessibility.isVoiceOverRunning else {
                stop()
                issue = .audioVoiceOverResume
                return
            }
            if synthesizer.continueSpeaking() {
                state = .reading
            } else {
                issue = .audioResumeFailed
            }
        }

        func stop() {
            utteranceID = nil
            synthesizer.stopSpeaking(at: .immediate)
            state = .idle
            issue = nil
        }

        func reset() {
            stop()
            voiceID = ""
            rate = AVSpeechUtteranceDefaultSpeechRate
        }

        nonisolated func speechSynthesizer(
            _ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance
        ) {
            let id = ObjectIdentifier(utterance)
            Task { @MainActor [weak self] in self?.finished(id) }
        }

        nonisolated func speechSynthesizer(
            _ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance
        ) {
            let id = ObjectIdentifier(utterance)
            Task { @MainActor [weak self] in self?.finished(id) }
        }

        private func finished(_ id: ObjectIdentifier) {
            guard utteranceID == id else { return }
            utteranceID = nil
            state = .idle
        }
    }
#endif
