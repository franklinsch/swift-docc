/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a tile into a render tile.
struct TileRenderTranslator: SemanticTranslator {
    
    /// Translates a tile into a render tile.
    func translate(_ tile: Tile, visitor: inout RenderNodeTranslator) -> RenderTile {
        let action = tile.destination.map {
            visitor.visitLink($0, defaultTitle: RenderTile.defaultCallToActionTitle(for: tile.identifier))
        }
        
        var section = RenderTile(
            identifier: .init(tileIdentifier: tile.identifier),
            title: tile.title,
            action: action,
            media: nil
        )
        section.content = MarkupContainerRenderTranslator().translate(tile.content, visitor: &visitor)
        
        return section
    }
}
