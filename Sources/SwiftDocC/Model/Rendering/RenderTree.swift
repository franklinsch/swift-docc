/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

public protocol RenderTree {}
extension Array: RenderTree where Element: RenderTree {}
extension RenderBlockContent: RenderTree {}
extension RenderReferenceIdentifier: RenderTree {}
extension RenderNode: RenderTree {}
extension IntroRenderSection: RenderTree {}
extension VolumeRenderSection: RenderTree {}
extension VolumeRenderSection.Chapter: RenderTree {}
extension ContentAndMediaSection: RenderTree {}
extension ContentAndMediaGroupSection: RenderTree {}
extension CallToActionSection: RenderTree {}
extension TutorialSectionsRenderSection: RenderTree {}
extension TutorialSectionsRenderSection.Section: RenderTree {}
extension TutorialAssessmentsRenderSection: RenderTree {}
extension TutorialAssessmentsRenderSection.Assessment: RenderTree {}
extension TutorialAssessmentsRenderSection.Assessment.Choice: RenderTree {}
extension RenderInlineContent: RenderTree {}
extension RenderTile: RenderTree {}
extension ResourcesRenderSection: RenderTree {}
extension TutorialArticleSection: RenderTree {}
extension ContentLayout: RenderTree {}

extension ContentRenderSection: RenderTree {}
