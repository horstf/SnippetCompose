import Foundation

enum ComposeTableParser {

    // MARK: - Public API

    static func load(from url: URL? = nil, prefix: String = "::") -> [String: String] {
        let fileURL = url ?? Bundle.main.url(forResource: "Compose", withExtension: "txt")
        guard let fileURL else {
            print("[ComposeTableParser] Compose.txt not found in bundle.")
            return [:]
        }
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            print("[ComposeTableParser] Failed to read \(fileURL.path)")
            return [:]
        }
        let table = parse(text, prefix: prefix)
        print("[ComposeTableParser] Loaded \(table.count) entries from \(fileURL.lastPathComponent)")
        return table
    }

    // MARK: - Parser

    static func parse(_ text: String, prefix: String = "::") -> [String: String] {
        var table = [String: String]()
        table.reserveCapacity(4096)

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
            guard trimmed.hasPrefix("<Multi_key>") else { continue }
            // Compose files use tabs (not spaces) before the colon, so we anchor on
            // the unambiguous `: "` sequence (colon + space + opening quote).
            guard let sepRange = trimmed.range(of: ": \"") else { continue }

            let lhs = String(trimmed[trimmed.startIndex..<sepRange.lowerBound])
            // rhs starts at the opening `"` character (2 chars after the colon)
            let quoteStart = trimmed.index(sepRange.lowerBound, offsetBy: 2)
            let rhs = String(trimmed[quoteStart...])

            guard let resultChar = extractQuotedString(from: rhs) else { continue }

            let keysyms = extractKeysyms(from: lhs)
            // keysyms includes "<Multi_key>" as the first token — skip it
            let tail = keysyms.dropFirst()
            guard !tail.isEmpty else { continue }

            var key = ""
            var valid = true
            for sym in tail {
                if sym == "Multi_key" {
                    // A second Multi_key in the sequence means "type the prefix again"
                    key += prefix
                } else if let ch = resolveKeysym(sym) {
                    key += ch
                } else {
                    valid = false; break
                }
            }
            guard valid else { continue }

            table[key] = resultChar
        }
        return table
    }

    // MARK: - Keysym resolution

    static func resolveKeysym(_ name: String) -> String? {
        // Skip dead keys
        if name.hasPrefix("dead_") { return nil }

        // Single ASCII character keysyms (letters, digits)
        if name.count == 1 {
            return name
        }

        // Unicode escape: U + hex digits
        if name.hasPrefix("U"), let scalar = UInt32(name.dropFirst(), radix: 16),
           let unicode = Unicode.Scalar(scalar) {
            return String(unicode)
        }

        // Named punctuation / special keysyms
        switch name {
        case "space":           return " "
        case "exclam":          return "!"
        case "quotedbl":        return "\""
        case "numbersign":      return "#"
        case "dollar":          return "$"
        case "percent":         return "%"
        case "ampersand":       return "&"
        case "apostrophe",
             "quoteright":      return "'"
        case "parenleft":       return "("
        case "parenright":      return ")"
        case "asterisk":        return "*"
        case "plus":            return "+"
        case "comma":           return ","
        case "minus":           return "-"
        case "period":          return "."
        case "slash":           return "/"
        case "colon":           return ":"
        case "semicolon":       return ";"
        case "less":            return "<"
        case "equal":           return "="
        case "greater":         return ">"
        case "question":        return "?"
        case "at":              return "@"
        case "bracketleft":     return "["
        case "backslash":       return "\\"
        case "bracketright":    return "]"
        case "asciicircum":     return "^"
        case "underscore":      return "_"
        case "grave",
             "quoteleft":       return "`"
        case "braceleft":       return "{"
        case "bar":             return "|"
        case "braceright":      return "}"
        case "asciitilde":      return "~"
        case "acute":           return "\u{00B4}"
        case "cedilla":         return "\u{00B8}"
        case "diaeresis":       return "\u{00A8}"
        case "degree":          return "\u{00B0}"
        case "mu":              return "\u{03BC}"
        case "section":         return "\u{00A7}"
        case "copyright":       return "\u{00A9}"
        case "registered":      return "\u{00AE}"
        case "EuroSign":        return "\u{20AC}"
        case "sterling":        return "\u{00A3}"
        case "yen":             return "\u{00A5}"
        case "cent":            return "\u{00A2}"
        case "notsign":         return "\u{00AC}"
        case "paragraph":       return "\u{00B6}"
        case "ordfeminine":     return "\u{00AA}"
        case "ordmasculine":    return "\u{00BA}"
        case "guillemotleft":   return "\u{00AB}"
        case "guillemotright":  return "\u{00BB}"
        case "onehalf":         return "\u{00BD}"
        case "onequarter":      return "\u{00BC}"
        case "threequarters":   return "\u{00BE}"
        case "masculine":       return "\u{00BA}"
        case "endash":          return "\u{2013}"
        case "emdash":          return "\u{2014}"
        case "ellipsis":        return "\u{2026}"
        case "periodcentered":  return "\u{00B7}"
        case "plusminus":       return "\u{00B1}"
        case "multiply":        return "\u{00D7}"
        case "division":        return "\u{00F7}"
        case "igrave":          return "i"     // fallback
        // Two-digit numeric keysym names used in Compose file (0-9 are single char, handled above)
        default: return nil
        }
    }

    // MARK: - Private helpers

    private static func extractQuotedString(from rhs: String) -> String? {
        // Find first unescaped '"' then scan until closing '"', honouring \" and \\ escapes
        var idx = rhs.startIndex
        guard let open = rhs[idx...].firstIndex(of: "\"") else { return nil }
        idx = rhs.index(after: open)

        var result = ""
        while idx < rhs.endIndex {
            let ch = rhs[idx]
            if ch == "\\" {
                let next = rhs.index(after: idx)
                guard next < rhs.endIndex else { break }
                let escaped = rhs[next]
                switch escaped {
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "n":  result.append("\n")
                case "t":  result.append("\t")
                default:   result.append(escaped)
                }
                idx = rhs.index(after: next)
            } else if ch == "\"" {
                return result.isEmpty ? nil : result
            } else {
                result.append(ch)
                idx = rhs.index(after: idx)
            }
        }
        return nil
    }

    private static func extractKeysyms(from lhs: String) -> [String] {
        var result: [String] = []
        var idx = lhs.startIndex
        while idx < lhs.endIndex {
            guard let open = lhs[idx...].firstIndex(of: "<") else { break }
            let afterOpen = lhs.index(after: open)
            guard afterOpen < lhs.endIndex,
                  let close = lhs[afterOpen...].firstIndex(of: ">") else { break }
            result.append(String(lhs[afterOpen..<close]))
            idx = lhs.index(after: close)
        }
        return result
    }
}
