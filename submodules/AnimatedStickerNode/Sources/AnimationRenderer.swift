import Foundation
import SwiftSignalKit
import AsyncDisplayKit

public enum AnimationRendererFrameType {
    case argb
    case yuva
}

public protocol AnimationRenderer {
    func render(queue: Queue, width: Int, height: Int, bytesPerRow: Int, data: Data, type: AnimationRendererFrameType, completion: @escaping () -> Void)
    
    func setOverlayColor(_ color: UIColor?, animated: Bool)
}
