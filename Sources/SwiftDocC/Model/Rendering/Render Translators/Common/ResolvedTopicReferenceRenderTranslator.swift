/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a resolved topic reference into a render reference identifier.
struct ResolvedTopicReferenceRenderTranslator {
    
    /// Translates a resolved topic reference into a render reference identifier.
    func translate(
        _ resolvedTopicReference: ResolvedTopicReference,
        visitor: inout RenderNodeTranslator
    ) -> RenderReferenceIdentifier {
        visitor.collectedTopicReferences.append(resolvedTopicReference)
        return RenderReferenceIdentifier(resolvedTopicReference.absoluteString)
    }
}
