/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// This type translates an image media value into a render reference identifier.
struct ImageMediaRenderTranslator: SemanticTranslator {
    
    /// Translates an image media value into a render reference identifier.
    ///
    /// This function registers a render reference for the associated media in the given render node translator.
    func translate(_ imageMedia: ImageMedia, visitor: inout RenderNodeTranslator) -> RenderReferenceIdentifier {
        visitor.createAndRegisterRenderReference(forMedia: imageMedia.source, altText: imageMedia.altText)
    }
}
