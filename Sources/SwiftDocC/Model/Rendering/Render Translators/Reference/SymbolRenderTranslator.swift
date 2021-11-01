/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a symbol into a render node.
struct SymbolRenderTranslator: SemanticTranslator {
    
    /// Translates a symbol into a render node.
    func translate(_ symbol: Symbol, visitor: inout RenderNodeTranslator) -> RenderNode {
        let context = visitor.context
        let bundle = visitor.bundle
        var identifier = visitor.identifier
        
        let documentationNode = try! context.entity(with: identifier)
        
        // Add the source languages declared in the documentation node.
        identifier.sourceLanguages = identifier.sourceLanguages.union(documentationNode.availableSourceLanguages)
        var node = RenderNode(identifier: identifier, kind: .symbol)
        var contentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: identifier)

        visitor.currentSymbol = identifier
        
        /*
         FIXME: We shouldn't be doing this kind of crawling here.
         
         We should be doing a graph search to build up a breadcrumb and pass that to the translator, giving
         a definitive hierarchy before we even begin to build a RenderNode.
         */
        var ref = documentationNode.reference
        while let grandparent = context.parents(of: ref).first {
            ref = grandparent
        }
        
        node.metadata.modulesVariants = VariantCollection<[RenderMetadata.Module]?>(
            from: symbol.moduleNameVariants,
            optionalValue: symbol.bystanderModuleNamesVariants
        ) { _, moduleName, bystanderModuleNames in
            [RenderMetadata.Module(name: moduleName, relatedModules: bystanderModuleNames)]
        } ?? .init(defaultValue: nil)
        
        node.metadata.extendedModuleVariants = VariantCollection<String?>(from: symbol.extendedModuleVariants)
        
        node.metadata.platformsVariants = VariantCollection<[AvailabilityRenderItem]?>(
            from: symbol.moduleNameVariants,
            optionalValue: symbol.availabilityVariants
        ) { _, moduleName, availability in
            (availability?.availability
                .compactMap { availability -> AvailabilityRenderItem? in
                    // Filter items with insufficient availability data
                    guard availability.introducedVersion != nil else {
                        return nil
                    }
                    guard let name = availability.domain.map({ PlatformName(operatingSystemName: $0.rawValue) }),
                          let currentPlatform = context.externalMetadata.currentPlatforms?[name.displayName] else {
                              // No current platform provided by the context
                              return AvailabilityRenderItem(availability, current: nil)
                          }
                    
                    return AvailabilityRenderItem(availability, current: currentPlatform)
                } ?? visitor.defaultAvailability(
                    for: bundle,
                    moduleName: moduleName,
                    currentPlatforms: context.externalMetadata.currentPlatforms
                )
            )?.filter({ !($0.unconditionallyUnavailable == true) })
                .sorted(by: AvailabilityRenderOrder.compare)
        } ?? .init(defaultValue: nil)
        
        node.metadata.requiredVariants = VariantCollection<Bool>(
            from: symbol.isRequiredVariants
        ) ?? .init(defaultValue: false)
        
        node.metadata.role = visitor.contentRenderer.role(for: documentationNode.kind).rawValue
        node.metadata.roleHeadingVariants = VariantCollection<String?>(from: symbol.roleHeadingVariants)
        node.metadata.titleVariants = VariantCollection<String?>(from: symbol.titleVariants)
        node.metadata.externalIDVariants = VariantCollection<String?>(from: symbol.externalIDVariants)
        
        // Remove any optional namespace (e.g. "swift.") for rendering
        node.metadata.symbolKindVariants = VariantCollection<String?>(from: symbol.kindVariants) { _, kindVariants in
            kindVariants.identifier.components(separatedBy: ".").last
        } ?? .init(defaultValue: nil)
        
        node.metadata.conformance = visitor.contentRenderer.conformanceSectionFor(
            identifier,
            collectedConstraints: visitor.collectedConstraints
        )
        node.metadata.fragmentsVariants = visitor.contentRenderer.subHeadingFragments(for: documentationNode)
        node.metadata.navigatorTitleVariants = visitor.contentRenderer.navigatorFragments(for: documentationNode)
        
        let generator = PresentationURLGenerator(context: context, baseURL: bundle.baseURL)
        
        node.variants = documentationNode.availableSourceLanguages
            .sorted(by: { language1, language2 in
                // Emit Swift first, then alphabetically.
                switch (language1, language2) {
                case (.swift, _): return true
                case (_, .swift): return false
                default: return language1.id < language2.id
                }
            })
            .map { sourceLanguage in
                RenderNode.Variant(
                    traits: [.interfaceLanguage(sourceLanguage.id)],
                    paths: [
                        generator.presentationURLForReference(identifier).path
                    ]
                )
            }
        
        visitor.collectedTopicReferences.append(identifier)
        
        let contentRenderer = DocumentationContentRenderer(documentationContext: context, bundle: bundle)
        node.metadata.tags = contentRenderer.tags(for: identifier)

        var hierarchyTranslator = RenderHierarchyTranslator(context: context, bundle: bundle)
        let hierarchy = hierarchyTranslator.visitSymbol(identifier)
        visitor.collectedTopicReferences.append(contentsOf: hierarchyTranslator.collectedTopicReferences)
        node.hierarchy = hierarchy
        
        func createDefaultAbstract() -> [RenderInlineContent] {
            // Introduce a special behavior for generated bundles.
            if context.externalMetadata.isGeneratedBundle {
                if documentationNode.kind != .module {
                    // Undocumented symbols get a default abstract.
                    return [.text("No overview available.")]
                } else {
                    // Undocumented module pages get an empty abstract.
                    return [.text("")]
                }
            } else {
                // For non-generated bundles always add the default abstract.
                return [.text("No overview available.")]
            }
        }

        // In case `inheritDocs` is disabled and there is actually origin data for the symbol, then include origin
        // information as abstract. Generate the placeholder abstract only in case there isn't an authored abstract
        // coming from a doc extension.
        if !context.externalMetadata.inheritDocs,
            let origin = (documentationNode.semantic as! Symbol).origin,
            symbol.abstractSection == nil
        {
            // Create automatic abstract for inherited symbols.
            node.abstract = [.text("Inherited from "), .codeVoice(code: origin.displayName), .text(".")]
        } else {
            node.abstractVariants = VariantCollection<[RenderInlineContent]?>(
                from: symbol.abstractSectionVariants
            ) { _, abstractSection in
                MarkupSequenceRenderTranslator().translate(abstractSection.content, visitor: &visitor)
            } ?? .init(defaultValue: createDefaultAbstract())
        }
        
        node.primaryContentSectionsVariants.append(
            contentsOf: visitor.createRenderSections(
                for: symbol,
                renderNode: &node,
                translators: [
                    DeclarationsSectionTranslator(),
                    ReturnsSectionTranslator(),
                    ParametersSectionTranslator(),
                    DiscussionSectionTranslator()
                ]
            )
        )
        
        if visitor.shouldEmitSymbolSourceFileURIs {
            node.metadata.sourceFileURIVariants = VariantCollection<String?>(
                from: symbol.locationVariants
            ) { _, location in
                location.uri
            } ?? .init(defaultValue: nil)
        }
        
        if visitor.shouldEmitSymbolAccessLevels {
            node.metadata.symbolAccessLevelVariants = VariantCollection<String?>(from: symbol.accessLevelVariants)
        }
        
        node.relationshipSectionsVariants = VariantCollection<[RelationshipsRenderSection]>(
            from: symbol.relationshipsVariants
        ) { trait, relationships in
            guard !relationships.groups.isEmpty else {
                return []
            }
            
            var groupSections = [RelationshipsRenderSection]()
            
            let eligibleGroups = relationships.groups
                .sorted(by: { (group1, group2) -> Bool in
                    return group1.sectionOrder < group2.sectionOrder
                })
            
            for group in eligibleGroups {
                // destination url → symbol title
                var destinationsMap = [TopicReference: String]()
                
                for destination in group.destinations {
                    if let constraints = relationships.constraints[destination] {
                        visitor.collectedConstraints[destination] = constraints
                    }
                    
                    switch destination {
                    case .resolved(let resolved):
                        let node = try! context.entity(with: resolved)
                        let resolver = LinkTitleResolver(context: context, source: resolved.url)
                        let resolvedTitle = resolver.title(for: node)
                        destinationsMap[destination] = resolvedTitle?[trait]
                        
                        // Add relationship to render references
                        visitor.collectedTopicReferences.append(resolved)
                    case .unresolved(let unresolved):
                        // Try creating a render reference anyway
                        if let title = relationships.targetFallbacks[destination],
                           let reference = visitor.collectUnresolvableSymbolReference(
                                destination: unresolved,
                                title: title
                            )
                        {
                            destinationsMap[destination] = reference.title
                        }
                        continue
                    }
                }
                
                // Links section
                var orderedDestinations = Array(destinationsMap.keys)
                orderedDestinations.sort { destination1, destination2 -> Bool in
                    return destinationsMap[destination1]! <= destinationsMap[destination2]!
                }
                let groupSection = RelationshipsRenderSection(
                    type: group.kind.rawValue,
                    title: group.heading.plainText,
                    identifiers: orderedDestinations.map { $0.url!.absoluteString }
                )
                groupSections.append(groupSection)
            }
            
            return groupSections
        } ?? .init(defaultValue: [])
        
        node.topicSectionsVariants = VariantCollection<[TaskGroupRenderSection]>(
            from: symbol.automaticTaskGroupsVariants,
            optionalValue: symbol.topicsVariants
        ) { _, automaticTaskGroups, topics in
            var sections = [TaskGroupRenderSection]()
            
            if let topics = topics, !topics.taskGroups.isEmpty {
                sections.append(
                    contentsOf: visitor.renderGroups(
                        topics,
                        allowExternalLinks: false,
                        contentCompiler: &contentCompiler
                    )
                )
            }
            
            // Place "top" rendering preference automatic task groups
            // after any user-defined task groups but before automatic curation.
            if !automaticTaskGroups.isEmpty {
                sections.append(
                    contentsOf: visitor.renderAutomaticTaskGroupsSection(
                        automaticTaskGroups.filter({ $0.renderPositionPreference == .top }),
                        contentCompiler: &contentCompiler
                    )
                )
            }
            
            // Children of the current symbol that have not been curated manually in a task group will all
            // be automatically curated in task groups after their symbol kind: "Properties", "Enumerations", etc.
            let alreadyCurated = Set(sections.flatMap { $0.identifiers })
            let groups = try! AutomaticCuration.topics(for: documentationNode, context: context)
            
            sections.append(contentsOf: groups.compactMap { group in
                let newReferences = group.references.filter { !alreadyCurated.contains($0.absoluteString) }
                guard !newReferences.isEmpty else { return nil }
                
                contentCompiler.collectedTopicReferences.append(contentsOf: newReferences)
                return TaskGroupRenderSection(
                    title: group.title,
                    abstract: nil,
                    discussion: nil,
                    identifiers: newReferences.map { $0.absoluteString }
                )
            })
            
            // Place "bottom" rendering preference automatic task groups
            // after any user-defined task groups but before automatic curation.
            if !automaticTaskGroups.isEmpty {
                sections.append(
                    contentsOf: visitor.renderAutomaticTaskGroupsSection(
                        automaticTaskGroups.filter({ $0.renderPositionPreference == .bottom }),
                        contentCompiler: &contentCompiler
                    )
                )
            }
            
            return sections
        } ?? .init(defaultValue: [])
        
        node.defaultImplementationsSectionsVariants = VariantCollection<[TaskGroupRenderSection]>(
            from: symbol.defaultImplementationsVariants,
            symbol.relationshipsVariants
        ) { _, defaultImplementations, relationships in
            guard !symbol.defaultImplementations.groups.isEmpty else {
                return []
            }
            
            for imp in defaultImplementations.implementations {
                let resolved: ResolvedTopicReference
                switch imp.reference {
                case .resolved(let reference):
                    resolved = reference
                case .unresolved(let unresolved):
                    // Try creating a render reference anyway
                    if let title = defaultImplementations.targetFallbacks[imp.reference],
                       let reference = visitor.collectUnresolvableSymbolReference(
                            destination: unresolved,
                            title: title
                       ),
                       let constraints = relationships.constraints[imp.reference]
                    {
                        visitor.collectedConstraints[.unresolved(reference)] = constraints
                    }
                    continue
                }
                
                // Add implementation to render references
                visitor.collectedTopicReferences.append(resolved)
                if let constraints = relationships.constraints[imp.reference] {
                    visitor.collectedConstraints[.resolved(resolved)] = constraints
                }
            }
            
            return defaultImplementations.groups.map { group in
                TaskGroupRenderSection(
                    title: group.heading,
                    abstract: nil,
                    discussion: nil,
                    identifiers: group.references.map({ $0.url!.absoluteString })
                )
            }
        } ?? .init(defaultValue: [])

        node.seeAlsoSectionsVariants = VariantCollection<[TaskGroupRenderSection]>(
            from: symbol.seeAlsoVariants
        ) { variant in
            // If the symbol contains an authored See Also section from the documentation extension,
            // add it as the first section under See Also.
            var seeAlsoSections = [TaskGroupRenderSection]()
            
            if let seeAlso = variant.map(\.1) {
                seeAlsoSections.append(
                    contentsOf: visitor.renderGroups(
                        seeAlso,
                        allowExternalLinks: true,
                        contentCompiler: &contentCompiler
                    )
                )
            }
            
            // Curate the current node's siblings as further See Also groups.
            if let seeAlso = try! AutomaticCuration.seeAlso(
                for: documentationNode,
                   context: context,
                   bundle: bundle,
                   renderContext: visitor.renderContext,
                   renderer: contentRenderer
            ) {
                contentCompiler.collectedTopicReferences.append(contentsOf: seeAlso.references)
                seeAlsoSections.append(TaskGroupRenderSection(
                    title: seeAlso.title,
                    abstract: nil,
                    discussion: nil,
                    identifiers: seeAlso.references.map { $0.absoluteString },
                    generated: true
                ))
            }

            return seeAlsoSections
        }
        
        node.deprecationSummaryVariants = VariantCollection<[RenderBlockContent]?>(
            from: symbol.deprecatedSummaryVariants
        ) { _, deprecatedSummary in
            // If there is a deprecation summary in a documentation extension file add it to the render node
            MarkupContainerRenderTranslator().translate(MarkupContainer(deprecatedSummary.content), visitor: &visitor)
        } ?? .init(defaultValue: nil)
        
        visitor.collectedTopicReferences.append(contentsOf: contentCompiler.collectedTopicReferences)
        node.references = visitor.createTopicRenderReferences()
        
        visitor.addReferences(visitor.imageReferences, to: &node)
        // See Also can contain external links, we need to separately transfer
        // link references from the content compiler
        visitor.addReferences(contentCompiler.linkReferences, to: &node)
        visitor.addReferences(visitor.linkReferences, to: &node)
        
        visitor.currentSymbol = nil
        return node
    }
}
