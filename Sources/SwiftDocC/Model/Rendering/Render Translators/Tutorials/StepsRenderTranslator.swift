/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a steps value into an array of render block content.
struct StepsRenderTranslator: SemanticTranslator {
    
    /// Translates a steps value into an array of render block content.
    func translate(_ steps: Steps, visitor: inout RenderNodeTranslator) -> [RenderBlockContent] {
        let stepsContent = steps.content.flatMap { child -> [RenderBlockContent] in
            return visitor.visit(child) as! [RenderBlockContent]
        }
        
        return stepsContent
    }
}
