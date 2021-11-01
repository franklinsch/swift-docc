/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates an article into a render node.
struct ArticleRenderTranslator: SemanticTranslator {
    
    /// Translates an article into a render node.
    func translate(_ article: Article, visitor: inout RenderNodeTranslator) -> RenderNode {
        let identifier = visitor.identifier
        let context = visitor.context
        let bundle = visitor.bundle
        
        var node = RenderNode(identifier: identifier, kind: .article)
        var contentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: identifier)
        
        node.metadata.title = article.title!.plainText
        
        // Detect the article modules from its breadcrumbs.
        let modules = context.pathsTo(identifier).compactMap({ path -> String? in
            return path.mapFirst(where: { ancestor in
                guard let ancestorNode = try? context.entity(with: ancestor) else { return nil }
                return (ancestorNode.semantic as? Symbol)?.moduleName
            })
        })
        if !modules.isEmpty {
            node.metadata.modules = Array(Set(modules)).map({
                return RenderMetadata.Module(name: $0, relatedModules: nil)
            })
        }
        
        let documentationNode = try! context.entity(with: identifier)
        
        var hierarchyTranslator = RenderHierarchyTranslator(context: context, bundle: bundle)
        let hierarchy = hierarchyTranslator.visitArticle(identifier)
        visitor.collectedTopicReferences.append(contentsOf: hierarchyTranslator.collectedTopicReferences)
        node.hierarchy = hierarchy
        
        // Find the language of the symbol that curated the article in the graph
        // and use it as the interface language for that article.
        if let language = try! context.interfaceLanguageFor(identifier)?.id {
            let generator = PresentationURLGenerator(context: context, baseURL: bundle.baseURL)
            node.variants = [
                .init(traits: [.interfaceLanguage(language)], paths: [
                    generator.presentationURLForReference(identifier).path
                ])
            ]
        }
        
        if let abstract = article.abstractSection {
            node.abstract = MarkupSequenceRenderTranslator().translate(abstract.content, visitor: &visitor)
        } else {
            node.abstract = [.text("No overview available.")]
        }
        
        if let discussion = article.discussion {
            let discussionContent = MarkupContainerRenderTranslator()
                .translate(MarkupContainer(discussion.content), visitor: &visitor)
            
            var title: String?
            if let first = discussionContent.first, case RenderBlockContent.heading = first {
                title = nil
            } else {
                // For articles hardcode an overview title
                title = "Overview"
            }
            
            node.primaryContentSections.append(
                ContentRenderSection(kind: .content, content: discussionContent, heading: title)
            )
        }
        
        if let topics = article.topics, !topics.taskGroups.isEmpty {
            // Don't set an eyebrow as collections and groups don't have one; append the authored Topics section
            node.topicSections.append(
                contentsOf: GroupedSectionRenderTranslator().translate(
                    topics,
                    allowExternalLinks: false,
                    contentCompiler: &contentCompiler,
                    visitor: &visitor
                )
            )
        }
        
        // Place "top" rendering preference automatic task groups
        // after any user-defined task groups but before automatic curation.
        if !article.automaticTaskGroups.isEmpty {
            node.topicSections.append(
                contentsOf: AutomaticTaskGroupSectionRenderTranslator().translate(
                    article.automaticTaskGroups.filter { $0.renderPositionPreference == .top },
                    contentCompiler: &contentCompiler
                )
            )
        }

        // If there are no manually curated topics, and no automatic groups, try generating automatic groups
        // by child kind.
        if (article.topics == nil || article.topics?.taskGroups.isEmpty == true) &&
            article.automaticTaskGroups.isEmpty {
            // If there are no authored child topics in docs or markdown,
            // inspect the topic graph, find this node's children, and
            // for the ones found curate them automatically in task groups.
            // Automatic groups are named after the child's kind, e.g.
            // "Methods", "Variables", etc.
            let alreadyCurated = Set(node.topicSections.flatMap { $0.identifiers })
            let groups = try! AutomaticCuration.topics(for: documentationNode, context: context)
                .compactMap({ group -> AutomaticCuration.TaskGroup? in
                    // Remove references that have been already curated.
                    let newReferences = group.references.filter { !alreadyCurated.contains($0.absoluteString) }
                    // Remove groups that have no uncurated references
                    guard !newReferences.isEmpty else { return nil }

                    return (title: group.title, references: newReferences)
                })
            
            // Collect all child topic references.
            contentCompiler.collectedTopicReferences.append(contentsOf: groups.flatMap(\.references))
            // Add the final groups to the node.
            node.topicSections.append(contentsOf: groups.map(TaskGroupRenderSection.init(taskGroup:)))
        }
        
        // Place "bottom" rendering preference automatic task groups
        // after any user-defined task groups but before automatic curation.
        if !article.automaticTaskGroups.isEmpty {
            node.topicSections.append(
                contentsOf: AutomaticTaskGroupSectionRenderTranslator().translate(
                    article.automaticTaskGroups.filter({ $0.renderPositionPreference == .bottom }),
                    contentCompiler: &contentCompiler
                )
            )
        }

        if node.topicSections.isEmpty {
            // Set an eyebrow for articles
            node.metadata.roleHeading = "Article"
        }
        node.metadata.role = visitor.contentRenderer.roleForArticle(
            article,
            nodeKind: documentationNode.kind
        ).rawValue

        // Authored See Also section
        if let seeAlso = article.seeAlso, !seeAlso.taskGroups.isEmpty {
            node.seeAlsoSections.append(
                contentsOf: GroupedSectionRenderTranslator().translate(
                    seeAlso,
                    allowExternalLinks: true,
                    contentCompiler: &contentCompiler,
                    visitor: &visitor
                )
            )
        }
        
        // Automatic See Also section
        if let seeAlso = try! AutomaticCuration.seeAlso(
            for: documentationNode,
            context: context,
            bundle: bundle,
            renderContext: visitor.renderContext,
            renderer: visitor.contentRenderer
        ) {
            contentCompiler.collectedTopicReferences.append(contentsOf: seeAlso.references)
            node.seeAlsoSections.append(TaskGroupRenderSection(
                title: seeAlso.title,
                abstract: nil,
                discussion: nil,
                identifiers: seeAlso.references.map { $0.absoluteString },
                generated: true
            ))
        }
        
        visitor.collectedTopicReferences.append(contentsOf: contentCompiler.collectedTopicReferences)
        node.references = visitor.createTopicRenderReferences()

        addReferences(visitor.imageReferences, to: &node)
        addReferences(visitor.videoReferences, to: &node)
        addReferences(visitor.linkReferences, to: &node)
        // See Also can contain external links, we need to separately transfer
        // link references from the content compiler
        addReferences(contentCompiler.linkReferences, to: &node)

        return node
    }
}
