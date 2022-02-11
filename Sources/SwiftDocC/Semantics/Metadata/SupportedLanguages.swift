/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that specifies a list of languages a technology supports.
///
/// This directive is only valid within the top-level ``Metadata`` directive of a technology root page:
/// ```
/// @Metadata {
///    @TechnologyRoot
///
///    @SupportedLanguages {
///      - Swift
///      - Objective-C
///    }
/// }
/// ```
 public final class SupportedLanguages: Semantic, DirectiveConvertible {
     public let originalMarkup: BlockDirective

     public static let directiveName: String = "SupportedLanguages"

     /// The list of languages, represented using their display name.
     public let languages: [SourceLanguage]

     init(originalMarkup: BlockDirective, languages: [SourceLanguage]) {
         self.originalMarkup = originalMarkup
         self.languages = languages
     }
     
     /// The valid languages that can be specified in this directive.
     private static let validLanguages = FeatureFlags.current.isExperimentalObjectiveCSupportEnabled
        ? [SourceLanguage.swift, SourceLanguage.objectiveC]
        : [SourceLanguage.swift]

     public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
         precondition(directive.name == SupportedLanguages.directiveName)

         _ = Semantic.Analyses.HasOnlyKnownArguments<SupportedLanguages>(
            severityIfFound: .warning,
            allowedArguments: []
         ).analyze(
            directive,
            children: directive.children,
            source: source,
            for: bundle,
            in: context,
            problems: &problems
         )

         let languages = Semantic.Analyses.HasExactlyOneUnorderedList<SupportedLanguages, Text>(
            severityIfNotFound: .warning
         ).analyze(
            directive,
            children: directive.children,
            source: source,
            for: bundle,
            in: context,
            problems: &problems
         ) ?? []
         
         let (validLanguages, invalidLanguages) = languages.categorize { rawLanguage in
             Self.validLanguages.first { $0.name == rawLanguage.plainText }
         }
         
         problems.append(
            contentsOf: invalidLanguages.map { invalidLanguage in
                Problem(
                    diagnostic: Diagnostic(
                        source: source,
                        severity: .warning,
                        range: invalidLanguage.range,
                        identifier: "org.swift.docc.\(SupportedLanguages.directiveName.singleQuoted).InvalidLanguage",
                        summary: """
                        Invalid language for \(SupportedLanguages.directiveName) directive. Valid languages are \
                        \(Self.validLanguages.map(\.name).map(\.singleQuoted).list(finalConjunction: .and)).
                        """
                    )
                )
            }
         )

         self.init(originalMarkup: directive, languages: validLanguages)
     }
 }
