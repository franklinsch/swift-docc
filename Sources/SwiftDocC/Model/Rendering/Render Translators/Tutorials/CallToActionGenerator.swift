/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

struct CallToActionGenerator {
    /// Creates a CTA for tutorials and tutorial articles.
    func createCallToAction(
        with callToActionImage: ImageMedia?,
        volume: ResolvedTopicReference,
        visitor: inout RenderNodeTranslator
    ) -> CallToActionSection? {
        // Get all the tutorials and tutorial articles in the learning path, ordered.

        var surroundingTopics = [(reference: ResolvedTopicReference, kind: DocumentationNode.Kind)]()
        visitor.context.traverseBreadthFirst(from: volume) { node in
            if node.kind == .tutorial || node.kind == .tutorialArticle {
                surroundingTopics.append((node.reference, node.kind))
            }
            return .continue
        }
        
        // Find the tutorial or article that comes after the current page, if one exists.
        let nextTopicIndex = surroundingTopics.firstIndex(where: { $0.reference == visitor.identifier }).map { $0 + 1 }
        if let nextTopicIndex = nextTopicIndex, nextTopicIndex < surroundingTopics.count {
            let nextTopicReference = surroundingTopics[nextTopicIndex]
            let nextTopicReferenceIdentifier = ResolvedTopicReferenceRenderTranslator()
                .translate(nextTopicReference.reference, visitor: &visitor)
            
            let nextTopic = try! visitor.context.entity(
                with: nextTopicReference.reference
            ).semantic as! Abstracted & Titled
            
            let image = callToActionImage.map { ImageMediaRenderTranslator().translate($0, visitor: &visitor) }
            
            return createCallToAction(
                reference: nextTopicReferenceIdentifier,
                kind: nextTopicReference.kind,
                title: nextTopic.title ?? "",
                abstract: inlineAbstractContentInTopic(nextTopic, visitor: &visitor),
                image: image
            )
        }
        
        return nil
    }
    
    private func createCallToAction(
        reference: RenderReferenceIdentifier,
        kind: DocumentationNode.Kind,
        title: String,
        abstract: [RenderInlineContent],
        image: RenderReferenceIdentifier?
    ) -> CallToActionSection {
        let overridingTitle: String
        let eyebrow: String
        switch kind {
        case .tutorial:
            overridingTitle = "Get started"
            eyebrow = "Tutorial"
        case .tutorialArticle:
            overridingTitle = "Read article"
            eyebrow = "Article"
        default:
            fatalError("Unexpected kind '\(kind)', only tutorials and tutorial articles may be CTA destinations.")
        }
        
        let action = RenderInlineContent.reference(
            identifier: reference,
            isActive: true,
            overridingTitle: overridingTitle,
            overridingTitleInlineContent: [.text(overridingTitle)]
        )
        return CallToActionSection(
            title: title,
            abstract: abstract,
            media: image,
            action: action,
            featuredEyebrow: eyebrow
        )
    }
    
    private func inlineAbstractContentInTopic(
        _ topic: Abstracted,
        visitor: inout RenderNodeTranslator
    ) -> [RenderInlineContent] {
        if let abstract = topic.abstract {
            return MarkupContainerRenderTranslator()
                .translate(MarkupContainer(abstract), visitor: &visitor).firstParagraph
        }
        
        return []
    }
}
