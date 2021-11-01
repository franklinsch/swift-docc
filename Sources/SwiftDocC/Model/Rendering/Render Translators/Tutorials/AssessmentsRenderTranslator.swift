/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates an assessments value into a tutorial assessments render section.
struct AssessmentsRenderTranslator: SemanticTranslator {
    
    /// Translates an assessments value into a tutorial assessments render section.
    func translate(
        _ assessments: Assessments,
        visitor: inout RenderNodeTranslator
    ) -> TutorialAssessmentsRenderSection {
        let renderSectionAssessments = assessments.questions.compactMap { question in
            MultipleChoiceRenderTranslator().translate(question, visitor: &visitor)
        }
        
        return TutorialAssessmentsRenderSection(
            assessments: renderSectionAssessments,
            anchor: RenderHierarchyTranslator.assessmentsAnchor
        )
    }
}
