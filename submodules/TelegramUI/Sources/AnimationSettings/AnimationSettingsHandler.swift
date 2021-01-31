//
//  AnimationSettingsHandler.swift
//  settingsui
//
//  Created by Nikita Rostovskii on 25.01.2021.
//

import UIKit

struct AnimationCurve: Codable {
    
    var x1: Float
    var y1: Float
    
    var x2: Float
    var y2: Float
    
    var delay: Float
    var duration: Float
    
    init(tuple: (Float, Float, Float, Float), delay: Float, duration: Float) {
        self.duration = duration
        self.delay = delay
        self.x1 = tuple.0
        self.y1 = tuple.1
        self.x2 = tuple.2
        self.y2 = tuple.3
    }
    
    var tuple: (Float, Float, Float, Float) {
        return (x1, y1, x2, y2)
    }
}

enum SettingsType: String, Codable, CaseIterable {
    case smallMessage = "Text Message"
//    case bigMessage = "Big Message"
    case linkPreview = "Link with Preview"
    case singleEmoji = "Single Emoji"
    case sticker = "Sticker"
    case voice = "Voice Message"
    case video = "Video Message"
    case background = "Background"
}

class AnimSettingsHandler {
    
    private static let saveKey = "AnimationContest"

    
    var data: [SettingsType: AnimSettings]
    
    var activeType: SettingsType
    var activeSettings: AnimSettings { data[activeType]! }

    init(data: [SettingsType: AnimSettings]) {
        var data = data
        if data[.background] == nil {
            data[.background] = BackgroundSettings.defaults
        }
        if data[.smallMessage] == nil {
            data[.smallMessage] = SmallMessageSettings.defaults
        }
//        if data[.bigMessage] == nil {
//            data[.bigMessage] = BigMessageSettings.defaults
//        }
        if data[.linkPreview] == nil {
            data[.linkPreview] = LinkWithPreviewSettings.defaults
        }
        if data[.singleEmoji] == nil {
            data[.singleEmoji] = EmojiMessageSettings.defaults
        }
        if data[.sticker] == nil {
            data[.sticker] = StickerMessageSettings.defaults
        }
        if data[.voice] == nil {
            data[.voice] = VoiceMessageSettings.defaults
        }
        if data[.video] == nil {
            data[.video] = VideoMessageSettings.defaults
        }
        self.data = data
        self.activeType = .smallMessage
    }
    
    private struct SettingsPair: Codable {
        var key: String
        var value: String
    }
    
    func exportSettings() -> String? {
        let encoder = JSONEncoder()
        var settings = [SettingsPair]()
        for (key, value) in data {
            if let data = value.makeData(encoder: encoder),
               let string = String(data: data, encoding: .utf8)  {
                
                settings.append(SettingsPair(key: key.rawValue, value: string))
            }
        }
        guard let result = try? encoder.encode(settings) else { return nil }
        return String(data: result, encoding: .utf8)
    }
    
    static func importSettings(string: String) -> AnimSettingsHandler? {
        guard let d = string.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        guard let objects = try? decoder.decode([SettingsPair].self, from: d) else { return nil }
        
        var data: [SettingsType: AnimSettings] = [:]
        
        for object in objects {
            guard let key = SettingsType(rawValue: object.key), let value = object.value.data(using: .utf8) else { continue }
            
            let obj: AnimSettings?
            switch key {
            case .smallMessage:
                obj = SmallMessageSettings.makeFromData(value, decoder: decoder)
//            case .bigMessage:
//                obj = BigMessageSettings.makeFromData(value, decoder: decoder)
            case .linkPreview:
                obj = LinkWithPreviewSettings.makeFromData(value, decoder: decoder)
            case .singleEmoji:
                obj = EmojiMessageSettings.makeFromData(value, decoder: decoder)
            case .sticker:
                obj = StickerMessageSettings.makeFromData(value, decoder: decoder)
            case .voice:
                obj = VoiceMessageSettings.makeFromData(value, decoder: decoder)
            case .video:
                obj = VideoMessageSettings.makeFromData(value, decoder: decoder)
            case .background:
                obj = BackgroundSettings.makeFromData(value, decoder: decoder)
            }
            if let o = obj {
                data[key] = o
            }
        }
        return AnimSettingsHandler(data: data)
    }
    
    func save() {
        let encoder = JSONEncoder()
        let defaults = UserDefaults.standard
        
        for (key, value) in data {
            if let data = value.makeData(encoder: encoder) {
                defaults.set(data, forKey: "\(Self.saveKey).\(key.rawValue)")
            }
        }
        defaults.synchronize()
        AnimationManager.shared.settings = self
    }
    
    static func loadDefaults() -> AnimSettingsHandler {
        let data: [SettingsType: AnimSettings] = [
            .smallMessage: SmallMessageSettings.defaults,
//            .bigMessage: BigMessageSettings.defaults,
            .linkPreview: LinkWithPreviewSettings.defaults,
            .singleEmoji: EmojiMessageSettings.defaults,
            .sticker: StickerMessageSettings.defaults,
            .video: VideoMessageSettings.defaults,
            .voice: VoiceMessageSettings.defaults,
            .background: BackgroundSettings.defaults
        ]
        return AnimSettingsHandler(data: data)
    }
    
    static func load() -> AnimSettingsHandler {
        let decoder = JSONDecoder()
        let defaults = UserDefaults.standard
        
        var data: [SettingsType: AnimSettings] = [:]
        
        for key in SettingsType.allCases {
            if let value = defaults.data(forKey: "\(saveKey).\(key.rawValue)") {
                let obj: AnimSettings?
                switch key {
                case .smallMessage:
                    obj = SmallMessageSettings.makeFromData(value, decoder: decoder)
//                case .bigMessage:
//                    obj = BigMessageSettings.makeFromData(value, decoder: decoder)
                case .linkPreview:
                    obj = LinkWithPreviewSettings.makeFromData(value, decoder: decoder)
                case .singleEmoji:
                    obj = EmojiMessageSettings.makeFromData(value, decoder: decoder)
                case .sticker:
                    obj = StickerMessageSettings.makeFromData(value, decoder: decoder)
                case .voice:
                    obj = VoiceMessageSettings.makeFromData(value, decoder: decoder)
                case .video:
                    obj = VideoMessageSettings.makeFromData(value, decoder: decoder)
                case .background:
                    obj = BackgroundSettings.makeFromData(value, decoder: decoder)
                }
                if let o = obj {
                    data[key] = o
                }
            }
        }
        return AnimSettingsHandler(data: data)
    }
}


enum DurationType: Int, Codable {
    
    case frames30 = 30
    case frames45 = 45
    case frames60 = 60
    
    var seconds: Float {
        return Float(rawValue) / 60.0
    }
}

protocol AnimSettings: class, Codable {
    
    var durationType: DurationType { get set }
    
    static var defaults: AnimSettings { get }
    
    func makeData(encoder: JSONEncoder) -> Data?
    static func makeFromData(_ data: Data, decoder: JSONDecoder) -> Self?
}

extension AnimSettings {
    
    func makeData(encoder: JSONEncoder) -> Data? {
        if let encoded = try? encoder.encode(self) {
            return encoded
        }
        return nil
    }
    
    static func makeFromData(_ data: Data, decoder: JSONDecoder) -> Self? {
        if let decoded = try? decoder.decode(Self.self, from: data) {
            return decoded
        }
        return nil
    }
    
}














class BackgroundSettings: AnimSettings {
    
    var color1: String
    var color2: String
    var color3: String
    var color4: String
    
    var col1: UIColor { UIColor(hex: color1) ?? .white }
    var col2: UIColor { UIColor(hex: color2) ?? .white }
    var col3: UIColor { UIColor(hex: color3) ?? .white }
    var col4: UIColor { UIColor(hex: color4) ?? .white }
    
    var curve: AnimationCurve
    
    var durationType: DurationType
    
    init(color1: String, color2: String, color3: String, color4: String, curve: (Float, Float, Float, Float), duration: Float, delay: Float, durationType: DurationType) {
        self.color1 = color1
        self.color2 = color2
        self.color3 = color3
        self.color4 = color4
        self.curve = AnimationCurve(tuple: curve, delay: delay, duration: duration)
        self.durationType = durationType
    }
    
    static var defaults: AnimSettings {
        return BackgroundSettings(color1: "FFF6BF",
                                  color2: "76A076",
                                  color3: "F6E477",
                                  color4: "316B4D",
                                  curve: (0.3, 0, 0.7, 1),
                                  duration: 1,
                                  delay: 0,
                                  durationType: .frames30)
    }
    
    
}


class SmallMessageSettings: AnimSettings {
    
    var curveX: AnimationCurve
    var curveY: AnimationCurve
    var curveBubble: AnimationCurve
    var curveStatus: AnimationCurve
    var durationType: DurationType
    
    init(curveX: (Float, Float, Float, Float), durationX: Float, delayX: Float,
         curveY: (Float, Float, Float, Float), durationY: Float, delayY: Float,
         curveBubble: (Float, Float, Float, Float), durationBubble: Float, delayBubble: Float,
         curveStatus: (Float, Float, Float, Float), durationStatus: Float, delayStatus: Float,
         durationType: DurationType) {
        
        
        self.curveX = AnimationCurve(tuple: curveX, delay: delayX, duration: durationX)
        self.curveY = AnimationCurve(tuple: curveY, delay: delayY, duration: durationY)
        self.curveBubble = AnimationCurve(tuple: curveBubble, delay: delayBubble, duration: durationBubble)
        self.curveStatus = AnimationCurve(tuple: curveStatus, delay: delayStatus, duration: durationStatus)
//        self.curveTime = AnimationCurve(tuple: curveTime, delay: delayTime, duration: durationTime)
        
        self.durationType = durationType
    }
    
    static let defaultCurve: (Float, Float, Float, Float) = (0.3, 0, 0.7, 1)
    static let defaultDuration: Float = 1
    static let defaultDelay: Float = 0
    static let defaultDuraionType = DurationType.frames30
    
    static var defaults: AnimSettings {
        return SmallMessageSettings(curveX: defaultCurve, durationX: defaultDuration, delayX: defaultDelay, curveY: defaultCurve, durationY: defaultDuration, delayY: defaultDelay, curveBubble: defaultCurve, durationBubble: defaultDuration, delayBubble: defaultDelay, curveStatus: defaultCurve, durationStatus: defaultDuration, delayStatus: defaultDelay, durationType: defaultDuraionType)
    }
}


//class BigMessageSettings: AnimSettings {
//
//    var curveX: AnimationCurve
//    var curveY: AnimationCurve
//    var curveBubble: AnimationCurve
//    var curveTextPos: AnimationCurve
//    var curveColor: AnimationCurve
//    var curveTime: AnimationCurve
//
//    var durationType: DurationType
//
//    init(curveX: (Float, Float, Float, Float), durationX: Float, delayX: Float,
//         curveY: (Float, Float, Float, Float), durationY: Float, delayY: Float,
//         curveBubble: (Float, Float, Float, Float), durationBubble: Float, delayBubble: Float,
//         curveTextPos: (Float, Float, Float, Float), durationTextPos: Float, delayTextPos: Float,
//         curveColor: (Float, Float, Float, Float), durationColor: Float, delayColor: Float,
//         curveTime: (Float, Float, Float, Float), durationTime: Float, delayTime: Float,
//         durationType: DurationType) {
//
//
//        self.curveX = AnimationCurve(tuple: curveX, delay: delayX, duration: durationX)
//        self.curveY = AnimationCurve(tuple: curveY, delay: delayY, duration: durationY)
//        self.curveBubble = AnimationCurve(tuple: curveBubble, delay: delayBubble, duration: durationBubble)
//        self.curveTextPos = AnimationCurve(tuple: curveTextPos, delay: delayTextPos, duration: durationTextPos)
//        self.curveColor = AnimationCurve(tuple: curveColor, delay: delayColor, duration: durationColor)
//        self.curveTime = AnimationCurve(tuple: curveTime, delay: delayTime, duration: durationTime)
//
//        self.durationType = durationType
//    }
//
//    static let defaultCurve: (Float, Float, Float, Float) = (0.2, 0, 0.6, 1)
//    static let defaultDuration: Float = 1
//    static let defaultDelay: Float = 0
//    static let defaultDuraionType = DurationType.frames30
//
//    static var defaults: AnimSettings {
//        return BigMessageSettings(curveX: defaultCurve, durationX: defaultDuration, delayX: defaultDelay, curveY: defaultCurve, durationY: defaultDuration, delayY: defaultDelay, curveBubble: defaultCurve, durationBubble: defaultDuration, delayBubble: defaultDelay, curveTextPos: defaultCurve, durationTextPos: defaultDuration, delayTextPos: defaultDelay, curveColor: defaultCurve, durationColor: defaultDuration, delayColor: defaultDelay, curveTime: defaultCurve, durationTime: defaultDuration, delayTime: defaultDelay, durationType: defaultDuraionType)
//    }
//}

class LinkWithPreviewSettings: AnimSettings {

    var curveX: AnimationCurve
    var curveY: AnimationCurve
//    var curveColor: AnimationCurve
    var curveStatus: AnimationCurve

    var durationType: DurationType

    init(curveX: (Float, Float, Float, Float), durationX: Float, delayX: Float,
         curveY: (Float, Float, Float, Float), durationY: Float, delayY: Float,
//         curveColor: (Float, Float, Float, Float), durationColor: Float, delayColor: Float,
         curveStatus: (Float, Float, Float, Float), durationStatus: Float, delayStatus: Float,
         durationType: DurationType) {


        self.curveX = AnimationCurve(tuple: curveX, delay: delayX, duration: durationX)
        self.curveY = AnimationCurve(tuple: curveY, delay: delayY, duration: durationY)
//        self.curveColor = AnimationCurve(tuple: curveColor, delay: delayColor, duration: durationColor)
        self.curveStatus = AnimationCurve(tuple: curveStatus, delay: delayStatus, duration: durationStatus)

        self.durationType = durationType
    }

    static let defaultCurve: (Float, Float, Float, Float) = (0.3, 0, 0.7, 1)
    static let defaultDuration: Float = 1
    static let defaultDelay: Float = 0
    static let defaultDuraionType = DurationType.frames30

    static var defaults: AnimSettings {
        return LinkWithPreviewSettings(curveX: defaultCurve, durationX: defaultDuration, delayX: defaultDelay, curveY: defaultCurve, durationY: defaultDuration, delayY: defaultDelay,
//                                       curveColor: defaultCurve, durationColor: defaultDuration, delayColor: defaultDelay,
                                       curveStatus: defaultCurve, durationStatus: defaultDuration, delayStatus: defaultDelay, durationType: defaultDuraionType)
    }
}

class EmojiMessageSettings: AnimSettings {
    
    var curveX: AnimationCurve
    var curveY: AnimationCurve
    var curveScale: AnimationCurve
    var curveStatus: AnimationCurve
    
    var durationType: DurationType
    
    init(curveX: (Float, Float, Float, Float), durationX: Float, delayX: Float,
         curveY: (Float, Float, Float, Float), durationY: Float, delayY: Float,
         curveScale: (Float, Float, Float, Float), durationScale: Float, delayScale: Float,
         curveStatus: (Float, Float, Float, Float), durationStatus: Float, delayStatus: Float,
         durationType: DurationType) {
        
        
        self.curveX = AnimationCurve(tuple: curveX, delay: delayX, duration: durationX)
        self.curveY = AnimationCurve(tuple: curveY, delay: delayY, duration: durationY)
        self.curveScale = AnimationCurve(tuple: curveScale, delay: delayScale, duration: durationScale)
        self.curveStatus = AnimationCurve(tuple: curveStatus, delay: delayStatus, duration: durationStatus)
        
        self.durationType = durationType
    }
    
    static let defaultCurve: (Float, Float, Float, Float) = (0.3, 0, 0.7, 1)
    static let defaultDuration: Float = 1
    static let defaultDelay: Float = 0
    static let defaultDuraionType = DurationType.frames30
    
    static var defaults: AnimSettings {
        return EmojiMessageSettings(curveX: defaultCurve, durationX: defaultDuration, delayX: defaultDelay, curveY: defaultCurve, durationY: defaultDuration, delayY: defaultDelay, curveScale: defaultCurve, durationScale: defaultDuration, delayScale: defaultDelay, curveStatus: defaultCurve, durationStatus: defaultDuration, delayStatus: defaultDelay, durationType: defaultDuraionType)
    }
}

class StickerMessageSettings: AnimSettings {
    
    var curveX: AnimationCurve
    var curveY: AnimationCurve
    var curveScale: AnimationCurve
    var curveStatus: AnimationCurve
    
    var durationType: DurationType
    
    init(curveX: (Float, Float, Float, Float), durationX: Float, delayX: Float,
         curveY: (Float, Float, Float, Float), durationY: Float, delayY: Float,
         curveScale: (Float, Float, Float, Float), durationScale: Float, delayScale: Float,
         curveStatus: (Float, Float, Float, Float), durationStatus: Float, delayStatus: Float,
         durationType: DurationType) {
        
        
        self.curveX = AnimationCurve(tuple: curveX, delay: delayX, duration: durationX)
        self.curveY = AnimationCurve(tuple: curveY, delay: delayY, duration: durationY)
        self.curveScale = AnimationCurve(tuple: curveScale, delay: delayScale, duration: durationScale)
        self.curveStatus = AnimationCurve(tuple: curveStatus, delay: delayStatus, duration: durationStatus)
        
        self.durationType = durationType
    }
    
    static let defaultCurve: (Float, Float, Float, Float) = (0.3, 0, 0.7, 1)
    static let defaultDuration: Float = 1
    static let defaultDelay: Float = 0
    static let defaultDuraionType = DurationType.frames30
    
    static var defaults: AnimSettings {
        return StickerMessageSettings(curveX: defaultCurve, durationX: defaultDuration, delayX: defaultDelay, curveY: defaultCurve, durationY: defaultDuration, delayY: defaultDelay, curveScale: defaultCurve, durationScale: defaultDuration, delayScale: defaultDelay, curveStatus: defaultCurve, durationStatus: defaultDuration, delayStatus: defaultDelay, durationType: defaultDuraionType)
    }
}

class VoiceMessageSettings: AnimSettings {
    
    var curveX: AnimationCurve
    var curveY: AnimationCurve
    var curveStatus: AnimationCurve
//    var curveTime: AnimationCurve
    
    var durationType: DurationType
    
    init(curveX: (Float, Float, Float, Float), durationX: Float, delayX: Float,
         curveY: (Float, Float, Float, Float), durationY: Float, delayY: Float,
         curveStatus: (Float, Float, Float, Float), durationStatus: Float, delayStatus: Float,
//         curveTime: (Float, Float, Float, Float), durationTime: Float, delayTime: Float,
         durationType: DurationType) {
        
        
        self.curveX = AnimationCurve(tuple: curveX, delay: delayX, duration: durationX)
        self.curveY = AnimationCurve(tuple: curveY, delay: delayY, duration: durationY)
        self.curveStatus = AnimationCurve(tuple: curveStatus, delay: delayStatus, duration: durationStatus)
//        self.curveTime = AnimationCurve(tuple: curveTime, delay: delayTime, duration: durationTime)
        
        self.durationType = durationType
    }
    
    static let defaultCurve: (Float, Float, Float, Float) = (0.3, 0, 0.7, 1)
    static let defaultDuration: Float = 1
    static let defaultDelay: Float = 0
    static let defaultDuraionType = DurationType.frames30
    
    static var defaults: AnimSettings {
        return VoiceMessageSettings(curveX: defaultCurve, durationX: defaultDuration, delayX: defaultDelay, curveY: defaultCurve, durationY: defaultDuration, delayY: defaultDelay,
                                    curveStatus: defaultCurve, durationStatus: defaultDuration, delayStatus: defaultDelay,
//                                    curveTime: defaultCurve, durationTime: defaultDuration, delayTime: defaultDelay,
                                    durationType: defaultDuraionType)
    }
}


class VideoMessageSettings: AnimSettings {
    
    var curveX: AnimationCurve
    var curveY: AnimationCurve
    var curveScale: AnimationCurve
    var curveStatus: AnimationCurve
    
    var durationType: DurationType
    
    init(curveX: (Float, Float, Float, Float), durationX: Float, delayX: Float,
         curveY: (Float, Float, Float, Float), durationY: Float, delayY: Float,
         curveScale: (Float, Float, Float, Float), durationScale: Float, delayScale: Float,
         curveStatus: (Float, Float, Float, Float), durationStatus: Float, delayStatus: Float,
         durationType: DurationType) {
        
        
        self.curveX = AnimationCurve(tuple: curveX, delay: delayX, duration: durationX)
        self.curveY = AnimationCurve(tuple: curveY, delay: delayY, duration: durationY)
        self.curveScale = AnimationCurve(tuple: curveScale, delay: delayScale, duration: durationScale)
        self.curveStatus = AnimationCurve(tuple: curveStatus, delay: delayStatus, duration: durationStatus)
        
        self.durationType = durationType
    }
    
    static let defaultCurve: (Float, Float, Float, Float) = (0.3, 0, 0.7, 1)
    static let defaultDuration: Float = 1
    static let defaultDelay: Float = 0
    static let defaultDuraionType = DurationType.frames30
    
    static var defaults: AnimSettings {
        return VideoMessageSettings(curveX: defaultCurve, durationX: defaultDuration, delayX: defaultDelay, curveY: defaultCurve, durationY: defaultDuration, delayY: defaultDelay, curveScale: defaultCurve, durationScale: defaultDuration, delayScale: defaultDelay, curveStatus: defaultCurve, durationStatus: defaultDuration, delayStatus: defaultDelay, durationType: defaultDuraionType)
    }
}
