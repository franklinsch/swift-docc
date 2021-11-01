/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a technology into a render node.
struct TechnologyRenderTranslator: SemanticTranslator {
    
    /// Translates a technology into a render node.
    func translate(_ technology: Technology, visitor: inout RenderNodeTranslator) -> RenderNode {
        var node = RenderNode(identifier: visitor.identifier, kind: .overview)
        
        node.metadata.title = technology.intro.title
        node.metadata.category = technology.name
        node.metadata.categoryPathComponent = visitor.identifier.url.lastPathComponent
        node.metadata.estimatedTime = totalEstimatedDuration(
            for: technology,
            context: visitor.context,
            identifier: visitor.identifier,
            contentRenderer: visitor.contentRenderer
        )
        node.metadata.role = visitor.contentRenderer.role(for: .technology).rawValue

        var intro = IntroRenderTranslator().translate(technology.intro, visitor: &visitor)
        if let firstTutorial = firstTutorial(
            ofTechnology: visitor.identifier,
            context: visitor.context
        ) {
            intro.action = visitor.visitLink(firstTutorial.reference.url, defaultTitle: "Get started")
        }
        node.sections.append(intro)
                
        node.sections.append(
            contentsOf: technology.volumes.map { VolumeRenderTranslator().translate($0, visitor: &visitor) }
        )
        
        if let resources = technology.resources {
            node.sections.append(ResourcesRenderTranslator().translate(resources, visitor: &visitor))
        }
        
        var hierarchyTranslator = RenderHierarchyTranslator(context: visitor.context, bundle: visitor.bundle)
        node.hierarchy = hierarchyTranslator
            .visitTechnologyNode(visitor.identifier, omittingChapters: true)!
            .hierarchy

        visitor.collectedTopicReferences.append(contentsOf: hierarchyTranslator.collectedTopicReferences)
        
        node.references = visitor.createTopicRenderReferences()
        
        addReferences(visitor.fileReferences, to: &node)
        addReferences(visitor.imageReferences, to: &node)
        addReferences(visitor.videoReferences, to: &node)
        addReferences(visitor.linkReferences, to: &node)
        
        return node
    }
    
    /// Returns a description of the total estimated duration to complete the tutorials of the given technology.
    /// - Returns: The estimated duration, or `nil` if there are no tutorials with time estimates.
    private func totalEstimatedDuration(
        for technology: Technology,
        context: DocumentationContext,
        identifier: ResolvedTopicReference,
        contentRenderer: DocumentationContentRenderer
    ) -> String? {
        var totalDurationMinutes: Int? = nil

        context.traverseBreadthFirst(from: identifier) { node in
            if let entity = try? context.entity(with: node.reference),
                let durationMinutes = (entity.semantic as? Timed)?.durationMinutes
            {
                if totalDurationMinutes == nil {
                    totalDurationMinutes = 0
                }
                totalDurationMinutes! += durationMinutes
            }

            return .continue
        }


        return totalDurationMinutes.flatMap(contentRenderer.formatEstimatedDuration(minutes:))
    }
    
    private func firstTutorial(
        ofTechnology technology: ResolvedTopicReference,
        context: DocumentationContext
    ) -> (reference: ResolvedTopicReference, kind: DocumentationNode.Kind)? {
        guard let volume = (context.children(of: technology, kind: .volume)).first,
              let firstChapter = (context.children(of: volume.reference)).first,
              let firstTutorial = (context.children(of: firstChapter.reference)).first else
        {
            return nil
        }
        return firstTutorial
    }
}
