/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a resources value into a resources render section.
struct ResourcesRenderTranslator: SemanticTranslator {
    
    /// Translates a resources value into a resources render section.
    func translate(_ resources: Resources, visitor: inout RenderNodeTranslator) -> ResourcesRenderSection {
        let tiles = resources.tiles.map { TileRenderTranslator().translate($0, visitor: &visitor) }
        let content = MarkupContainerRenderTranslator().translate(resources.content, visitor: &visitor)
        return ResourcesRenderSection(tiles: tiles, content: content)
    }
}
