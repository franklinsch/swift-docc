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
    
    /// Creates a CTA for tutorials and tutorial articles.
    mutating func callToAction(with callToActionImage: ImageMedia?, volume: ResolvedTopicReference) -> CallToActionSection? {
        // Get all the tutorials and tutorial articles in the learning path, ordered.

        var surroundingTopics = [(reference: ResolvedTopicReference, kind: DocumentationNode.Kind)]()
        context.traverseBreadthFirst(from: volume) { node in
            if node.kind == .tutorial || node.kind == .tutorialArticle {
                surroundingTopics.append((node.reference, node.kind))
            }
            return .continue
        }
        
        // Find the tutorial or article that comes after the current page, if one exists.
        let nextTopicIndex = surroundingTopics.firstIndex(where: { $0.reference == identifier }).map { $0 + 1 }
        if let nextTopicIndex = nextTopicIndex, nextTopicIndex < surroundingTopics.count {
            let nextTopicReference = surroundingTopics[nextTopicIndex]
            let nextTopicReferenceIdentifier = visitResolvedTopicReference(nextTopicReference.reference) as! RenderReferenceIdentifier
            let nextTopic = try! context.entity(with: nextTopicReference.reference).semantic as! Abstracted & Titled
            
            let image = callToActionImage.map { visit($0) as! RenderReferenceIdentifier }
            
            return createCallToAction(reference: nextTopicReferenceIdentifier, kind: nextTopicReference.kind, title: nextTopic.title ?? "", abstract: inlineAbstractContentInTopic(nextTopic), image: image)
        }
        
        return nil
    }
    
    private mutating func createCallToAction(reference: RenderReferenceIdentifier, kind: DocumentationNode.Kind, title: String, abstract: [RenderInlineContent], image: RenderReferenceIdentifier?) -> CallToActionSection {
        let overridingTitle: String
        let eyebrow: String
        switch kind {
        case .tutorial:
            overridingTitle = "Get started"
            eyebrow = "Tutorial"
        case .tutorialArticle:
            overridingTitle = "Read article"
            eyebrow = "Article"
        default:
            fatalError("Unexpected kind '\(kind)', only tutorials and tutorial articles may be CTA destinations.")
        }
        
        let action = RenderInlineContent.reference(identifier: reference, isActive: true, overridingTitle: overridingTitle, overridingTitleInlineContent: [.text(overridingTitle)])
        return CallToActionSection(title: title, abstract: abstract, media: image, action: action, featuredEyebrow: eyebrow)
    }
    
    private mutating func inlineAbstractContentInTopic(_ topic: Abstracted) -> [RenderInlineContent] {
        if let abstract = topic.abstract {
            return (visitMarkupContainer(MarkupContainer(abstract)) as! [RenderBlockContent]).firstParagraph
        }
        
        return []
    }
    
    public mutating func visitIntro(_ intro: Intro) -> RenderTree? {
        IntroRenderTranslator().translate(intro, visitor: &self)
    }
    
    /// Add a requirement reference and return its identifier.
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
    
    func firstTutorial(ofTechnology technology: ResolvedTopicReference) -> (reference: ResolvedTopicReference, kind: DocumentationNode.Kind)? {
        guard let volume = (context.children(of: technology, kind: .volume)).first,
            let firstChapter = (context.children(of: volume.reference)).first,
            let firstTutorial = (context.children(of: firstChapter.reference)).first else
        {
            return nil
        }
        return firstTutorial
    }

    /// Returns a description of the total estimated duration to complete the tutorials of the given technology.
    /// - Returns: The estimated duration, or `nil` if there are no tutorials with time estimates.
    func totalEstimatedDuration(for technology: Technology) -> String? {
        var totalDurationMinutes: Int? = nil

        context.traverseBreadthFirst(from: identifier) { node in
            if let entity = try? context.entity(with: node.reference),
                let durationMinutes = (entity.semantic as? Timed)?.durationMinutes
            {
                if totalDurationMinutes == nil {
                    totalDurationMinutes = 0
                }
                totalDurationMinutes! += durationMinutes
            }

            return .continue
        }


        return totalDurationMinutes.flatMap(contentRenderer.formatEstimatedDuration(minutes:))
    }

    public mutating func visitTechnology(_ technology: Technology) -> RenderTree? {
        TechnologyRenderTranslator().translate(technology, visitor: &self)
    }
    
    mutating func createTopicRenderReferences() -> [String: RenderReference] {
        var renderReferences: [String: RenderReference] = [:]
        let renderer = DocumentationContentRenderer(documentationContext: context, bundle: bundle)
        
        for reference in collectedTopicReferences {
            var renderReference: TopicRenderReference
            var dependencies: RenderReferenceDependencies
            
            if let renderContext = renderContext, let prerendered = renderContext.store.content(for: reference)?.renderReference as? TopicRenderReference,
                let renderReferenceDependencies = renderContext.store.content(for: reference)?.renderReferenceDependencies {
                renderReference = prerendered
                dependencies = renderReferenceDependencies
            } else {
                dependencies = RenderReferenceDependencies()
                renderReference = renderer.renderReference(for: reference, dependencies: &dependencies)
            }
            
            for link in dependencies.linkReferences {
                linkReferences[link.identifier.identifier] = link
            }
            
            for dependencyReference in dependencies.topicReferences {
                var dependencyRenderReference: TopicRenderReference
                if let renderContext = renderContext, let prerendered = renderContext.store.content(for: dependencyReference)?.renderReference as? TopicRenderReference {
                    dependencyRenderReference = prerendered
                } else {
                    var dependencies = RenderReferenceDependencies()
                    dependencyRenderReference = renderer.renderReference(for: dependencyReference, dependencies: &dependencies)
                }
                renderReferences[dependencyReference.absoluteString] = dependencyRenderReference
            }
            
            // Add any conformance constraints to the reference, if any are present.
            if let conformanceSection = renderer.conformanceSectionFor(reference, collectedConstraints: collectedConstraints) {
                renderReference.conformance = conformanceSection
            }
            
            renderReferences[reference.absoluteString] = renderReference
        }

        for unresolved in collectedUnresolvedTopicReferences {
            let renderReference = UnresolvedRenderReference(
                identifier: RenderReferenceIdentifier(unresolved.topicURL.absoluteString),
                title: unresolved.title ?? unresolved.topicURL.absoluteString
            )
            renderReferences[renderReference.identifier.identifier] = renderReference
        }
        
        return renderReferences
    }
    
    func addReferences<Reference>(_ references: [String: Reference], to node: inout RenderNode) where Reference: RenderReference {
        node.references.merge(references) { _, new in new }
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

    public mutating func visitLink(_ link: URL, defaultTitle overridingTitle: String?) -> RenderInlineContent {
        let overridingTitleInlineContent: [RenderInlineContent]? = overridingTitle.map { [RenderInlineContent.text($0)] }
        
        let action: RenderInlineContent
        // We expect, at this point of the rendering, this API to be called with valid URLs, otherwise crash.
        let unresolved = UnresolvedTopicReference(topicURL: ValidatedURL(link)!)
        if case let .resolved(resolved) = context.resolve(.unresolved(unresolved), in: bundle.rootReference) {
            action = RenderInlineContent.reference(identifier: RenderReferenceIdentifier(resolved.absoluteString),
                                                   isActive: true,
                                                   overridingTitle: overridingTitle,
                                                   overridingTitleInlineContent: overridingTitleInlineContent)
            collectedTopicReferences.append(resolved)
        } else if !ResolvedTopicReference.urlHasResolvedTopicScheme(link) {
            // This is an external link
            let externalLinkIdentifier = RenderReferenceIdentifier(forExternalLink: link.absoluteString)
            if linkReferences.keys.contains(externalLinkIdentifier.identifier) {
                // If we've already seen this link, return the existing reference with an overriden title.
                action = RenderInlineContent.reference(identifier: externalLinkIdentifier,
                                                       isActive: true,
                                                       overridingTitle: overridingTitle,
                                                       overridingTitleInlineContent: overridingTitleInlineContent)
            } else {
                // Otherwise, create and save a new link reference.
                let linkReference = LinkReference(identifier: externalLinkIdentifier,
                                                  title: overridingTitle ?? link.absoluteString,
                                                  titleInlineContent: overridingTitleInlineContent ?? [.text(link.absoluteString)],
                                                  url: link.absoluteString)
                linkReferences[externalLinkIdentifier.identifier] = linkReference
                
                action = RenderInlineContent.reference(identifier: externalLinkIdentifier, isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil)
            }
        } else {
            // This is an unresolved doc: URL. We render the link inactive by converting it to plain text,
            // as it may break routing or other downstream uses of the URL.
            action = RenderInlineContent.text(link.path)
        }
        
        return action
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
    
    mutating func contentLayouts<MarkupLayouts: Sequence>(_ markupLayouts: MarkupLayouts) -> [ContentLayout] where MarkupLayouts.Element == MarkupLayout {
        return markupLayouts.map { content in
            switch content {
            case .markup(let markup):
                return .fullWidth(content: visitMarkupContainer(markup) as! [RenderBlockContent])
            case .contentAndMedia(let contentAndMedia):
                return .contentAndMedia(content: visitContentAndMedia(contentAndMedia) as! ContentAndMediaSection)
            case .stack(let stack):
                return .columns(content: self.visitStack(stack) as! [ContentAndMediaSection])
            }
        }
    }
    
    public mutating func visitStack(_ stack: Stack) -> RenderTree? {
        StackRenderTranslator().translate(stack, visitor: &self)
    }
    
    public mutating func visitComment(_ comment: Comment) -> RenderTree? { nil }
    
    public mutating func visitDeprecationSummary(_ summary: DeprecationSummary) -> RenderTree? { nil }

    /// The current module context for symbols.
    private var currentSymbolModuleName: String? = nil
    /// The current symbol context.
    var currentSymbol: ResolvedTopicReference? = nil

    /// Renders automatically generated task groups
    mutating func renderAutomaticTaskGroupsSection(_ taskGroups: [AutomaticTaskGroupSection], contentCompiler: inout RenderContentCompiler) -> [TaskGroupRenderSection] {
        return taskGroups.map { group in
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
    
    /// Renders a list of topic groups.
    mutating func renderGroups(_ topics: GroupedSection, allowExternalLinks: Bool, contentCompiler: inout RenderContentCompiler) -> [TaskGroupRenderSection] {
        return topics.taskGroups.compactMap { group in
            
            let abstractContent = group.abstract.map {
                return visitMarkup($0.content) as! [RenderInlineContent]
            }
            
            let discussion = group.discussion.map { discussion -> ContentRenderSection in
                let discussionContent = visitMarkupContainer(MarkupContainer(discussion.content)) as! [RenderBlockContent]
                return ContentRenderSection(kind: .content, content: discussionContent, heading: "Discussion")
            }
            
            let taskGroupRenderSection = TaskGroupRenderSection(
                title: group.heading?.plainText,
                abstract: abstractContent,
                discussion: discussion,
                identifiers: group.links.compactMap { link in
                    switch link {
                    case let link as Link:
                        if !allowExternalLinks {
                            // For links require documentation scheme
                            guard let _ = link.destination.flatMap(ValidatedURL.init)?.requiring(scheme: ResolvedTopicReference.urlScheme) else {
                                return nil
                            }
                        }
                        
                        if let referenceInlines = contentCompiler.visitLink(link) as? [RenderInlineContent],
                            let renderReference = referenceInlines.first(where: { inline in
                            switch inline {
                            case .reference(_,_,_,_):
                                return true
                            default:
                                return false
                            }
                        }),
                           case let RenderInlineContent.reference(identifier: identifier, isActive: _, overridingTitle: _, overridingTitleInlineContent: _) = renderReference {
                            return identifier.identifier
                        }
                    case let link as SymbolLink:
                        if let referenceInlines = contentCompiler.visitSymbolLink(link) as? [RenderInlineContent],
                            let renderReference = referenceInlines.first(where: { inline in
                            switch inline {
                            case .reference:
                                return true
                            default:
                                return false
                            }
                        }),
                           case let RenderInlineContent.reference(identifier: identifier, isActive: _, overridingTitle: _, overridingTitleInlineContent: _) = renderReference {
                            return identifier.identifier
                        }
                    default: break
                    }
                    return nil
                }
            )
            
            // rdar://74617294 If a task group doesn't have any symbol or external links it shouldn't be rendered
            guard !taskGroupRenderSection.identifiers.isEmpty else {
                return nil
            }
            
            return taskGroupRenderSection
        }
    }
    
    @discardableResult
    mutating func collectUnresolvableSymbolReference(destination: UnresolvedTopicReference, title: String) -> UnresolvedTopicReference? {
        guard let url = ValidatedURL(destination.topicURL.url) else {
            return nil
        }
        
        let reference = UnresolvedTopicReference(topicURL: url, title: title)
        collectedUnresolvedTopicReferences.append(reference)
        
        return reference
    }
    
    public mutating func visitSymbol(_ symbol: Symbol) -> RenderTree? {
        SymbolRenderTranslator().translate(symbol, visitor: &self)
    }

    /// Creates a render reference for the given media and registers the reference to include it in the `references` dictionary.
    mutating func createAndRegisterRenderReference(forMedia media: ResourceReference?, poster: ResourceReference? = nil, altText: String? = nil, assetContext: DataAsset.Context = .display) -> RenderReferenceIdentifier {
        var mediaReference = RenderReferenceIdentifier("")
        guard let oldMedia = media,
              let path = context.identifier(forAssetName: oldMedia.path, in: identifier) else { return mediaReference }
        
        let media = ResourceReference(bundleIdentifier: oldMedia.bundleIdentifier, path: path)
        let fileExtension = NSString(string: media.path).pathExtension
        
        func resolveAsset() -> DataAsset? {
            renderContext?.store.content(
                forAssetNamed: media.path, bundleIdentifier: identifier.bundleIdentifier)
            ?? context.resolveAsset(named: media.path, in: identifier)
        }
        
        // Check if media is a supported image.
        if DocumentationContext.isFileExtension(fileExtension, supported: .image),
            let resolvedImages = resolveAsset()
        {
            mediaReference = RenderReferenceIdentifier(media.path)
            
            imageReferences[media.path] = ImageReference(
                identifier: mediaReference,
                // If no alt text has been provided and this image has been registered previously, use the registered alt text.
                altText: altText ?? imageReferences[media.path]?.altText,
                imageAsset: resolvedImages
            )
        }
        
        if DocumentationContext.isFileExtension(fileExtension, supported: .video),
           let resolvedVideos = resolveAsset()
        {
            mediaReference = RenderReferenceIdentifier(media.path)
            let poster = poster.map { createAndRegisterRenderReference(forMedia: $0) }
            videoReferences[media.path] = VideoReference(identifier: mediaReference, altText: altText, videoAsset: resolvedVideos, poster: poster)
        }
        
        if assetContext == DataAsset.Context.download, let resolvedDownload = resolveAsset() {
            // Create a download reference if possible.
            let downloadReference: DownloadReference
            do {            
                mediaReference = RenderReferenceIdentifier(media.path)
                let downloadURL = resolvedDownload.variants.first!.value
                let downloadData = try context.dataProvider.contentsOfURL(downloadURL, in: bundle)
                downloadReference = DownloadReference(identifier: mediaReference,
                    renderURL: downloadURL,
                    sha512Checksum: Checksum.sha512(of: downloadData))
            } catch {
                // It seems this is the way to error out of here.
                return mediaReference
            }

            // Add the file to the download references.
            mediaReference = RenderReferenceIdentifier(media.path)
            downloadReferences[media.path] = downloadReference
        }

        return mediaReference
    }
    
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
    
    private var bundleAvailability: [BundleModuleIdentifier: [AvailabilityRenderItem]] = [:]
    
    /// Given module availability and the current platforms we're building against return if the module is a beta framework.
    private func isModuleBeta(moduleAvailability: DefaultAvailability.ModuleAvailability, currentPlatforms: [String: PlatformVersion]) -> Bool {
        guard
            // Check if we have a symbol availability version and a target platform version
            let moduleVersion = Version(versionString: moduleAvailability.platformVersion),
            // We require at least two components for a platform version (e.g. 10.15 or 10.15.1)
            moduleVersion.count >= 2,
            // Verify we're building against this platform
            let targetPlatformVersion = currentPlatforms[moduleAvailability.platformName.displayName],
            // Verify the target platform version is in beta
            targetPlatformVersion.beta else {
                return false
        }
        
        // Build a module availability version, defaulting the patch number to 0 if not provided (e.g. 10.15)
        let moduleVersionTriplet = VersionTriplet(moduleVersion[0], moduleVersion[1], moduleVersion.count > 2 ? moduleVersion[2] : 0)
        
        return moduleVersionTriplet == targetPlatformVersion.version
    }
    
    /// The default availability for modules in a given bundle and module.
    mutating func defaultAvailability(for bundle: DocumentationBundle, moduleName: String, currentPlatforms: [String: PlatformVersion]?) -> [AvailabilityRenderItem]? {
        let identifier = BundleModuleIdentifier(bundle: bundle, moduleName: moduleName)
        
        // Cached availability
        if let availability = bundleAvailability[identifier] {
            return availability
        }
        
        // Find default module availability if existing
        guard let bundleDefaultAvailability = bundle.defaultAvailability,
            let moduleAvailability = bundleDefaultAvailability.modules[moduleName] else {
            return nil
        }
        
        // Prepare for rendering
        let renderedAvailability = moduleAvailability
            .map({ availability -> AvailabilityRenderItem in
                return AvailabilityRenderItem(
                    name: availability.platformName.displayName,
                    introduced: availability.platformVersion,
                    isBeta: currentPlatforms.map({ isModuleBeta(moduleAvailability: availability, currentPlatforms: $0) }) ?? false
                )
            })
        
        // Cache the availability to use for further symbols
        bundleAvailability[identifier] = renderedAvailability
        
        // Return the availability
        return renderedAvailability
    }
   
    mutating func createRenderSections(
        for symbol: Symbol,
        renderNode: inout RenderNode,
        translators: [RenderSectionTranslator]
    ) -> [VariantCollection<CodableContentSection?>] {
        translators.compactMap { translator in
            translator.translateSection(for: symbol, renderNode: &renderNode, renderNodeTranslator: &self)
        }
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

fileprivate typealias BundleModuleIdentifier = String

extension BundleModuleIdentifier {
    fileprivate init(bundle: DocumentationBundle, moduleName: String) {
        self = "\(bundle.identifier):\(moduleName)"
    }
}

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
