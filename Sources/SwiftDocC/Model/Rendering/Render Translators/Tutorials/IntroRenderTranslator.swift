/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates an intro value into a render reference identifier.
struct IntroRenderTranslator: SemanticTranslator {
    
    /// Translates an intro value into an intro render section.
    func translate(_ intro: Intro, visitor: inout RenderNodeTranslator) -> IntroRenderSection {
        var section = IntroRenderSection(title: intro.title)
        section.content = MarkupContainerRenderTranslator().translate(intro.content, visitor: &visitor)
        
        section.image = intro.image.map { ImageMediaRenderTranslator().translate($0, visitor: &visitor) }
        section.video = intro.video.map { VideoMediaRenderTranslator().translate($0, visitor: &visitor) }
        
        // Set the Intro's background image to the video's poster image.
        section.backgroundImage = intro.video?.poster.map { visitor.createAndRegisterRenderReference(forMedia: $0) }
            ?? intro.image.map { visitor.createAndRegisterRenderReference(forMedia: $0.source) }
        
        return section
    }
}
