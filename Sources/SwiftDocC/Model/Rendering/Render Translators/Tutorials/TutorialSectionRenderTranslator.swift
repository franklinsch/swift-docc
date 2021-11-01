/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a tutorial section into tutorial render section.
struct TutorialSectionRenderTranslator: SemanticTranslator {
    
    /// Translates a tutorial section into tutorial render section.
    func translate(
        _ tutorialSection: TutorialSection,
        visitor: inout RenderNodeTranslator
    ) -> TutorialSectionsRenderSection.Section {
        let introduction = visitor.contentLayouts(tutorialSection.introduction)
        let stepsContent: [RenderBlockContent]
        if let steps = tutorialSection.stepsContent {
            stepsContent = StepsRenderTranslator().translate(steps, visitor: &visitor)
        } else {
            stepsContent = []
        }
        
        let highlightsPerFile = LineHighlighter(context: visitor.context, tutorialSection: tutorialSection).highlights
        
        // Add the highlights to the file references.
        for result in highlightsPerFile {
            visitor.fileReferences[result.file.path]?.highlights = result.highlights
        }
        
        return TutorialSectionsRenderSection.Section(
            title: tutorialSection.title,
            contentSection: introduction,
            stepsSection: stepsContent,
            anchor: urlReadableFragment(tutorialSection.title)
        )
    }
}
