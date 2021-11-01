/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a volume into a volume render section.
struct VolumeRenderTranslator: SemanticTranslator {
    
    /// Translates a volume into a volume render section.
    func translate(_ volume: Volume, visitor: inout RenderNodeTranslator) -> VolumeRenderSection {
        var volumeSection = VolumeRenderSection(name: volume.name)
        volumeSection.image = volume.image.map { ImageMediaRenderTranslator().translate($0, visitor: &visitor) }
        
        volumeSection.content = volume.content.map {
            MarkupContainerRenderTranslator().translate($0, visitor: &visitor)
        }
        
        volumeSection.chapters = volume.chapters.compactMap {
            ChapterRenderTranslator().translate($0, visitor: &visitor)
        } 
        
        return volumeSection
    }
}
