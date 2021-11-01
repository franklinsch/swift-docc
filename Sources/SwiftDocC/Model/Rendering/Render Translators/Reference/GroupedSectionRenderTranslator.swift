/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A type that translates a grouped section into an array of render task groups.
struct GroupedSectionRenderTranslator {
    
    /// Translates a grouped section into an array of render task groups.
    func translate(
        _ topics: GroupedSection,
        allowExternalLinks: Bool,
        contentCompiler: inout RenderContentCompiler,
        visitor: inout RenderNodeTranslator
    ) -> [TaskGroupRenderSection] {
        topics.taskGroups.compactMap { group in
            
            let abstractContent = group.abstract.map {
                return MarkupSequenceRenderTranslator().translate($0.content, visitor: &visitor)
            }
            
            let discussion = group.discussion.map { discussion -> ContentRenderSection in
                let discussionContent = MarkupContainerRenderTranslator()
                    .translate(MarkupContainer(discussion.content), visitor: &visitor)
                return ContentRenderSection(kind: .content, content: discussionContent, heading: "Discussion")
            }
            
            let taskGroupRenderSection = TaskGroupRenderSection(
                title: group.heading?.plainText,
                abstract: abstractContent,
                discussion: discussion,
                identifiers: group.links.compactMap { link in
                    switch link {
                    case let link as Link:
                        if !allowExternalLinks {
                            // For links require documentation scheme
                            guard let _ = link.destination.flatMap(ValidatedURL.init)?
                                    .requiring(scheme: ResolvedTopicReference.urlScheme)
                            else {
                                return nil
                            }
                        }
                        
                        if let referenceInlines = contentCompiler.visitLink(link) as? [RenderInlineContent],
                            let renderReference = referenceInlines.first(where: { inline in
                            switch inline {
                            case .reference(_,_,_,_):
                                return true
                            default:
                                return false
                            }
                        }),
                           case let RenderInlineContent.reference(
                            identifier: identifier,
                            isActive: _,
                            overridingTitle: _,
                            overridingTitleInlineContent: _
                           ) = renderReference {
                            return identifier.identifier
                        }
                    case let link as SymbolLink:
                        if let referenceInlines = contentCompiler.visitSymbolLink(link) as? [RenderInlineContent],
                            let renderReference = referenceInlines.first(where: { inline in
                            switch inline {
                            case .reference:
                                return true
                            default:
                                return false
                            }
                        }),
                           case let RenderInlineContent.reference(identifier: identifier, isActive: _, overridingTitle: _, overridingTitleInlineContent: _) = renderReference {
                            return identifier.identifier
                        }
                    default: break
                    }
                    return nil
                }
            )
            
            // rdar://74617294 If a task group doesn't have any symbol or external links it shouldn't be rendered
            guard !taskGroupRenderSection.identifiers.isEmpty else {
                return nil
            }
            
            return taskGroupRenderSection
        }
    }
}
