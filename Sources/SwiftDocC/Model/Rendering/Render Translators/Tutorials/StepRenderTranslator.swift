/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a step value into an array of render block content.
struct StepRenderTranslator: SemanticTranslator {
    
    /// Translates a step value into an array of render block content.
    func translate(_ step: Step, visitor: inout RenderNodeTranslator) -> [RenderBlockContent] {
        let renderBlock = visitor.visitMarkupContainer(MarkupContainer(step.content)) as! [RenderBlockContent]
        let caption = visitor.visitMarkupContainer(MarkupContainer(step.caption)) as! [RenderBlockContent]
        
        let mediaReference = step.media.map { visitor.visit($0) } as? RenderReferenceIdentifier
        let codeReference = step.code.map { CodeRenderTranslator().translate($0, visitor: &visitor) }
        
        let previewReference = step.code?.preview.map {
            visitor.createAndRegisterRenderReference(forMedia: $0.source, altText: ($0 as? ImageMedia)?.altText)
        }
        
        return [
            RenderBlockContent.step(
                content: renderBlock,
                caption: caption,
                media: mediaReference,
                code: codeReference,
                runtimePreview: previewReference
            )
        ]
    }
}
