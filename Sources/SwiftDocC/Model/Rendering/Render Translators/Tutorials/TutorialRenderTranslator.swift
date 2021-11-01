/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a tutorial into render node.
struct TutorialRenderTranslator: SemanticTranslator {
    
    /// Translates a tutorial into render node.
    ///
    /// - Returns: The render node representing the tutorial if the tutorial is curated, otherwise `nil`.
    func translate(_ tutorial: Tutorial, visitor: inout RenderNodeTranslator) -> RenderNode? {
        var node = RenderNode(identifier: visitor.identifier, kind: .tutorial)
        
        var hierarchyTranslator = RenderHierarchyTranslator(context: visitor.context, bundle: visitor.bundle)
        guard let hierarchy = hierarchyTranslator.visitTechnologyNode(visitor.identifier) else {
            // This tutorial is not curated, so we don't generate a render node.
            // We've warned about this during semantic analysis.
            return nil
        }
        
        let technology = try! visitor.context.entity(with: hierarchy.technology).semantic as! Technology
        
        node.metadata.title = tutorial.intro.title
        node.metadata.role = visitor.contentRenderer.role(for: .tutorial).rawValue
        
        visitor.collectedTopicReferences.append(contentsOf: hierarchyTranslator.collectedTopicReferences)
        
        node.hierarchy = hierarchy.hierarchy
        node.metadata.category = technology.name
        
        node.metadata.categoryPathComponent = hierarchy.technology.url.lastPathComponent
                
        var intro = IntroRenderTranslator().translate(tutorial.intro, visitor: &visitor)
        intro.estimatedTimeInMinutes = tutorial.durationMinutes
        
        if let chapterReference = visitor.context.parents(of: visitor.identifier).first {
            intro.chapter = visitor.context.title(for: chapterReference)
        }
        // Add an Xcode requirement to the tutorial intro if one is provided.
        if let requirement = tutorial.requirements.first {
            let identifier = RenderReferenceIdentifier(requirement.title)
            let requirementReference = XcodeRequirementReference(
                identifier: identifier,
                title: requirement.title,
                url: requirement.destination
            )
            visitor.requirementReferences[identifier.identifier] = requirementReference
            intro.xcodeRequirement = identifier
        }
        
        if let projectFiles = tutorial.projectFiles {
            intro.projectFiles = visitor.createAndRegisterRenderReference(
                forMedia: projectFiles,
                assetContext: .download
            )
        }
        
        node.sections.append(intro)
        
        var tutorialSections = TutorialSectionsRenderSection(
            sections: tutorial.sections.map {
                TutorialSectionRenderTranslator().translate($0, visitor: &visitor)
            }
        )

        // Attach anchors to tutorial sections.
        // Find the reference associated with the section, by searching the tutorial's children for a node that has a
        // matching title.
        // This assumes that the rendered `tasks` are in the same order as `tutorial.sections`.
        let sectionReferences = visitor.context.children(of: visitor.identifier, kind: .onPageLandmark)
        tutorialSections.tasks = tutorialSections.tasks.enumerated().map { (index, section) in
            var section = section
            section.anchor = sectionReferences[index].reference.fragment ?? ""
            return section
        }
        
        node.sections.append(tutorialSections)
        if let assessments = tutorial.assessments {
            node.sections.append(AssessmentsRenderTranslator().translate(assessments, visitor: &visitor))
        }

        // We guarantee there will be at least 1 path with at least 4 nodes in that path if the tutorial is curated.
        // The way to curate tutorials is to link them from a Technology page and that generates the following
        // hierarchy: technology -> volume -> chapter -> tutorial.
        let technologyPath = visitor.context.pathsTo(visitor.identifier, options: [.preferTechnologyRoot])[0]
        
        if technologyPath.count >= 2 {
            let volume = technologyPath[technologyPath.count - 2]
            
            if let cta = visitor.callToAction(with: tutorial.callToActionImage, volume: volume) {
                node.sections.append(cta)
            }
        }
        
        node.references = visitor.createTopicRenderReferences()

        visitor.addReferences(visitor.fileReferences, to: &node)
        visitor.addReferences(visitor.imageReferences, to: &node)
        visitor.addReferences(visitor.videoReferences, to: &node)
        visitor.addReferences(visitor.requirementReferences, to: &node)
        visitor.addReferences(visitor.downloadReferences, to: &node)
        visitor.addReferences(visitor.linkReferences, to: &node)
        visitor.addReferences(hierarchyTranslator.linkReferences, to: &node)
        return node
    }
}
