/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A type that translates markup layouts into an array of render content layouts.
struct MarkupLayoutsRenderTranslator {
    func translate<MarkupLayouts: Sequence>(
        _ markupLayouts: MarkupLayouts,
        visitor: inout RenderNodeTranslator
    ) -> [ContentLayout] where MarkupLayouts.Element == MarkupLayout {
        markupLayouts.map { content in
            switch content {
            case .markup(let markup):
                return .fullWidth(content: MarkupContainerRenderTranslator().translate(markup, visitor: &visitor))
            case .contentAndMedia(let contentAndMedia):
                return .contentAndMedia(
                    content: ContentAndMediaRenderTranslator().translate(contentAndMedia, visitor: &visitor)
                )
            case .stack(let stack):
                return .columns(content: StackRenderTranslator().translate(stack, visitor: &visitor))
            }
        }
    }
}
