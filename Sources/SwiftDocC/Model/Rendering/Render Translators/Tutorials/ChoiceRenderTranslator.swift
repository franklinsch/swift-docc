/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates an assessments choice into a choice render value.
struct ChoiceRenderTranslator: SemanticTranslator {
    
    /// Translates an assessments choice into a choice render value.
    func translate(
        _ choice: Choice,
        visitor: inout RenderNodeTranslator
    ) -> TutorialAssessmentsRenderSection.Assessment.Choice {
        TutorialAssessmentsRenderSection.Assessment.Choice(
            content: MarkupContainerRenderTranslator().translate(choice.content, visitor: &visitor),
            isCorrect: choice.isCorrect,
            justification: JustificationRenderTranslator().translate(choice.justification, visitor: &visitor),
            reaction: choice.justification.reaction
        )
    }
}
