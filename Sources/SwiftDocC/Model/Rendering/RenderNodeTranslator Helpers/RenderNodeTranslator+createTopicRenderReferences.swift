/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension RenderNodeTranslator {
    mutating func createTopicRenderReferences() -> [String: RenderReference] {
        var renderReferences: [String: RenderReference] = [:]
        let renderer = DocumentationContentRenderer(documentationContext: context, bundle: bundle)
        
        for reference in collectedTopicReferences {
            var renderReference: TopicRenderReference
            var dependencies: RenderReferenceDependencies
            
            if let renderContext = renderContext, let prerendered = renderContext.store.content(for: reference)?.renderReference as? TopicRenderReference,
                let renderReferenceDependencies = renderContext.store.content(for: reference)?.renderReferenceDependencies {
                renderReference = prerendered
                dependencies = renderReferenceDependencies
            } else {
                dependencies = RenderReferenceDependencies()
                renderReference = renderer.renderReference(for: reference, dependencies: &dependencies)
            }
            
            for link in dependencies.linkReferences {
                linkReferences[link.identifier.identifier] = link
            }
            
            for dependencyReference in dependencies.topicReferences {
                var dependencyRenderReference: TopicRenderReference
                if let renderContext = renderContext, let prerendered = renderContext.store.content(for: dependencyReference)?.renderReference as? TopicRenderReference {
                    dependencyRenderReference = prerendered
                } else {
                    var dependencies = RenderReferenceDependencies()
                    dependencyRenderReference = renderer.renderReference(for: dependencyReference, dependencies: &dependencies)
                }
                renderReferences[dependencyReference.absoluteString] = dependencyRenderReference
            }
            
            // Add any conformance constraints to the reference, if any are present.
            if let conformanceSection = renderer.conformanceSectionFor(reference, collectedConstraints: collectedConstraints) {
                renderReference.conformance = conformanceSection
            }
            
            renderReferences[reference.absoluteString] = renderReference
        }

        for unresolved in collectedUnresolvedTopicReferences {
            let renderReference = UnresolvedRenderReference(
                identifier: RenderReferenceIdentifier(unresolved.topicURL.absoluteString),
                title: unresolved.title ?? unresolved.topicURL.absoluteString
            )
            renderReferences[renderReference.identifier.identifier] = renderReference
        }
        
        return renderReferences
    }
}
