/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a tutorial reference into render reference identifier.
struct TutorialReferenceRenderTranslator: SemanticTranslator {
    
    /// Translates a tutorial reference into render reference identifier.
    func translate(
        _ tutorialReference: TutorialReference,
        visitor: inout RenderNodeTranslator
    ) -> RenderReferenceIdentifier {
        switch visitor.context.resolve(tutorialReference.topic, in: visitor.bundle.rootReference) {
        case let .unresolved(reference):
            return RenderReferenceIdentifier(reference.topicURL.absoluteString)
        case let .resolved(resolved):
            return ResolvedTopicReferenceRenderTranslator().translate(resolved, visitor: &visitor)
        }
    }
}
