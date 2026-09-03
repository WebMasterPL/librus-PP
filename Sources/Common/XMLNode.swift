import Foundation

/// Dead-simple read-only XML tree, enough for the Librus messages module.
final class XMLTreeNode {
    let name: String
    var text: String = ""
    private(set) var children: [XMLTreeNode] = []
    weak var parent: XMLTreeNode?

    init(name: String) { self.name = name }

    func addChild(_ node: XMLTreeNode) {
        node.parent = self
        children.append(node)
    }

    /// First descendant matching a path like `["response", "GetList", "data"]`.
    func firstNode(path: [String]) -> XMLTreeNode? {
        var current: XMLTreeNode? = self
        for part in path {
            current = current?.children.first { $0.name.caseInsensitiveCompare(part) == .orderedSame }
        }
        return current
    }

    func nodes(named name: String) -> [XMLTreeNode] {
        children.filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    func childText(_ name: String) -> String? {
        let t = nodes(named: name).first?.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return (t?.isEmpty ?? true) ? nil : t
    }

    static func parse(_ data: Data) -> XMLTreeNode? {
        let parser = XMLParser(data: data)
        let delegate = Builder()
        parser.delegate = delegate
        guard parser.parse() else { return nil }
        return delegate.root
    }

    static func parse(_ string: String) -> XMLTreeNode? {
        parse(Data(string.utf8))
    }

    private final class Builder: NSObject, XMLParserDelegate {
        var root: XMLTreeNode?
        private var stack: [XMLTreeNode] = []

        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String: String] = [:]) {
            let node = XMLTreeNode(name: elementName)
            stack.last?.addChild(node)
            stack.append(node)
            if root == nil { root = node }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            stack.last?.text += string
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            if let s = String(data: CDATABlock, encoding: .utf8) { stack.last?.text += s }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            if stack.count > 1 { stack.removeLast() }
        }
    }
}
