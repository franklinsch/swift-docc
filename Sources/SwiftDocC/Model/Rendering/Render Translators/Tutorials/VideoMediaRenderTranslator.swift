/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a video media into a render reference identifier.
struct VideoMediaRenderTranslator: SemanticTranslator {
    
    /// Translates a video media into a render reference identifier.
    func translate(_ videoMedia: VideoMedia, visitor: inout RenderNodeTranslator) -> RenderReferenceIdentifier {
        visitor.createAndRegisterRenderReference(forMedia: videoMedia.source, poster: videoMedia.poster)
    }
}
