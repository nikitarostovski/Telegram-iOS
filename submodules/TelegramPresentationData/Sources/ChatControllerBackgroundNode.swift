import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import SyncCore
import Display
import SwiftSignalKit
import Postbox
import MediaResources
import AppBundle

private var backgroundImageForWallpaper: (TelegramWallpaper, Bool, UIImage)?

public func chatControllerBackgroundImage(theme: PresentationTheme?, wallpaper initialWallpaper: TelegramWallpaper, mediaBox: MediaBox, composed: Bool = true, knockoutMode: Bool, cached: Bool = true) -> UIImage? {
    var wallpaper = initialWallpaper
    if knockoutMode, let theme = theme {
        switch theme.name {
        case let .builtin(name):
            switch name {
            case .day, .night, .nightAccent:
                wallpaper = theme.chat.defaultWallpaper
            case .dayClassic:
                break
            }
        case .custom:
            break
        }
    }
    
    var backgroundImage: UIImage?
    if cached && composed && wallpaper == backgroundImageForWallpaper?.0, (wallpaper.settings?.blur ?? false) == backgroundImageForWallpaper?.1 {
        backgroundImage = backgroundImageForWallpaper?.2
    } else {
        var succeed = true
        switch wallpaper {
            case let .animatedGradient(color1, color2, color3, color4, settings):
                backgroundImage = generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
                    context.setFillColor(UIColor.systemPink.withAlphaComponent(1.0).cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                })
                break
            case .builtin:
                if let filePath = getAppBundle().path(forResource: "ChatWallpaperBuiltin0", ofType: "jpg") {
                    backgroundImage = UIImage(contentsOfFile: filePath)?.precomposed()
                }
            case let .color(color):
                backgroundImage = generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
                    context.setFillColor(UIColor(argb: color).withAlphaComponent(1.0).cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                })
            case let .gradient(topColor, bottomColor, settings):
                backgroundImage = generateImage(CGSize(width: 640.0, height: 1280.0), rotatedContext: { size, context in
                    let gradientColors = [UIColor(argb: topColor).cgColor, UIColor(argb: bottomColor).cgColor] as CFArray
                       
                    var locations: [CGFloat] = [0.0, 1.0]
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!

                    context.translateBy(x: 320.0, y: 640.0)
                    context.rotate(by: CGFloat(settings.rotation ?? 0) * CGFloat.pi / 180.0)
                    context.translateBy(x: -320.0, y: -640.0)
                    
                    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                })
            case let .image(representations, settings):
                if let largest = largestImageRepresentation(representations) {
                    if settings.blur && composed {
                        var image: UIImage?
                        let _ = mediaBox.cachedResourceRepresentation(largest.resource, representation: CachedBlurredWallpaperRepresentation(), complete: true, fetch: true, attemptSynchronously: true).start(next: { data in
                            if data.complete {
                                image = UIImage(contentsOfFile: data.path)?.precomposed()
                            }
                        })
                        backgroundImage = image
                    }
                    if backgroundImage == nil, let path = mediaBox.completedResourcePath(largest.resource) {
                        succeed = false
                        backgroundImage = UIImage(contentsOfFile: path)?.precomposed()
                    }
                }
            case let .file(file):
                if wallpaper.isPattern, let color = file.settings.color, let intensity = file.settings.intensity {
                    var image: UIImage?
                    let _ = mediaBox.cachedResourceRepresentation(file.file.resource, representation: CachedPatternWallpaperRepresentation(color: color, bottomColor: file.settings.bottomColor, intensity: intensity, rotation: file.settings.rotation), complete: true, fetch: true, attemptSynchronously: true).start(next: { data in
                        if data.complete {
                            image = UIImage(contentsOfFile: data.path)?.precomposed()
                        }
                    })
                    backgroundImage = image
                } else {
                    if file.settings.blur && composed {
                        var image: UIImage?
                        let _ = mediaBox.cachedResourceRepresentation(file.file.resource, representation: CachedBlurredWallpaperRepresentation(), complete: true, fetch: true, attemptSynchronously: true).start(next: { data in
                            if data.complete {
                                image = UIImage(contentsOfFile: data.path)?.precomposed()
                            }
                        })
                        backgroundImage = image
                    }
                    if backgroundImage == nil, let path = mediaBox.completedResourcePath(file.file.resource) {
                        succeed = false
                        backgroundImage = UIImage(contentsOfFile: path)?.precomposed()
                    }
                }
        }
        if let backgroundImage = backgroundImage, composed && succeed {
            backgroundImageForWallpaper = (wallpaper, (wallpaper.settings?.blur ?? false), backgroundImage)
        }
    }
    return backgroundImage
}

public typealias AnimatedBackgroundColors = (UInt32, UInt32, UInt32, UInt32)

private var signalBackgroundImageForWallpaper: (TelegramWallpaper, Bool, UIImage)?

public func chatControllerBackgroundImageSignal(wallpaper: TelegramWallpaper, mediaBox: MediaBox, accountMediaBox: MediaBox) -> Signal<(UIImage?, AnimatedBackgroundColors?, Bool)?, NoError> {
    
    var backgroundImage: UIImage?
    if wallpaper == signalBackgroundImageForWallpaper?.0, (wallpaper.settings?.blur ?? false) == signalBackgroundImageForWallpaper?.1, let image = signalBackgroundImageForWallpaper?.2 {
        return .single((image, nil, true))
    } else {
        func cacheWallpaper(_ image: UIImage?) {
            if let image = image {
                Queue.mainQueue().async {
                    signalBackgroundImageForWallpaper = (wallpaper, (wallpaper.settings?.blur ?? false), image)
                }
            }
        }
        
        switch wallpaper {
            case let .animatedGradient(color1, color2, color3, color4, settings):
                return .single((nil, (color1, color2, color3, color4), true))
                |> afterNext { image in
                    cacheWallpaper(image?.0)
                }
            case .builtin:
                if let filePath = getAppBundle().path(forResource: "ChatWallpaperBuiltin0", ofType: "jpg") {
                    return .single((UIImage(contentsOfFile: filePath)?.precomposed(), nil, true))
                    |> afterNext { image in
                        cacheWallpaper(image?.0)
                    }
                }
            case let .color(color):
                return .single((generateImage(CGSize(width: 1.0, height: 1.0), rotatedContext: { size, context in
                    context.setFillColor(UIColor(argb: color).withAlphaComponent(1.0).cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                }), nil, true))
                |> afterNext { image in
                    cacheWallpaper(image?.0)
                }
            case let .gradient(topColor, bottomColor, settings):
                return .single((generateImage(CGSize(width: 640.0, height: 1280.0), rotatedContext: { size, context in
                    let gradientColors = [UIColor(argb: topColor).cgColor, UIColor(argb: bottomColor).cgColor] as CFArray
                       
                    var locations: [CGFloat] = [0.0, 1.0]
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!

                    context.translateBy(x: 320.0, y: 640.0)
                    context.rotate(by: CGFloat(settings.rotation ?? 0) * CGFloat.pi / 180.0)
                    context.translateBy(x: -320.0, y: -640.0)
                    
                    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                }), nil, true))
                |> afterNext { image in
                    cacheWallpaper(image?.0)
                }
            case let .image(representations, settings):
                if let largest = largestImageRepresentation(representations) {
                    if settings.blur {
                        return mediaBox.cachedResourceRepresentation(largest.resource, representation: CachedBlurredWallpaperRepresentation(), complete: true, fetch: true, attemptSynchronously: true)
                        |> map { data -> (UIImage?, (UInt32, UInt32, UInt32, UInt32)?, Bool)? in
                            if data.complete {
                                return (UIImage(contentsOfFile: data.path)?.precomposed(), nil, true)
                            } else {
                                return nil
                            }
                        }
                        |> afterNext { image in
                            cacheWallpaper(image?.0)
                        }
                    } else if let path = mediaBox.completedResourcePath(largest.resource) {
                        return .single((UIImage(contentsOfFile: path)?.precomposed(), nil, true))
                        |> afterNext { image in
                            cacheWallpaper(image?.0)
                        }
                    }
                }
            case let .file(file):
                if wallpaper.isPattern, let color = file.settings.color, let intensity = file.settings.intensity {
                    let representation = CachedPatternWallpaperRepresentation(color: color, bottomColor: file.settings.bottomColor, intensity: intensity, rotation: file.settings.rotation)
                    
                    let effectiveMediaBox: MediaBox
                    if FileManager.default.fileExists(atPath: mediaBox.cachedRepresentationCompletePath(file.file.resource.id, representation: representation)) {
                        effectiveMediaBox = mediaBox
                    } else {
                        effectiveMediaBox = accountMediaBox
                    }
                    
                    return effectiveMediaBox.cachedResourceRepresentation(file.file.resource, representation: representation, complete: true, fetch: true, attemptSynchronously: true)
                    |> take(1)
                    |> mapToSignal { data -> Signal<(UIImage?, (UInt32, UInt32, UInt32, UInt32)?, Bool)?, NoError> in
                        if data.complete {
                            return .single((UIImage(contentsOfFile: data.path)?.precomposed(), nil, true))
                        } else {
                            let interimWallpaper: TelegramWallpaper
                            if let secondColor = file.settings.bottomColor {
                                interimWallpaper = .gradient(color, secondColor, file.settings)
                            } else {
                                interimWallpaper = .color(color)
                            }
                            
                            let settings = file.settings
                            let interrimImage = generateImage(CGSize(width: 640.0, height: 1280.0), rotatedContext: { size, context in
                                if let color = settings.color {
                                    let gradientColors = [UIColor(argb: color).cgColor, UIColor(argb: settings.bottomColor ?? color).cgColor] as CFArray
                                    
                                    var locations: [CGFloat] = [0.0, 1.0]
                                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                                    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                                    
                                    context.translateBy(x: 320.0, y: 640.0)
                                    context.rotate(by: CGFloat(settings.rotation ?? 0) * CGFloat.pi / 180.0)
                                    context.translateBy(x: -320.0, y: -640.0)
                                    
                                    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                                }
                            })

                            return .single((interrimImage, nil, false)) |> then(effectiveMediaBox.cachedResourceRepresentation(file.file.resource, representation: CachedPatternWallpaperRepresentation(color: color, bottomColor: file.settings.bottomColor, intensity: intensity, rotation: file.settings.rotation), complete: true, fetch: true, attemptSynchronously: false)
                            |> map { data -> (UIImage?, (UInt32, UInt32, UInt32, UInt32)?, Bool)? in
                                return (UIImage(contentsOfFile: data.path)?.precomposed(), nil, true)
                            })
                        }
                    }
                    |> afterNext { image in
                        cacheWallpaper(image?.0)
                    }
                } else {
                    if file.settings.blur {
                        let representation = CachedBlurredWallpaperRepresentation()
                        
                        let effectiveMediaBox: MediaBox
                        if FileManager.default.fileExists(atPath: mediaBox.cachedRepresentationCompletePath(file.file.resource.id, representation: representation)) {
                            effectiveMediaBox = mediaBox
                        } else {
                            effectiveMediaBox = accountMediaBox
                        }
                        
                        return effectiveMediaBox.cachedResourceRepresentation(file.file.resource, representation: representation, complete: true, fetch: true, attemptSynchronously: true)
                        |> map { data -> (UIImage?, (UInt32, UInt32, UInt32, UInt32)?, Bool)? in
                            if data.complete {
                                return (UIImage(contentsOfFile: data.path)?.precomposed(), nil, true)
                            } else {
                                return nil
                            }
                        }
                        |> afterNext { image in
                            cacheWallpaper(image?.0)
                        }
                    } else {
                        var path: String?
                        if let maybePath = mediaBox.completedResourcePath(file.file.resource) {
                            path = maybePath
                        } else if let maybePath = accountMediaBox.completedResourcePath(file.file.resource) {
                            path = maybePath
                        }
                        if let path = path {
                            return .single((UIImage(contentsOfFile: path)?.precomposed(), nil, true))
                            |> afterNext { image in
                                cacheWallpaper(image?.0)
                            }
                        }
                    }
                }
        }
    }
    return .complete()
}
