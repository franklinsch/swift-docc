/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

struct RenderReferenceGenerator {
    /// Creates a render reference for the given media and registers the reference to include it in the `references` dictionary.
    func createAndRegisterRenderReference(
        forMedia media: ResourceReference?,
        poster: ResourceReference? = nil,
        altText: String? = nil,
        assetContext: DataAsset.Context = .display,
        visitor: inout RenderNodeTranslator
    ) -> RenderReferenceIdentifier {
        let context = visitor.context
        let renderContext = visitor.renderContext
        let identifier = visitor.identifier
        let bundle = visitor.bundle
        
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
            
            visitor.imageReferences[media.path] = ImageReference(
                identifier: mediaReference,
                // If no alt text has been provided and this image has been registered previously, use the
                // registered alt text.
                altText: altText ?? visitor.imageReferences[media.path]?.altText,
                imageAsset: resolvedImages
            )
        }
        
        if DocumentationContext.isFileExtension(fileExtension, supported: .video),
           let resolvedVideos = resolveAsset()
        {
            mediaReference = RenderReferenceIdentifier(media.path)
            let poster = poster.map { createAndRegisterRenderReference(forMedia: $0, visitor: &visitor) }
            visitor.videoReferences[media.path] = VideoReference(
                identifier: mediaReference,
                altText: altText,
                videoAsset: resolvedVideos,
                poster: poster
            )
        }
        
        if assetContext == DataAsset.Context.download, let resolvedDownload = resolveAsset() {
            // Create a download reference if possible.
            let downloadReference: DownloadReference
            do {
                mediaReference = RenderReferenceIdentifier(media.path)
                let downloadURL = resolvedDownload.variants.first!.value
                let downloadData = try context.dataProvider.contentsOfURL(downloadURL, in: bundle)
                downloadReference = DownloadReference(
                    identifier: mediaReference,
                    renderURL: downloadURL,
                    sha512Checksum: Checksum.sha512(of: downloadData)
                )
            } catch {
                // It seems this is the way to error out of here.
                return mediaReference
            }
            
            // Add the file to the download references.
            mediaReference = RenderReferenceIdentifier(media.path)
            visitor.downloadReferences[media.path] = downloadReference
        }
        
        return mediaReference
    }
    
}
