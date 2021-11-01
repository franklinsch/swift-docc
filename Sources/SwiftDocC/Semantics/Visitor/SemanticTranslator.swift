/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A translator for a semantic value.
///
/// Types conforming to this protocol translate a single semantic value in the context of a visit using a ``SemanticVisitor``.
protocol SemanticTranslator {
    /// The semantic value to translate.
    associatedtype Input: Semantic
    
    /// The value to translate to.
    associatedtype Output
    
    /// The visitor associated with the translation.
    associatedtype Visitor: SemanticVisitor
    
    /// Translates the given semantic value using the given visitor.
    func translate(_ value: Input, visitor: inout Visitor) -> Output
}
