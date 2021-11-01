/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a tutorial article into a render node.
struct TutorialArticleRenderTranslator: SemanticTranslator {
    
    /// Translates a tutorial article into a render node.
    ///
    /// - Returns: The render node representing the tutorial article if the tutorial article is curated, otherwise `nil`.
    func translate(_ article: TutorialArticle, visitor: inout RenderNodeTranslator) -> RenderNode? {
        let identifier = visitor.identifier
        let context = visitor.context
        let bundle = visitor.bundle
        
        var node = RenderNode(identifier: identifier, kind: .article)
        
        var hierarchyTranslator = RenderHierarchyTranslator(context: context, bundle: bundle)
        guard let hierarchy = hierarchyTranslator.visitTechnologyNode(identifier) else {
            // This tutorial article is not curated, so we don't generate a render node.
            // We've warned about this during semantic analysis.
            return nil
        }
        
        let technology = try! context.entity(with: hierarchy.technology).semantic as! Technology
        
        node.metadata.title = article.title
        
        node.metadata.category = technology.name
        node.metadata.categoryPathComponent = hierarchy.technology.url.lastPathComponent
        node.metadata.role = visitor.contentRenderer.role(for: .tutorialArticle).rawValue
        
        // Unlike for other pages, in here we use `RenderHierarchyTranslator` to crawl the technology
        // and produce the list of modules for the render hierarchy to display in the tutorial local navigation.
        node.hierarchy = hierarchy.hierarchy
        
        visitor.collectedTopicReferences.append(contentsOf: hierarchyTranslator.collectedTopicReferences)
        
        var intro: IntroRenderSection
        if let articleIntro = article.intro {
            intro = IntroRenderTranslator().translate(articleIntro, visitor: &visitor)
        } else {
            // Create a default intro section so that it's not an error to skip writing one.
            intro = IntroRenderSection(title: "")
        }
        
        if let time = article.durationMinutes {
            intro.estimatedTimeInMinutes = time
        }
        
        // Guaranteed to have at least one path
        let technologyPath = context.pathsTo(identifier, options: [.preferTechnologyRoot])[0]
                
        node.sections.append(intro)
        
        let layouts = visitor.contentLayouts(article.content)
        
        let articleSection = TutorialArticleSection(content: layouts)
        
        node.sections.append(articleSection)
        
        if let assessments = article.assessments {
            node.sections.append(AssessmentsRenderTranslator().translate(assessments, visitor: &visitor))
        }
        
        if technologyPath.count >= 2 {
            let volume = technologyPath[technologyPath.count - 2]
            
            if let cta = visitor.callToAction(with: article.callToActionImage, volume: volume) {
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
        
        return node
    }
}
