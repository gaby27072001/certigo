import Foundation

#if canImport(SwiftUI)
    import AVFoundation
    import CertigoData
    import CertigoDomain
    import Observation
    import SwiftUI
    import UIKit

    struct NativeAccountDeletionView: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Bindable var model: NativeModel
        @Environment(\.dismiss) private var dismiss
        @Environment(\.scenePhase) private var scenePhase
        private enum Focus: Hashable { case status, error }
        @AccessibilityFocusState private var focused: Focus?

        var body: some View {
            Form {
                Section {
                    Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($focused, equals: .status)
                    if model.deletionBusy { ProgressView(copy.loading) }
                    if let message = model.deletionMessage {
                        Text(message.resolved(using: copy)).accessibilityIdentifier(
                            "account-deletion-message"
                        )
                        .accessibilityFocused($focused, equals: .error)
                    }
                }
                if [.explanation, .verifying, .confirmation].contains(
                    model.deletionStage ?? .explanation)
                {
                    Section(copy[.deletionBeforeContinuing]) {
                        Text(
                            copy[.deletionScopeNote]
                        )
                        Text(
                            copy[.deletionRetentionNote]
                        )
                        if model.canReauthenticateForDeletion {
                            Button(
                                copy[.deletionVerify],
                                systemImage: "person.badge.shield.checkmark"
                            ) {
                                Task { await model.verifyDeletionIdentity() }
                            }
                            .disabled(model.deletionBusy)
                        } else {
                            Text(
                                copy[.deletionMicrosoftRequired]
                            )
                        }
                    }
                } else if model.deletionStage == .pending || model.deletionStage == .unconfirmed
                    || model.deletionStage == .checking
                {
                    Section(copy[.deletionServerStatus]) {
                        if let status = model.deletionStatus, status.status == .pending {
                            Text(
                                copy.deletionProgress(
                                    completed: status.completedSteps, total: status.totalSteps)
                            )
                            Text(
                                copy[.deletionPendingNote]
                            )
                            if status.retryAfterSeconds != nil {
                                Text(
                                    copy[.deletionRetryDelay]
                                )
                            }
                        }
                        Button(copy[.deletionCheckStatus], systemImage: "arrow.clockwise") {
                            Task { await model.refreshDeletionStatus() }
                        }
                        .disabled(model.deletionBusy)
                        Button(
                            copy[.deletionSignInSameAccount], systemImage: "person.crop.circle"
                        ) {
                            Task { await model.recoverDeletionConnection(interactive: true) }
                        }
                        .disabled(model.deletionBusy)
                        Button(copy.retry, role: .destructive) {
                            Task { await model.retryAccountDeletion() }
                        }
                        .disabled(!model.canRetryDeletion)
                        if model.deletionStatus?.status == .notRequested {
                            Button(copy[.deletionResumeAccount]) {
                                Task { await model.resumeAccountAfterStatusCheck() }
                            }
                            .disabled(model.deletionBusy)
                        }
                    }
                } else if model.deletionStage == .cleanupFailed {
                    Section {
                        Text(
                            copy[.deletionCleanupIncomplete]
                        )
                        Button(copy.retry, systemImage: "arrow.clockwise") {
                            Task { await model.retryDeletionCleanup() }
                        }
                        .disabled(model.deletionBusy)
                    }
                } else if model.deletionStage == .completed {
                    Section {
                        Text(
                            copy[.deletionCompletedNote]
                        )
                        Button(copy[.deletionReturnToSignIn]) { model.acknowledgeAccountDeletion() }
                    }
                }
            }
            .navigationTitle(copy.accountDeletion)
            .navigationBarBackButtonHidden(model.deletionBusy || !model.canCancelDeletion)
            .toolbar {
                if model.canCancelDeletion {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(copy[.cancel]) {
                            Task {
                                await model.cancelAccountDeletion()
                                if model.deletionStage == nil { dismiss() }
                            }
                        }
                    }
                }
            }
            .alert(
                copy[.deletionConfirmTitle],
                isPresented: Binding(
                    get: { model.deletionStage == .confirmation },
                    set: { _ in })
            ) {
                Button(copy[.deleteAccount], role: .destructive) {
                    Task { await model.confirmAccountDeletion() }
                }
                Button(copy[.cancel], role: .cancel) { model.discardDeletionProof() }
            } message: {
                Text(
                    copy[.deletionConfirmMessage]
                )
            }
            .onChange(of: model.deletionStage) { _, _ in focused = .status }
            .onChange(of: model.deletionMessage) { _, message in
                focused = message == nil ? .status : .error
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { model.discardDeletionProof() }
            }
            .onAppear { if model.deletionStage == nil { model.showAccountDeletion() } }
            .onDisappear {
                model.discardDeletionProof()
                if model.canCancelDeletion { Task { await model.cancelAccountDeletion() } }
            }
        }

        private var title: String {
            switch model.deletionStage {
            case .verifying: copy[.deletionVerifying]
            case .confirmation: copy[.deletionIdentityVerified]
            case .checking: copy[.deletionChecking]
            case .pending: copy[.deletionPending]
            case .unconfirmed: copy[.deletionUnconfirmed]
            case .cleanupFailed: copy[.deletionCleanupAttention]
            case .completed: copy[.deletionCompleted]
            default: copy[.deletionTitle]
            }
        }
    }
#endif
