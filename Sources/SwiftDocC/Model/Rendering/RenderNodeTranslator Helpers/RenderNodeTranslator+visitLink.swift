/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension RenderNodeTranslator {
    public mutating func visitLink(_ link: URL, defaultTitle overridingTitle: String?) -> RenderInlineContent {
        let overridingTitleInlineContent = overridingTitle.map { [RenderInlineContent.text($0)] }
        
        let action: RenderInlineContent
        // We expect, at this point of the rendering, this API to be called with valid URLs, otherwise crash.
        let unresolved = UnresolvedTopicReference(topicURL: ValidatedURL(link)!)
        
        if case let .resolved(resolved) = context.resolve(.unresolved(unresolved), in: bundle.rootReference) {
            action = RenderInlineContent.reference(
                identifier: RenderReferenceIdentifier(resolved.absoluteString),
                isActive: true,
                overridingTitle: overridingTitle,
                overridingTitleInlineContent: overridingTitleInlineContent
            )
            collectedTopicReferences.append(resolved)
        } else if !ResolvedTopicReference.urlHasResolvedTopicScheme(link) {
            // This is an external link
            let externalLinkIdentifier = RenderReferenceIdentifier(forExternalLink: link.absoluteString)
            if linkReferences.keys.contains(externalLinkIdentifier.identifier) {
                // If we've already seen this link, return the existing reference with an overridden title.
                action = RenderInlineContent.reference(
                    identifier: externalLinkIdentifier,
                    isActive: true,
                    overridingTitle: overridingTitle,
                    overridingTitleInlineContent: overridingTitleInlineContent
                )
            } else {
                // Otherwise, create and save a new link reference.
                let linkReference = LinkReference(
                    identifier: externalLinkIdentifier,
                    title: overridingTitle ?? link.absoluteString,
                    titleInlineContent: overridingTitleInlineContent ?? [.text(link.absoluteString)],
                    url: link.absoluteString
                )
                linkReferences[externalLinkIdentifier.identifier] = linkReference
                
                action = RenderInlineContent.reference(
                    identifier: externalLinkIdentifier,
                    isActive: true,
                    overridingTitle: nil,
                    overridingTitleInlineContent: nil
                )
            }
        } else {
            // This is an unresolved doc: URL. We render the link inactive by converting it to plain text,
            // as it may break routing or other downstream uses of the URL.
            action = RenderInlineContent.text(link.path)
        }
        
        return action
    }
}
