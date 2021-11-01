/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a markup container into an array of render block content elements.
struct MarkupContainerRenderTranslator: SemanticTranslator {
    
    /// Translates a markup container into an array of render block content elements.
    func translate(_ markupContainer: MarkupContainer, visitor: inout RenderNodeTranslator) -> [RenderBlockContent] {
        var contentCompiler = RenderContentCompiler(
            context: visitor.context,
            bundle: visitor.bundle,
            identifier: visitor.identifier
        )
        
        let content = markupContainer.elements.reduce(into: []) { result, item in
            result.append(contentsOf: contentCompiler.visit(item))
        } as! [RenderBlockContent]
        
        visitor.collectedTopicReferences.append(contentsOf: contentCompiler.collectedTopicReferences)
        // Copy all the image references found in the markup container.
        visitor.imageReferences.merge(contentCompiler.imageReferences) { (_, new) in new }
        visitor.linkReferences.merge(contentCompiler.linkReferences) { (_, new) in new }
        return content
    }
}
