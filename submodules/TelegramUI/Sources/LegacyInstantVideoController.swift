import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import MediaResources
import LegacyComponents
import AccountContext
import LegacyUI
import ImageCompression
import LocalMediaResources
import AppBundle
import LegacyMediaPickerUI

final class InstantVideoControllerRecordingStatus {
    let micLevel: Signal<Float, NoError>
    let duration: Signal<TimeInterval, NoError>
    
    init(micLevel: Signal<Float, NoError>, duration: Signal<TimeInterval, NoError>) {
        self.micLevel = micLevel
        self.duration = duration
    }
}

final class InstantVideoController: LegacyController, StandalonePresentableController {
    private var captureController: TGVideoMessageCaptureController?
    
    var onDismiss: ((Bool) -> Void)?
    var onStop: (() -> Void)?
    
    private let micLevelValue = ValuePromise<Float>(0.0)
    private let durationValue = ValuePromise<TimeInterval>(0.0)
    let audioStatus: InstantVideoControllerRecordingStatus
    
    private var dismissedVideo = false
    
    override init(presentation: LegacyControllerPresentation, theme: PresentationTheme?, strings: PresentationStrings? = nil, initialLayout: ContainerViewLayout? = nil) {
        self.audioStatus = InstantVideoControllerRecordingStatus(micLevel: self.micLevelValue.get(), duration: self.durationValue.get())
        
        super.init(presentation: presentation, theme: theme, initialLayout: initialLayout)
        
        self.lockOrientation = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func bindCaptureController(_ captureController: TGVideoMessageCaptureController?) {
        self.captureController = captureController
        if let captureController = captureController {
            captureController.micLevel = { [weak self] (level: CGFloat) -> Void in
                self?.micLevelValue.set(Float(level))
            }
            captureController.onDuration = { [weak self] duration in
                self?.durationValue.set(duration)
            }
            captureController.onDismiss = { [weak self] _, isCancelled in
                guard let strongSelf = self else { return }
                if !strongSelf.dismissedVideo {
                    self?.dismissedVideo = true
                    self?.onDismiss?(isCancelled)
                }
            }
            captureController.onStop = { [weak self] in
                self?.onStop?()
            }
        }
    }
    
    func dismissVideo() {
        if let captureController = self.captureController, !self.dismissedVideo {
            self.dismissedVideo = true
            captureController.dismiss()
        }
    }
    
    func completeVideo() {
        if let captureController = self.captureController, !self.dismissedVideo {
            self.dismissedVideo = true
            captureController.complete()
        }
    }
    
    func stopVideo() -> Bool {
        if let captureController = self.captureController {
            return captureController.stop()
        }
        return false
    }
    
    func lockVideo() {
        if let captureController = self.captureController {
            return captureController.setLocked()
        }
    }
    
    func updateRecordButtonInteraction(_ value: CGFloat) {
        if let captureController = self.captureController {
            captureController.buttonInteractionUpdate(CGPoint(x: value, y: 0.0))
        }
    }
}

func legacyInputMicPalette(from theme: PresentationTheme) -> TGModernConversationInputMicPallete {
    let inputPanelTheme = theme.chat.inputPanel
    return TGModernConversationInputMicPallete(dark: theme.overallDarkAppearance, buttonColor: inputPanelTheme.actionControlFillColor, iconColor: inputPanelTheme.actionControlForegroundColor, backgroundColor: inputPanelTheme.panelBackgroundColor, borderColor: inputPanelTheme.panelSeparatorColor, lock: inputPanelTheme.panelControlAccentColor, textColor: inputPanelTheme.primaryTextColor, secondaryTextColor: inputPanelTheme.secondaryTextColor, recording: inputPanelTheme.mediaRecordingDotColor)
}

func legacyInstantVideoController(theme: PresentationTheme, panelFrame: CGRect, context: AccountContext, peerId: PeerId, slowmodeState: ChatSlowmodeState?, hasSchedule: Bool, send: @escaping (EnqueueMessage) -> Void, displaySlowmodeTooltip: @escaping (ASDisplayNode, CGRect) -> Void, presentSchedulePicker: @escaping (@escaping (Int32) -> Void) -> Void) -> InstantVideoController {
    let isSecretChat = peerId.namespace == Namespaces.Peer.SecretChat
    
    let legacyController = InstantVideoController(presentation: .custom, theme: theme)
    legacyController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .all)
    legacyController.lockOrientation = true
    legacyController.statusBar.statusBarStyle = .Hide
    let baseController = TGViewController(context: legacyController.context)!
    legacyController.bind(controller: baseController)
    legacyController.presentationCompleted = { [weak legacyController, weak baseController] in
        if let legacyController = legacyController, let baseController = baseController {
            legacyController.view.disablesInteractiveTransitionGestureRecognizer = true
            var uploadInterface: LegacyLiveUploadInterface?
            if peerId.namespace != Namespaces.Peer.SecretChat {
                uploadInterface = LegacyLiveUploadInterface(account: context.account)
            }
            
            var slowmodeValidUntil: Int32 = 0
            if let slowmodeState = slowmodeState, case let .timestamp(timestamp) = slowmodeState.variant {
                slowmodeValidUntil = timestamp
            }
            
            let controller = TGVideoMessageCaptureController(context: legacyController.context, assets: TGVideoMessageCaptureControllerAssets(send: PresentationResourcesChat.chatInputPanelSendButtonImage(theme)!, slideToCancel: PresentationResourcesChat.chatInputPanelMediaRecordingCancelArrowImage(theme)!, actionDelete: generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.chat.inputPanel.panelControlAccentColor))!, transitionInView: {
                return nil
            }, parentController: baseController, controlsFrame: panelFrame, isAlreadyLocked: {
                return false
            }, liveUploadInterface: uploadInterface, pallete: legacyInputMicPalette(from: theme), slowmodeTimestamp: slowmodeValidUntil, slowmodeView: {
                let node = ChatSendButtonRadialStatusView(color: theme.chat.inputPanel.panelControlAccentColor)
                node.slowmodeState = slowmodeState
                return node
            }, canSendSilently: !isSecretChat, canSchedule: hasSchedule, reminder: peerId == context.account.peerId)!
            controller.presentScheduleController = { done in
                presentSchedulePicker { time in
                    done?(time)
                }
            }
            controller.finishedWithVideo = { videoUrl, previewImage, _, duration, dimensions, liveUploadData, adjustments, isSilent, scheduleTimestamp in
                guard let videoUrl = videoUrl else {
                    return
                }
                AnimationManager.shared.videoFrame = controller.circeFrame
                if AnimationManager.shared.shouldAnimateInsertion {
                    controller.dismissImmediately()
                }
                
                var finalDimensions: CGSize = dimensions
                var finalDuration: Double = duration
                
                var previewRepresentations: [TelegramMediaImageRepresentation] = []
                if let previewImage = previewImage {
                    let resource = LocalFileMediaResource(fileId: arc4random64())
                    let thumbnailSize = finalDimensions.aspectFitted(CGSize(width: 320.0, height: 320.0))
                    let thumbnailImage = TGScaleImageToPixelSize(previewImage, thumbnailSize)!
                    if let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.4) {
                        context.account.postbox.mediaBox.storeResourceData(resource.id, data: thumbnailData)
                        previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(thumbnailSize), resource: resource, progressiveSizes: []))
                    }
                }
                
                finalDimensions = TGMediaVideoConverter.dimensions(for: finalDimensions, adjustments: adjustments, preset: TGMediaVideoConversionPresetVideoMessage)
                
                var resourceAdjustments: VideoMediaResourceAdjustments?
                if let adjustments = adjustments {
                    if adjustments.trimApplied() {
                        finalDuration = adjustments.trimEndValue - adjustments.trimStartValue
                    }
                    
                    let adjustmentsData = MemoryBuffer(data: NSKeyedArchiver.archivedData(withRootObject: adjustments.dictionary()))
                    let digest = MemoryBuffer(data: adjustmentsData.md5Digest())
                    resourceAdjustments = VideoMediaResourceAdjustments(data: adjustmentsData, digest: digest)
                }
                
                if finalDuration.isZero || finalDuration.isNaN {
                    return
                }
                
                let resource: TelegramMediaResource
                if let liveUploadData = liveUploadData as? LegacyLiveUploadInterfaceResult, resourceAdjustments == nil, let data = try? Data(contentsOf: videoUrl) {
                    resource = LocalFileMediaResource(fileId: liveUploadData.id)
                    context.account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                } else {
                    resource = LocalFileVideoMediaResource(randomId: arc4random64(), path: videoUrl.path, adjustments: resourceAdjustments)
                }
                
                if let previewImage = previewImage {
                    if let data = compressImageToJPEG(previewImage, quality: 0.7) {
                    context.account.postbox.mediaBox.storeCachedResourceRepresentation(resource, representation: CachedVideoFirstFrameRepresentation(), data: data)
                    }
                }
                
                let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: arc4random64()), partialReference: nil, resource: resource, previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: [.FileName(fileName: "video.mp4"), .Video(duration: Int(finalDuration), size: PixelDimensions(finalDimensions), flags: [.instantRoundVideo])])
                var message: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: nil, localGroupingKey: nil)
                
                let scheduleTime: Int32? = scheduleTimestamp > 0 ? scheduleTimestamp : nil
                
                message = message.withUpdatedAttributes { attributes in
                    var attributes = attributes
                    for i in (0 ..< attributes.count).reversed() {
                        if attributes[i] is NotificationInfoMessageAttribute {
                            attributes.remove(at: i)
                        } else if let _ = scheduleTime, attributes[i] is OutgoingScheduleInfoMessageAttribute {
                            attributes.remove(at: i)
                        }
                    }
                    if isSilent {
                        attributes.append(NotificationInfoMessageAttribute(flags: .muted))
                    }
                    if let scheduleTime = scheduleTime {
                        attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: scheduleTime))
                    }
                    return attributes
                }
                
                send(message)
            }
            controller.didDismiss = { [weak legacyController] in
                if let legacyController = legacyController {
                    legacyController.dismiss()
                }
            }
            controller.displaySlowmodeTooltip = { [weak legacyController, weak controller] in
                if let legacyController = legacyController, let controller = controller {
                    let rect = controller.frameForSendButton()
                    displaySlowmodeTooltip(legacyController.displayNode, rect)
                }
            }
            legacyController.bindCaptureController(controller)
            
            let presentationDisposable = context.sharedContext.presentationData.start(next: { [weak controller] presentationData in
                if let controller = controller {
                    controller.pallete = legacyInputMicPalette(from: presentationData.theme)
                }
            })
            legacyController.disposables.add(presentationDisposable)
        }
    }
    return legacyController
}
