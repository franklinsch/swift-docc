/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a multiple choice value into an array of render block content elements.
struct MultipleChoiceRenderTranslator: SemanticTranslator {
    
    /// Translates a multiple choice value into an array of render block content elements.
    func translate(
        _ multipleChoice: MultipleChoice,
        visitor: inout RenderNodeTranslator
    ) -> TutorialAssessmentsRenderSection.Assessment {
        let questionPhrasing = MarkupContainerRenderTranslator()
            .translate(multipleChoice.questionPhrasing, visitor: &visitor)
        
        let content = MarkupContainerRenderTranslator()
            .translate(multipleChoice.content, visitor: &visitor)
        
        return TutorialAssessmentsRenderSection.Assessment(
            title: questionPhrasing,
            content: content,
            choices: multipleChoice.choices
                .map { visitor.visitChoice($0) } as! [TutorialAssessmentsRenderSection.Assessment.Choice]
        )
    }
}
