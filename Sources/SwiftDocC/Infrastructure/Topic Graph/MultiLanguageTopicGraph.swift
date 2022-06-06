/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

struct MultiLanguageTopicGraph {
    typealias Node = TopicGraph.Node
    typealias Traversal = TopicGraph.Traversal
    
    var topicGraphs = [SourceLanguage: TopicGraph]()
    
    var nodes: [TopicGraph.Node] {
        topicGraphs.values.flatMap { topicGraph -> [TopicGraph.Node] in
            Array(topicGraph.nodes.values)
        }
    }

    mutating func addNode(_ node: Node, sourceLanguage: SourceLanguage) {
        topicGraphs[sourceLanguage, default: TopicGraph()].addNode(node)
    }
    
    mutating func replaceNode(_ node: Node, with newNode: Node, sourceLanguage: SourceLanguage) {
        topicGraphs[sourceLanguage, default: TopicGraph()].replaceNode(node, with: newNode)
    }
    
    mutating func updateReference(_ reference: ResolvedTopicReference, newReference: ResolvedTopicReference, sourceLanguage: SourceLanguage) {
        topicGraphs[sourceLanguage, default: TopicGraph()].updateReference(reference, newReference: newReference)
    }
    
    mutating func unsafelyAddEdge(source: ResolvedTopicReference, target: ResolvedTopicReference, sourceLanguage: SourceLanguage) {
        topicGraphs[sourceLanguage, default: TopicGraph()].unsafelyAddEdge(source: source, target: target)
    }
    
    mutating func addEdge(from source: Node, to target: Node, sourceLanguage: SourceLanguage) {
        topicGraphs[sourceLanguage, default: TopicGraph()].addEdge(from: source, to: target)
    }
    
    mutating func removeEdges(from source: Node, sourceLanguage: SourceLanguage) {
        topicGraphs[sourceLanguage, default: TopicGraph()].removeEdges(from: source)
    }
    
    mutating func removeEdge(
        fromReference source: ResolvedTopicReference,
        toReference target: ResolvedTopicReference,
        sourceLanguage: SourceLanguage
    ) {
        topicGraphs[sourceLanguage, default: TopicGraph()].removeEdge(fromReference: source, toReference: target)
    }
    
    func nodeWithReference(_ reference: ResolvedTopicReference, sourceLanguage: SourceLanguage) -> Node? {
        topicGraphs[sourceLanguage, default: TopicGraph()].nodeWithReference(reference)
    }
    
    func traverseDepthFirst(from startingNode: Node, _ observe: (Node) -> Traversal, sourceLanguage: SourceLanguage) {
        topicGraphs[sourceLanguage, default: TopicGraph()].traverseDepthFirst(from: startingNode, observe)
    }
    
    func traverseBreadthFirst(from startingNode: Node, _ observe: (Node) -> Traversal, sourceLanguage: SourceLanguage) {
        topicGraphs[sourceLanguage, default: TopicGraph()].traverseDepthFirst(from: startingNode, observe)
    }
    
    func isLinkable(_ reference: ResolvedTopicReference, sourceLanguage: SourceLanguage) -> Bool {
        topicGraphs[sourceLanguage, default: TopicGraph()].isLinkable(reference)
    }
    
    func hasParent(_ reference: ResolvedTopicReference, sourceLanguage: SourceLanguage) -> Bool {
        topicGraphs[sourceLanguage]?.reverseEdges[reference] != nil
    }
    
    func children(of node: Node, sourceLanguage: SourceLanguage) -> [ResolvedTopicReference] {
        topicGraphs[sourceLanguage]?.edges[node.reference] ?? []
    }
    
    func parents(of reference: ResolvedTopicReference, sourceLanguage: SourceLanguage) -> [ResolvedTopicReference] {
        topicGraphs[sourceLanguage]?.reverseEdges[reference] ?? []
    }
    
    func dump(
        startingAt node: Node,
        keyPath: KeyPath<TopicGraph.Node, String> = \.title,
        decorator: String = "",
        sourceLanguage: SourceLanguage
    ) -> String {
        topicGraphs[sourceLanguage, default: TopicGraph()].dump(startingAt: node)
    }
    
}
