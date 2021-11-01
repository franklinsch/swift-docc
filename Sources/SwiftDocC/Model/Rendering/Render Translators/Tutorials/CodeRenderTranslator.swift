/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a code value into a render reference identifier.
struct CodeRenderTranslator: SemanticTranslator {
    
    /// Translates a code value into a render reference identifier.
    ///
    /// This function reads the file contents associated with the``Code`` value and writes it to the visitor's `fileReferences` dictionary.
    func translate(_ code: Code, visitor: inout RenderNodeTranslator) -> RenderReferenceIdentifier {
        let fileType = NSString(string: code.fileName).pathExtension
        let fileReference = code.fileReference
        
        guard let fileData = try? visitor.context.resource(with: code.fileReference),
            let fileContents = String(data: fileData, encoding: .utf8) else {
            return RenderReferenceIdentifier("")
        }
        
        let assetReference = RenderReferenceIdentifier(fileReference.path)
        
        visitor.fileReferences[fileReference.path] = FileReference(
            identifier: assetReference,
            fileName: code.fileName,
            fileType: fileType,
            syntax: fileType,
            content: fileContents.splitByNewlines
        )
        return assetReference
    }
}
