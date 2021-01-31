import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import SyncCore

func addMessageMediaResourceIdsToRemove(media: Media, resourceIds: inout [WrappedMediaResourceId]) {
    if let image = media as? TelegramMediaImage {
        for representation in image.representations {
            resourceIds.append(WrappedMediaResourceId(representation.resource.id))
        }
    } else if let file = media as? TelegramMediaFile {
        for representation in file.previewRepresentations {
            resourceIds.append(WrappedMediaResourceId(representation.resource.id))
        }
        resourceIds.append(WrappedMediaResourceId(file.resource.id))
    }
}

func addMessageMediaResourceIdsToRemove(message: Message, resourceIds: inout [WrappedMediaResourceId]) {
    for media in message.media {
        addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
    }
}

public func deleteMessages(transaction: Transaction, mediaBox: MediaBox, ids: [MessageId], deleteMedia: Bool = true, manualAddMessageThreadStatsDifference: ((MessageId, Int, Int) -> Void)? = nil) {
    var resourceIds: [WrappedMediaResourceId] = []
    if deleteMedia {
        for id in ids {
            if id.peerId.namespace == Namespaces.Peer.SecretChat {
                if let message = transaction.getMessage(id) {
                    addMessageMediaResourceIdsToRemove(message: message, resourceIds: &resourceIds)
                }
            }
        }
    }
    if !resourceIds.isEmpty {
        let _ = mediaBox.removeCachedResources(Set(resourceIds)).start()
    }
    for id in ids {
        if id.peerId.namespace == Namespaces.Peer.CloudChannel && id.namespace == Namespaces.Message.Cloud {
            if let message = transaction.getMessage(id) {
                if let threadId = message.threadId {
                    let messageThreadId = makeThreadIdMessageId(peerId: message.id.peerId, threadId: threadId)
                    if id.peerId.namespace == Namespaces.Peer.CloudChannel {
                        if let manualAddMessageThreadStatsDifference = manualAddMessageThreadStatsDifference {
                            manualAddMessageThreadStatsDifference(messageThreadId, 0, 1)
                        } else {
                            updateMessageThreadStats(transaction: transaction, threadMessageId: messageThreadId, removedCount: 1, addedMessagePeers: [])
                        }
                    }
                }
            }
        }
    }
    transaction.deleteMessages(ids, forEachMedia: { _ in
    })
}

public func deleteAllMessagesWithAuthor(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, authorId: PeerId, namespace: MessageId.Namespace) {
    var resourceIds: [WrappedMediaResourceId] = []
    transaction.removeAllMessagesWithAuthor(peerId, authorId: authorId, namespace: namespace, forEachMedia: { media in
        addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
    })
    if !resourceIds.isEmpty {
        let _ = mediaBox.removeCachedResources(Set(resourceIds)).start()
    }
}

public func deleteAllMessagesWithForwardAuthor(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, forwardAuthorId: PeerId, namespace: MessageId.Namespace) {
    var resourceIds: [WrappedMediaResourceId] = []
    transaction.removeAllMessagesWithForwardAuthor(peerId, forwardAuthorId: forwardAuthorId, namespace: namespace, forEachMedia: { media in
        addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
    })
    if !resourceIds.isEmpty {
        let _ = mediaBox.removeCachedResources(Set(resourceIds)).start()
    }
}

public func clearHistory(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, namespaces: MessageIdNamespaces) {
    if peerId.namespace == Namespaces.Peer.SecretChat {
        var resourceIds: [WrappedMediaResourceId] = []
        transaction.withAllMessages(peerId: peerId, { message in
            addMessageMediaResourceIdsToRemove(message: message, resourceIds: &resourceIds)
            return true
        })
        if !resourceIds.isEmpty {
            let _ = mediaBox.removeCachedResources(Set(resourceIds)).start()
        }
    }
    transaction.clearHistory(peerId, namespaces: namespaces, forEachMedia: { _ in
    })
}

public enum ClearCallHistoryError {
    case generic
}

public func clearCallHistory(account: Account, forEveryone: Bool) -> Signal<Never, ClearCallHistoryError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        var flags: Int32 = 0
        if forEveryone {
            flags |= 1 << 0
        }
        
        let signal = account.network.request(Api.functions.messages.deletePhoneCallHistory(flags: flags))
        |> map { result -> Api.messages.AffectedFoundMessages? in
            return result
        }
        |> `catch` { _ -> Signal<Api.messages.AffectedFoundMessages?, Bool> in
            return .fail(false)
        }
        |> mapToSignal { result -> Signal<Void, Bool> in
            if let result = result {
                switch result {
                case let .affectedFoundMessages(pts, ptsCount, offset, _):
                    account.stateManager.addUpdateGroups([.updatePts(pts: pts, ptsCount: ptsCount)])
                    if offset == 0 {
                        return .fail(true)
                    } else {
                        return .complete()
                    }
                }
            } else {
                return .fail(true)
            }
        }
        return (signal
        |> restart)
        |> `catch` { success -> Signal<Void, NoError> in
            if success {
                return account.postbox.transaction { transaction -> Void in
                    transaction.removeAllMessagesWithGlobalTag(tag: GlobalMessageTags.Calls)
                }
            } else {
                return .complete()
            }
        }
    }
    |> switchToLatest
    |> ignoreValues
    |> castError(ClearCallHistoryError.self)
}
