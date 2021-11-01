/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a content and media value into a content and media render section.
struct ContentAndMediaRenderTranslator: SemanticTranslator {
    
    /// Translates a content and media value into a content and media render section.
    func translate(_ contentAndMedia: ContentAndMedia, visitor: inout RenderNodeTranslator) -> ContentAndMediaSection {
        var layout: ContentAndMediaSection.Layout? {
            switch contentAndMedia.layout {
            case .horizontal: return .horizontal
            case .vertical: return .vertical
            case nil: return nil
            }
        }

        let mediaReference = contentAndMedia.media.map { visitor.visit($0) } as? RenderReferenceIdentifier
        var section = ContentAndMediaSection(
            layout: layout,
            title: contentAndMedia.title,
            media: mediaReference,
            mediaPosition: contentAndMedia.mediaPosition
        )
        
        section.eyebrow = contentAndMedia.eyebrow
        section.content = MarkupContainerRenderTranslator().translate(contentAndMedia.content, visitor: &visitor)
        
        return section
    }
}
