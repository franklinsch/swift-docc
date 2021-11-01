/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A type that translates automatically generated task groups into an array of render task groups.
struct AutomaticTaskGroupSectionRenderTranslator {
    
    /// Translates a grouped section into an array of render task groups.
    func translate(
        _ taskGroups: [AutomaticTaskGroupSection],
        contentCompiler: inout RenderContentCompiler
    ) -> [TaskGroupRenderSection] {
        taskGroups.map { group in
            contentCompiler.collectedTopicReferences.append(contentsOf: group.references)
            return TaskGroupRenderSection(
                title: group.title,
                abstract: nil,
                discussion: nil,
                identifiers: group.references.compactMap(\.url?.absoluteString),
                generated: true
            )
        }
    }
}
