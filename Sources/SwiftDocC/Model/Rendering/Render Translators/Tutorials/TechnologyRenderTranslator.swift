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
        node.metadata.estimatedTime = visitor.totalEstimatedDuration(for: technology)
        node.metadata.role = visitor.contentRenderer.role(for: .technology).rawValue

        var intro = IntroRenderTranslator().translate(technology.intro, visitor: &visitor)
        if let firstTutorial = visitor.firstTutorial(ofTechnology: visitor.identifier) {
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
        
        visitor.addReferences(visitor.fileReferences, to: &node)
        visitor.addReferences(visitor.imageReferences, to: &node)
        visitor.addReferences(visitor.videoReferences, to: &node)
        visitor.addReferences(visitor.linkReferences, to: &node)
        
        return node
    }
}
