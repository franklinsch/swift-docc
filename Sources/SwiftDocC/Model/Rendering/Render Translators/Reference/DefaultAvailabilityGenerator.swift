//
//  File.swift
//  
//
//  Created by Franklin Schrans on 01/11/2021.
//

import Foundation

struct DefaultAvailabilityGenerator {
    /// The default availability for modules in a given bundle and module.
    func createDefaultAvailability(
        for bundle: DocumentationBundle,
        moduleName: String,
        currentPlatforms: [String: PlatformVersion]?,
        visitor: inout RenderNodeTranslator
    ) -> [AvailabilityRenderItem]? {
        let identifier = BundleModuleIdentifier(bundle: bundle, moduleName: moduleName)
        
        // Cached availability
        if let availability = visitor.bundleAvailability[identifier] {
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
        visitor.bundleAvailability[identifier] = renderedAvailability
        
        // Return the availability
        return renderedAvailability
    }
    
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
}

typealias BundleModuleIdentifier = String

extension BundleModuleIdentifier {
    fileprivate init(bundle: DocumentationBundle, moduleName: String) {
        self = "\(bundle.identifier):\(moduleName)"
    }
}
