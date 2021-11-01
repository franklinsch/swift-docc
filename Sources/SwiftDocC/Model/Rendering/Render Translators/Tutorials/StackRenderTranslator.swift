/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a stack value into an array of content and media sections.
struct StackRenderTranslator: SemanticTranslator {
    
    /// Translates a stack value into an array of content and media sections.
    func translate(_ stack: Stack, visitor: inout RenderNodeTranslator) -> [ContentAndMediaSection] {
        stack.contentAndMedia.map {
            ContentAndMediaRenderTranslator().translate($0, visitor: &visitor)
        }
    }
}
