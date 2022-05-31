/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A reference to another page which cannot be resolved.
public struct UnresolvedRenderReference: RenderReference, VariantContainer {
    /// The type of this unresolvable reference.
    ///
    /// This value is always `.unresolvable`.
    public var type: RenderReferenceType = .unresolvable
    
    /// The identifier of this unresolved reference.
    public var identifier: RenderReferenceIdentifier
    
    /// The title of this unresolved reference.
    public var title: String {
        get { getVariantDefaultValue(keyPath: \.titleVariants) }
        set { setVariantDefaultValue(newValue, keyPath: \.titleVariants) }
    }
    
    /// The title of the destination page.
    public var titleVariants: VariantCollection<String>

    /// Creates a new unresolved reference with a given identifier and title.
    /// 
    /// - Parameters:
    ///   - identifier: The identifier of this unresolved reference.
    ///   - title: The title of this unresolved reference.
    public init(identifier: RenderReferenceIdentifier, title: String) {
        self.identifier = identifier
        self.titleVariants = .init(defaultValue: title)
    }
    
    public init(identifier: RenderReferenceIdentifier, titleVariants: VariantCollection<String>) {
        self.identifier = identifier
        self.titleVariants = titleVariants
    }
    
    enum CodingKeys: String, CodingKey {
        case type, identifier, title
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decode(RenderReferenceType.self, forKey: .type)
        identifier = try values.decode(RenderReferenceIdentifier.self, forKey: .identifier)
        titleVariants = try values.decode(VariantCollection<String>.self, forKey: .title)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(type, forKey: .type)
        try container.encode(identifier, forKey: .identifier)
        try container.encodeVariantCollection(titleVariants, forKey: .title, encoder: encoder)
    }
}
