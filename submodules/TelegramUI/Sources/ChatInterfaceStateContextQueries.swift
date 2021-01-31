import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox
import TelegramUIPreferences
import LegacyComponents
import TextFormat
import AccountContext
import Emoji
import SearchPeerMembers
import DeviceLocationManager
import TelegramNotices

enum ChatContextQueryError {
    case inlineBotLocationRequest(PeerId)
}

enum ChatContextQueryUpdate {
    case remove
    case update(ChatPresentationInputQuery, Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError>)
}

func contextQueryResultStateForChatInterfacePresentationState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentQueryStates: inout [ChatPresentationInputQueryKind: (ChatPresentationInputQuery, Disposable)], requestBotLocationStatus: @escaping (PeerId) -> Void) -> [ChatPresentationInputQueryKind: ChatContextQueryUpdate] {
    guard let peer = chatPresentationInterfaceState.renderedPeer?.peer else {
        return [:]
    }
    let inputQueries = inputContextQueriesForChatPresentationIntefaceState(chatPresentationInterfaceState).filter({ query in
        if chatPresentationInterfaceState.editMessageState != nil {
            switch query {
                case .contextRequest, .command, .emoji:
                    return false
                default:
                    return true
            }
        } else {
            return true
        }
    })
    
    var updates: [ChatPresentationInputQueryKind: ChatContextQueryUpdate] = [:]
    
    for query in inputQueries {
        let previousQuery = currentQueryStates[query.kind]?.0
        if previousQuery != query {
            let signal = updatedContextQueryResultStateForQuery(context: context, peer: peer, chatLocation: chatPresentationInterfaceState.chatLocation, inputQuery: query, previousQuery: previousQuery, requestBotLocationStatus: requestBotLocationStatus)
            updates[query.kind] = .update(query, signal)
        }
    }
    
    for currentQueryKind in currentQueryStates.keys {
        var found = false
        inner: for query in inputQueries {
            if query.kind == currentQueryKind {
                found = true
                break inner
            }
        }
        if !found {
            updates[currentQueryKind] = .remove
        }
    }
    
    return updates
}

struct StickersSearchConfiguration {
    static var defaultValue: StickersSearchConfiguration {
        return StickersSearchConfiguration(disableLocalSuggestions: false)
    }
    
    public let disableLocalSuggestions: Bool
    
    fileprivate init(disableLocalSuggestions: Bool) {
        self.disableLocalSuggestions = disableLocalSuggestions
    }
    
    static func with(appConfiguration: AppConfiguration) -> StickersSearchConfiguration {
        if let data = appConfiguration.data, let suggestOnlyApi = data["stickers_emoji_suggest_only_api"] as? Bool {
            return StickersSearchConfiguration(disableLocalSuggestions: suggestOnlyApi)
        } else {
            return .defaultValue
        }
    }
}

private func updatedContextQueryResultStateForQuery(context: AccountContext, peer: Peer, chatLocation: ChatLocation, inputQuery: ChatPresentationInputQuery, previousQuery: ChatPresentationInputQuery?, requestBotLocationStatus: @escaping (PeerId) -> Void) -> Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> {
    switch inputQuery {
        case let .emoji(query):
            var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = .complete()
            if let previousQuery = previousQuery {
                switch previousQuery {
                    case .emoji:
                        break
                    default:
                        signal = .single({ _ in return .stickers([]) })
                }
            } else {
                signal = .single({ _ in return .stickers([]) })
            }
            
            let stickerConfiguration = context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
            |> map { preferencesView -> StickersSearchConfiguration in
                let appConfiguration: AppConfiguration = preferencesView.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? .defaultValue
                return StickersSearchConfiguration.with(appConfiguration: appConfiguration)
            }
            let stickerSettings = context.sharedContext.accountManager.transaction { transaction -> StickerSettings in
                let stickerSettings: StickerSettings = (transaction.getSharedData(ApplicationSpecificSharedDataKeys.stickerSettings) as? StickerSettings) ?? .defaultSettings
                return stickerSettings
            }

            let stickers: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = combineLatest(stickerConfiguration, stickerSettings)
            |> castError(ChatContextQueryError.self)
            |> mapToSignal { stickerConfiguration, stickerSettings -> Signal<[FoundStickerItem], ChatContextQueryError> in
                let scope: SearchStickersScope
                switch stickerSettings.emojiStickerSuggestionMode {
                    case .none:
                        scope = []
                    case .all:
                        if stickerConfiguration.disableLocalSuggestions {
                            scope = [.remote]
                        } else {
                            scope = [.installed, .remote]
                        }
                    case .installed:
                        scope = [.installed]
                }
                return searchStickers(account: context.account, query: query.basicEmoji.0, scope: scope)
                |> castError(ChatContextQueryError.self)
            }
            |> map { stickers -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                return { _ in
                    return .stickers(stickers)
                }
            }
            return signal |> then(stickers)
        case let .hashtag(query):
            var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = .complete()
            if let previousQuery = previousQuery {
                switch previousQuery {
                    case .hashtag:
                        break
                    default:
                        signal = .single({ _ in return .hashtags([]) })
                }
            } else {
                signal = .single({ _ in return .hashtags([]) })
            }
            
            let hashtags: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = recentlyUsedHashtags(postbox: context.account.postbox)
                |> map { hashtags -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                let normalizedQuery = query.lowercased()
                var result: [String] = []
                for hashtag in hashtags {
                    if hashtag.lowercased().hasPrefix(normalizedQuery) {
                        result.append(hashtag)
                    }
                }
                return { _ in return .hashtags(result) }
            }
            |> castError(ChatContextQueryError.self)
            
            return signal |> then(hashtags)
        case let .mention(query, types):
            let normalizedQuery = query.lowercased()
            
            var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = .complete()
            if let previousQuery = previousQuery {
                switch previousQuery {
                    case .mention:
                        break
                    default:
                        signal = .single({ _ in return .mentions([]) })
                }
            } else {
                signal = .single({ _ in return .mentions([]) })
            }
            
            let inlineBots: Signal<[(Peer, Double)], NoError> = types.contains(.contextBots) ? recentlyUsedInlineBots(postbox: context.account.postbox) : .single([])
            let participants = combineLatest(inlineBots, searchPeerMembers(context: context, peerId: peer.id, chatLocation: chatLocation, query: query, scope: .mention))
            |> map { inlineBots, peers -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                let filteredInlineBots = inlineBots.sorted(by: { $0.1 > $1.1 }).filter { peer, rating in
                    if rating < 0.14 {
                        return false
                    }
                    if peer.indexName.matchesByTokens(normalizedQuery) {
                        return true
                    }
                    if let addressName = peer.addressName, addressName.lowercased().hasPrefix(normalizedQuery) {
                        return true
                    }
                    return false
                }.map { $0.0 }
                
                let inlineBotPeerIds = Set(filteredInlineBots.map { $0.id })
                
                let filteredPeers = peers.filter { peer in
                    if inlineBotPeerIds.contains(peer.id) {
                        return false
                    }
                    if !types.contains(.accountPeer) && peer.id == context.account.peerId {
                        return false
                    }
                    return true
                }
                var sortedPeers = filteredInlineBots
                sortedPeers.append(contentsOf: filteredPeers.sorted(by: { lhs, rhs in
                    let result = lhs.indexName.indexName(.lastNameFirst).compare(rhs.indexName.indexName(.lastNameFirst))
                    return result == .orderedAscending
                }))
                sortedPeers = sortedPeers.filter { peer in
                    return !peer.debugDisplayTitle.isEmpty
                }
                return { _ in return .mentions(sortedPeers) }
            }
            |> castError(ChatContextQueryError.self)
            
            return signal |> then(participants)
        case let .command(query):
            let normalizedQuery = query.lowercased()
            
            var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = .complete()
            if let previousQuery = previousQuery {
                switch previousQuery {
                    case .command:
                        break
                    default:
                        signal = .single({ _ in return .commands([]) })
                }
            } else {
                signal = .single({ _ in return .commands([]) })
            }
            
            let commands = peerCommands(account: context.account, id: peer.id)
            |> map { commands -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                let filteredCommands = commands.commands.filter { command in
                    if command.command.text.hasPrefix(normalizedQuery) {
                        return true
                    }
                    return false
                }
                let sortedCommands = filteredCommands
                return { _ in return .commands(sortedCommands) }
            }
            |> castError(ChatContextQueryError.self)
            return signal |> then(commands)
        case let .contextRequest(addressName, query):
            var delayRequest = true
            var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = .complete()
            if let previousQuery = previousQuery {
                switch previousQuery {
                    case let .contextRequest(currentAddressName, currentContextQuery) where currentAddressName == addressName:
                        if query.isEmpty && !currentContextQuery.isEmpty {
                            delayRequest = false
                        }
                    default:
                        delayRequest = false
                        signal = .single({ _ in return .contextRequestResult(nil, nil) })
                }
            } else {
                signal = .single({ _ in return .contextRequestResult(nil, nil) })
            }
            
            let chatPeer = peer
            let contextBot = resolvePeerByName(account: context.account, name: addressName)
            |> mapToSignal { peerId -> Signal<Peer?, NoError> in
                if let peerId = peerId {
                    return context.account.postbox.loadedPeerWithId(peerId)
                    |> map { peer -> Peer? in
                        return peer
                    }
                    |> take(1)
                } else {
                    return .single(nil)
                }
            }
            |> castError(ChatContextQueryError.self)
            |> mapToSignal { peer -> Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> in
                if let user = peer as? TelegramUser, let botInfo = user.botInfo, let _ = botInfo.inlinePlaceholder {
                    let contextResults = requestChatContextResults(account: context.account, botId: user.id, peerId: chatPeer.id, query: query, location: context.sharedContext.locationManager.flatMap { locationManager -> Signal<(Double, Double)?, NoError> in
                        return `deferred` {
                            Queue.mainQueue().async {
                                requestBotLocationStatus(user.id)
                            }
                            
                            return ApplicationSpecificNotice.inlineBotLocationRequestStatus(accountManager: context.sharedContext.accountManager, peerId: user.id)
                            |> filter { $0 }
                            |> take(1)
                            |> mapToSignal { _ -> Signal<(Double, Double)?, NoError> in
                                return currentLocationManagerCoordinate(manager: locationManager, timeout: 5.0)
                                |> flatMap { coordinate -> (Double, Double) in
                                    return (coordinate.latitude, coordinate.longitude)
                                }
                            }
                        }
                    } ?? .single(nil), offset: "")
                    |> mapError { error -> ChatContextQueryError in
                        return .inlineBotLocationRequest(user.id)
                    }
                    |> map { results -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                        return { _ in
                            return .contextRequestResult(user, results?.results)
                        }
                    }
                    
                    let botResult: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = .single({ previousResult in
                        var passthroughPreviousResult: ChatContextResultCollection?
                        if let previousResult = previousResult {
                            if case let .contextRequestResult(previousUser, previousResults) = previousResult {
                                if previousUser?.id == user.id {
                                    passthroughPreviousResult = previousResults
                                }
                            }
                        }
                        return .contextRequestResult(user, passthroughPreviousResult)
                    })
                    
                    let maybeDelayedContextResults: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError>
                    if delayRequest {
                        maybeDelayedContextResults = contextResults
                        |> delay(0.4, queue: Queue.concurrentDefaultQueue())
                    } else {
                        maybeDelayedContextResults = contextResults
                    }
                    
                    return botResult |> then(maybeDelayedContextResults)
                } else {
                    return .single({ _ in return nil })
                }
            }
            
            return signal |> then(contextBot)
        case let .emojiSearch(query, languageCode, range):
            var signal = searchEmojiKeywords(postbox: context.account.postbox, inputLanguageCode: languageCode, query: query, completeMatch: query.count < 2)
            if !languageCode.lowercased().hasPrefix("en") {
                signal = signal
                |> mapToSignal { keywords in
                    return .single(keywords)
                    |> then(
                        searchEmojiKeywords(postbox: context.account.postbox, inputLanguageCode: "en-US", query: query, completeMatch: query.count < 3)
                        |> map { englishKeywords in
                            return keywords + englishKeywords
                        }
                    )
                }
            }
            
            return signal
            |> map { keywords -> [(String, String)] in
                var result: [(String, String)] = []
                for keyword in keywords {
                    for emoticon in keyword.emoticons {
                        result.append((emoticon, keyword.keyword))
                    }
                }
                return result
            }
            |> map { result -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                return { _ in return .emojis(result, range) }
            }
            |> castError(ChatContextQueryError.self)
    }
}

func searchQuerySuggestionResultStateForChatInterfacePresentationState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentQuery: ChatPresentationInputQuery?) -> (ChatPresentationInputQuery?, Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>)? {
    var inputQuery: ChatPresentationInputQuery?
    if let search = chatPresentationInterfaceState.search {
        switch search.domain {
            case .members:
                inputQuery = .mention(query: search.query, types: [.members, .accountPeer])
            default:
                break
        }
    }
    
    if let inputQuery = inputQuery {
        if inputQuery == currentQuery {
            return nil
        } else {
            switch inputQuery {
                case let .mention(query, _):
                    if let peer = chatPresentationInterfaceState.renderedPeer?.peer {
                        var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
                        if let currentQuery = currentQuery {
                            switch currentQuery {
                            case .mention:
                                break
                            default:
                                signal = .single({ _ in return nil })
                            }
                        }
                        
                        let participants = searchPeerMembers(context: context, peerId: peer.id, chatLocation: chatPresentationInterfaceState.chatLocation, query: query, scope: .memberSuggestion)
                        |> map { peers -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                            let filteredPeers = peers
                            var sortedPeers: [Peer] = []
                            sortedPeers.append(contentsOf: filteredPeers.sorted(by: { lhs, rhs in
                                let result = lhs.indexName.indexName(.lastNameFirst).compare(rhs.indexName.indexName(.lastNameFirst))
                                return result == .orderedAscending
                            }))
                            return { _ in return .mentions(sortedPeers) }
                        }
                        
                        return (inputQuery, signal |> then(participants))
                    } else {
                        return (nil, .single({ _ in return nil }))
                    }
                default:
                    return (nil, .single({ _ in return nil }))
            }
        }
    } else {
        return (nil, .single({ _ in return nil }))
    }
}

private let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType([.link]).rawValue)

func detectUrl(_ inputText: NSAttributedString?) -> String? {
    var detectedUrl: String?
    if let text = inputText, let dataDetector = dataDetector {
        let utf16 = text.string.utf16
        
        let nsRange = NSRange(location: 0, length: utf16.count)
        let matches = dataDetector.matches(in: text.string, options: [], range: nsRange)
        if let match = matches.first {
            let urlText = (text.string as NSString).substring(with: match.range)
            detectedUrl = urlText
        }
        
        if detectedUrl == nil {
            inputText?.enumerateAttribute(ChatTextInputAttributes.textUrl, in: nsRange, options: [], using: { value, range, stop in
                if let value = value as? ChatTextInputTextUrlAttribute {
                    detectedUrl = value.url
                }
            })
        }
    }
    return detectedUrl
}

func urlPreviewStateForInputText(_ inputText: NSAttributedString?, context: AccountContext, currentQuery: String?) -> (String?, Signal<(TelegramMediaWebpage?) -> TelegramMediaWebpage?, NoError>)? {
    guard let _ = inputText else {
        if currentQuery != nil {
            return (nil, .single({ _ in return nil }))
        } else {
            return nil
        }
    }
    if let _ = dataDetector {
        let detectedUrl = detectUrl(inputText)
        if detectedUrl != currentQuery {
            if let detectedUrl = detectedUrl {
                return (detectedUrl, webpagePreview(account: context.account, url: detectedUrl) |> map { value in
                    return { _ in return value }
                })
            } else {
                return (nil, .single({ _ in return nil }))
            }
        } else {
            return nil
        }
    } else {
        return (nil, .single({ _ in return nil }))
    }
}
