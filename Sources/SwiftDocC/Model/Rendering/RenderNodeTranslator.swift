/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
import SymbolKit

/// A visitor which converts a semantic model into a render node.
///
/// The translator visits the contents of a ``DocumentationNode``'s ``Semantic`` model and creates a ``RenderNode``.
/// The translation is lossy, meaning that translating a ``RenderNode`` back to a ``Semantic`` is not possible with full fidelity.
/// For example, source markup syntax is not preserved during the translation.
public struct RenderNodeTranslator: SemanticVisitor {

    /// Resolved topic references that were seen by the visitor. These should be used to populate the references dictionary.
    var collectedTopicReferences: [ResolvedTopicReference] = []
    
    /// Unresolvable topic references outside the current bundle.
    var collectedUnresolvedTopicReferences: [UnresolvedTopicReference] = []
    
    /// Any collected constraints to symbol relationships.
    var collectedConstraints: [TopicReference: [SymbolGraph.Symbol.Swift.GenericConstraint]] = [:]
    
    /// A context containing pre-rendered content.
    let renderContext: RenderContext?
    
    /// A collection of functions that render pieces of documentation content.
    let contentRenderer: DocumentationContentRenderer
    
    /// Whether the documentation converter should include source file
    /// location metadata in any render nodes representing symbols it creates.
    ///
    /// Before setting this value to `true` please confirm that your use case doesn't
    /// include public distribution of any created render nodes as there are filesystem privacy and security
    /// concerns with distributing this data.
    var shouldEmitSymbolSourceFileURIs: Bool
    
    /// Whether the documentation converter should include access level information for symbols.
    var shouldEmitSymbolAccessLevels: Bool
    
    /// The current module context for symbols.
    private var currentSymbolModuleName: String? = nil
    /// The current symbol context.
    var currentSymbol: ResolvedTopicReference? = nil
    
    var context: DocumentationContext
    var bundle: DocumentationBundle
    var identifier: ResolvedTopicReference
    var source: URL?
    var imageReferences: [String: ImageReference] = [:]
    var videoReferences: [String: VideoReference] = [:]
    var fileReferences: [String: FileReference] = [:]
    var linkReferences: [String: LinkReference] = [:]
    var requirementReferences: [String: XcodeRequirementReference] = [:]
    var downloadReferences: [String: DownloadReference] = [:]
    
    var bundleAvailability: [BundleModuleIdentifier: [AvailabilityRenderItem]] = [:]
        
    public mutating func visitCode(_ code: Code) -> RenderTree? {
        CodeRenderTranslator().translate(code, visitor: &self)
    }
    
    public mutating func visitSteps(_ steps: Steps) -> RenderTree? {
        StepsRenderTranslator().translate(steps, visitor: &self)
    }
    
    public mutating func visitStep(_ step: Step) -> RenderTree? {
        StepRenderTranslator().translate(step, visitor: &self)
    }
    
    public mutating func visitTutorialSection(_ tutorialSection: TutorialSection) -> RenderTree? {
        TutorialSectionRenderTranslator().translate(tutorialSection, visitor: &self)
    }
    
    public mutating func visitTutorial(_ tutorial: Tutorial) -> RenderTree? {
        TutorialRenderTranslator().translate(tutorial, visitor: &self)
    }
    
    public mutating func visitIntro(_ intro: Intro) -> RenderTree? {
        IntroRenderTranslator().translate(intro, visitor: &self)
    }
    
    public mutating func visitXcodeRequirement(_ requirement: XcodeRequirement) -> RenderTree? {
        fatalError("TODO")
    }
    
    public mutating func visitAssessments(_ assessments: Assessments) -> RenderTree? {
        AssessmentsRenderTranslator().translate(assessments, visitor: &self)
    }
    
    public mutating func visitMultipleChoice(_ multipleChoice: MultipleChoice) -> RenderTree? {
        MultipleChoiceRenderTranslator().translate(multipleChoice, visitor: &self)
    }
    
    public mutating func visitChoice(_ choice: Choice) -> RenderTree? {
        ChoiceRenderTranslator().translate(choice, visitor: &self)
    }
    
    public mutating func visitJustification(_ justification: Justification) -> RenderTree? {
        JustificationRenderTranslator().translate(justification, visitor: &self)
    }
        
    // Visits a container and expects the elements to be block level elements
    public mutating func visitMarkupContainer(_ markupContainer: MarkupContainer) -> RenderTree? {
        MarkupContainerRenderTranslator().translate(markupContainer, visitor: &self)
    }
    
    // Visits a collection of inline markup elements.
    public mutating func visitMarkup(_ markup: [Markup]) -> RenderTree? {
        MarkupSequenceRenderTranslator().translate(markup, visitor: &self)
    }

    // Visits a single inline markup element.
    public mutating func visitMarkup(_ markup: Markup) -> RenderTree? {
        MarkupRenderTranslator().translate(markup, visitor: &self)
    }

    public mutating func visitTechnology(_ technology: Technology) -> RenderTree? {
        TechnologyRenderTranslator().translate(technology, visitor: &self)
    }

    public mutating func visitVolume(_ volume: Volume) -> RenderTree? {
        VolumeRenderTranslator().translate(volume, visitor: &self)
    }
    
    public mutating func visitImageMedia(_ imageMedia: ImageMedia) -> RenderTree? {
        ImageMediaRenderTranslator().translate(imageMedia, visitor: &self)
    }
    
    public mutating func visitVideoMedia(_ videoMedia: VideoMedia) -> RenderTree? {
        VideoMediaRenderTranslator().translate(videoMedia, visitor: &self)
    }
    
    public mutating func visitChapter(_ chapter: Chapter) -> RenderTree? {
        ChapterRenderTranslator().translate(chapter, visitor: &self)
    }
    
    public mutating func visitContentAndMedia(_ contentAndMedia: ContentAndMedia) -> RenderTree? {
        ContentAndMediaRenderTranslator().translate(contentAndMedia, visitor: &self)
    }
        
    public mutating func visitTutorialReference(_ tutorialReference: TutorialReference) -> RenderTree? {
        TutorialReferenceRenderTranslator().translate(tutorialReference, visitor: &self)
    }
    
    public mutating func visitResolvedTopicReference(_ resolvedTopicReference: ResolvedTopicReference) -> RenderTree {
        ResolvedTopicReferenceRenderTranslator().translate(resolvedTopicReference, visitor: &self)
    }
        
    public mutating func visitResources(_ resources: Resources) -> RenderTree? {
        ResourcesRenderTranslator().translate(resources, visitor: &self)
    }
    
    public mutating func visitTile(_ tile: Tile) -> RenderTree? {
        TileRenderTranslator().translate(tile, visitor: &self)
    }
    
    public mutating func visitArticle(_ article: Article) -> RenderTree? {
        ArticleRenderTranslator().translate(article, visitor: &self)
    }
    
    public mutating func visitTutorialArticle(_ article: TutorialArticle) -> RenderTree? {
        TutorialArticleRenderTranslator().translate(article, visitor: &self)
    }
    
    public mutating func visitStack(_ stack: Stack) -> RenderTree? {
        StackRenderTranslator().translate(stack, visitor: &self)
    }
    
    public mutating func visitComment(_ comment: Comment) -> RenderTree? { nil }
    
    public mutating func visitDeprecationSummary(_ summary: DeprecationSummary) -> RenderTree? { nil }
    
    public mutating func visitSymbol(_ symbol: Symbol) -> RenderTree? {
        SymbolRenderTranslator().translate(symbol, visitor: &self)
    }
    
    init(
        context: DocumentationContext,
        bundle: DocumentationBundle,
        identifier: ResolvedTopicReference,
        source: URL?,
        renderContext: RenderContext? = nil,
        emitSymbolSourceFileURIs: Bool = false,
        emitSymbolAccessLevels: Bool = false
    ) {
        self.context = context
        self.bundle = bundle
        self.identifier = identifier
        self.source = source
        self.renderContext = renderContext
        self.contentRenderer = DocumentationContentRenderer(documentationContext: context, bundle: bundle)
        self.shouldEmitSymbolSourceFileURIs = emitSymbolSourceFileURIs
        self.shouldEmitSymbolAccessLevels = emitSymbolAccessLevels
    }
}
