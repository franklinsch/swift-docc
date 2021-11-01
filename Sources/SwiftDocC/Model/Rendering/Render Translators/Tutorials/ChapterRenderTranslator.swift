/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a chapter into a chapter render value.
struct ChapterRenderTranslator: SemanticTranslator {
    
    /// Translates a chapter into a chapter render value.
    ///
    /// - Returns: The chapter render value if the chapter has tutorial references, otherwise `nil`.
    func translate(_ chapter: Chapter, visitor: inout RenderNodeTranslator) -> VolumeRenderSection.Chapter? {
        guard !chapter.topicReferences.isEmpty else {
            // If the chapter has no tutorials, return `nil`.
            return nil
        }
        
        var renderChapter = VolumeRenderSection.Chapter(name: chapter.name)
        renderChapter.content = MarkupContainerRenderTranslator().translate(chapter.content, visitor: &visitor)
        
        renderChapter.tutorials = chapter.topicReferences.map {
            TutorialReferenceRenderTranslator().translate($0, visitor: &visitor)
        }
        
        renderChapter.image = chapter.image.map {
            ImageMediaRenderTranslator().translate($0, visitor: &visitor)
        }
        
        return renderChapter
    }
}
