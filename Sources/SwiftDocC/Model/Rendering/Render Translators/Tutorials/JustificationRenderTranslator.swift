/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a justification value into an array of render block content elements.
struct JustificationRenderTranslator: SemanticTranslator {
    
    /// Translates a justification value into an array of render block content elements.
    func translate(_ justification: Justification, visitor: inout RenderNodeTranslator) -> [RenderBlockContent] {
        MarkupContainerRenderTranslator().translate(justification.content, visitor: &visitor)
    }
}
