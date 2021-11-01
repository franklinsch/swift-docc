/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A type that translates a sequence of markup values into an array of render inline content elements.
struct MarkupSequenceRenderTranslator {
    
    /// Translates a sequence of markup values into an array of render inline content elements.
    func translate(_ markups: [Markup], visitor: inout RenderNodeTranslator) -> [RenderInlineContent] {
        var contentCompiler = RenderContentCompiler(
            context: visitor.context,
            bundle: visitor.bundle,
            identifier: visitor.identifier
        )
        
        let content = markups.reduce(into: []) { result, item in
            result.append(contentsOf: contentCompiler.visit(item))
        } as! [RenderInlineContent]
        
        visitor.collectedTopicReferences.append(contentsOf: contentCompiler.collectedTopicReferences)
        // Copy all the image references.
        visitor.imageReferences.merge(contentCompiler.imageReferences) { (_, new) in new }
        
        return content
    }
}
