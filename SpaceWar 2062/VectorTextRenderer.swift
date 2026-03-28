//
//  VectorTextRenderer.swift
//  SpaceWar 2062
//
//  Created by Michael Stern on 1/9/26.
//  Copyright © 2026 Michael Stern. All rights reserved.
//

import SpriteKit

/// Renders retro vector-style text and numbers using line segments
struct VectorTextRenderer {
    
    // MARK: - Seven-Segment Digit Rendering
    
    /// Creates a seven-segment display digit node
    /// - Parameters:
    ///   - digit: The digit to render (0-9)
    ///   - scale: Scale factor for the digit
    /// - Returns: A shape node containing the rendered digit
    static func createDigitNode(_ digit: Int, scale: CGFloat = 1.0) -> SKShapeNode {
        let A = (CGPoint(x: 1, y: 15), CGPoint(x: 9, y: 15))
        let B = (CGPoint(x: 9, y: 15), CGPoint(x: 9, y: 8))
        let C = (CGPoint(x: 9, y: 8),  CGPoint(x: 9, y: 1))
        let D = (CGPoint(x: 1, y: 1),  CGPoint(x: 9, y: 1))
        let E = (CGPoint(x: 1, y: 8),  CGPoint(x: 1, y: 1))
        let F = (CGPoint(x: 1, y: 15), CGPoint(x: 1, y: 8))
        let G = (CGPoint(x: 1, y: 8),  CGPoint(x: 9, y: 8))
        let segments = [A, B, C, D, E, F, G]
        let map: [Int: [Int]] = [
            0:[0,1,2,3,4,5], 1:[1,2], 2:[0,1,6,4,3], 3:[0,1,6,2,3],
            4:[5,6,1,2], 5:[0,5,6,2,3], 6:[0,5,6,2,3,4],
            7:[0,1,2], 8:[0,1,2,3,4,5,6], 9:[0,1,2,3,5,6]
        ]
        let path = CGMutablePath()
        for idx in map[digit] ?? [] {
            let (p1, p2) = segments[idx]
            path.move(to: CGPoint(x: p1.x * scale, y: p1.y * scale))
            path.addLine(to: CGPoint(x: p2.x * scale, y: p2.y * scale))
        }
        let node = SKShapeNode(path: path)
        node.strokeColor = .white
        node.lineWidth = 2
        node.glowWidth = 3
        node.zPosition = 60
        return node
    }
    
    /// Creates a score display from a number using seven-segment digits
    /// - Parameters:
    ///   - score: The score value to render
    ///   - scale: Scale factor for the digits
    ///   - spacing: Spacing between digits
    /// - Returns: A node containing all the digits
    static func makeScoreNode(score: Int, scale: CGFloat = 1.2, spacing: CGFloat = 12) -> SKNode {
        let container = SKNode()
        let digits = Array(String(score))
        let digitWidth: CGFloat = 10  // Width of a single digit (9 + 1 margin)
        var x: CGFloat = 0
        for ch in digits {
            if let d = Int(String(ch)) {
                let dn = createDigitNode(d, scale: scale)
                dn.position = CGPoint(x: x, y: 0)
                container.addChild(dn)
                x += (digitWidth + spacing) * scale  // Use digit width + spacing
            }
        }
        if digits.isEmpty { 
            let dn = createDigitNode(0, scale: scale)
            dn.position = .zero
            container.addChild(dn)
        }
        return container
    }
    
    // MARK: - Infinity Symbol
    
    /// Creates a vector infinity (∞) symbol node
    /// - Parameter scale: Scale factor for the symbol
    /// - Returns: A node containing the infinity symbol
    static func makeVectorInfinityNode(scale: CGFloat) -> SKNode {
        // Lemniscate drawn in a 20×10 native space — much larger than the 8×12 glyph cell
        // so it stays legible at small scales. Crosses at centre (10,5); right lobe clockwise,
        // left lobe counter-clockwise so the path genuinely intersects at the midpoint.
        let cx: CGFloat = 10, cy: CGFloat = 5
        let hw: CGFloat = 8.0, hh: CGFloat = 3.5
        let path = CGMutablePath()
        path.move(to: CGPoint(x: cx, y: cy))
        path.addCurve(to: CGPoint(x: cx + hw, y: cy),
                      control1: CGPoint(x: cx + hw * 0.45, y: cy + hh),
                      control2: CGPoint(x: cx + hw,        y: cy + hh))
        path.addCurve(to: CGPoint(x: cx, y: cy),
                      control1: CGPoint(x: cx + hw,        y: cy - hh),
                      control2: CGPoint(x: cx + hw * 0.45, y: cy - hh))
        path.addCurve(to: CGPoint(x: cx - hw, y: cy),
                      control1: CGPoint(x: cx - hw * 0.45, y: cy - hh),
                      control2: CGPoint(x: cx - hw,        y: cy - hh))
        path.addCurve(to: CGPoint(x: cx, y: cy),
                      control1: CGPoint(x: cx - hw,        y: cy + hh),
                      control2: CGPoint(x: cx - hw * 0.45, y: cy + hh))
        let node = SKShapeNode(path: path)
        node.strokeColor = .white
        node.fillColor = .clear
        node.lineWidth = 1.0
        node.glowWidth = 4.0
        node.alpha = 1.0
        node.lineCap = .round
        node.setScale(scale)
        return node
    }
    
    // MARK: - Vector Word Rendering
    
    /// Calculates the width of a rendered vector word
    /// - Parameters:
    ///   - text: The text to measure
    ///   - scale: Scale factor
    ///   - spacing: Character spacing
    /// - Returns: The total width in points
    static func vectorWordWidth(_ text: String, scale: CGFloat, spacing: CGFloat) -> CGFloat {
        let n = CGFloat(text.count)
        guard n > 0 else { return 0 }
        return ((n - 1) * (8 + spacing) + 8) * scale
    }
    
    /// Creates a vector-style word node using line-segment glyphs
    /// - Parameters:
    ///   - text: The text to render
    ///   - scale: Scale factor
    ///   - spacing: Character spacing
    ///   - bright: Whether to use bright/glowing style (true) or dim retro style (false)
    /// - Returns: A node containing the rendered text
    static func makeVectorWordNode(_ text: String, scale: CGFloat, spacing: CGFloat, bright: Bool = false) -> SKNode {
        let container = SKNode()
        var cursorX: CGFloat = 0
        let sw: CGFloat = bright ? 1.0 : 0.5
        let segAlpha: CGFloat = bright ? 1.0 : 0.4
        let dotAlpha: CGFloat = bright ? 1.0 : 0.7
        let segGlow: CGFloat  = bright ? 4.0 : 0.0
        let glyphs: [Character: [(CGFloat,CGFloat,CGFloat,CGFloat)]] = [
            "0": [(0,2,0,10),(0,10,2,12),(2,12,6,12),(6,12,8,10),(8,10,8,2),(8,2,6,0),(6,0,2,0),(2,0,0,2)],
            "1": [(2,10,4,12),(4,12,4,0),(0,0,8,0)],
            "2": [(0,10,2,12),(2,12,6,12),(6,12,8,10),(8,10,8,7),(8,7,0,0),(0,0,8,0)],
            "3": [(0,10,2,12),(2,12,6,12),(6,12,8,10),(8,10,8,7),(8,7,6,6),(2,6,6,6),(6,6,8,5),(8,5,8,2),(8,2,6,0),(6,0,2,0),(2,0,0,2)],
            "4": [(0,12,0,6),(0,6,8,6),(6,12,6,0)],
            "5": [(8,12,0,12),(0,12,0,7),(0,7,6,7),(6,7,8,5),(8,5,8,2),(8,2,6,0),(6,0,0,0)],
            "6": [(8,10,6,12),(6,12,2,12),(2,12,0,10),(0,10,0,2),(0,2,2,0),(2,0,6,0),(6,0,8,2),(8,2,8,5),(8,5,0,5)],
            "7": [(0,12,8,12),(8,12,4,0)],
            "8": [(2,6,0,8),(0,8,0,10),(0,10,2,12),(2,12,6,12),(6,12,8,10),(8,10,8,8),(8,8,6,6),(6,6,2,6),(2,6,0,4),(0,4,0,2),(0,2,2,0),(2,0,6,0),(6,0,8,2),(8,2,8,4),(8,4,6,6)],
            "9": [(8,2,6,0),(6,0,2,0),(2,0,0,2),(0,2,0,5),(0,5,8,5),(8,5,8,10),(8,10,6,12),(6,12,2,12),(2,12,0,10)],
            "A": [(0,0,2,6),(2,6,4,12),(8,0,6,6),(6,6,4,12),(2,6,6,6)],
            "B": [(0,0,0,12),(0,12,5,12),(5,12,7,10),(7,10,7,7),(7,7,5,6),(5,6,0,6),
                  (0,6,5,6),(5,6,7,4),(7,4,7,1),(7,1,5,0),(5,0,0,0)],
            "C": [(7,11,6,12),(6,12,2,12),(2,12,0,10),(0,10,0,2),(0,2,2,0),(2,0,6,0),(6,0,7,1)],
            "D": [(0,0,0,12),(0,12,5,12),(5,12,8,9),(8,9,8,3),(8,3,5,0),(5,0,0,0)],
            "E": [(0,12,0,6),(0,6,0,0),(0,12,8,12),(0,6,6,6),(0,0,8,0)],
            "F": [(0,12,0,6),(0,6,0,0),(0,12,8,12),(0,6,6,6)],
            "G": [(7,11,6,12),(6,12,2,12),(2,12,0,10),(0,10,0,2),(0,2,2,0),(2,0,6,0),
                  (6,0,8,2),(8,2,8,6),(8,6,4,6)],
            "H": [(0,0,0,6),(0,6,0,12),(8,0,8,6),(8,6,8,12),(0,6,8,6)],
            "I": [(2,12,4,12),(4,12,6,12),(4,12,4,0),(2,0,4,0),(4,0,6,0)],
            "J": [(2,12,6,12),(6,12,8,12),(6,12,6,2),(6,2,4,0),(4,0,0,0)],
            "K": [(0,0,0,6),(0,6,0,12),(0,6,8,12),(0,6,8,0)],
            "L": [(0,12,0,0),(0,0,8,0)],
            "M": [(0,0,0,12),(0,12,4,6),(4,6,8,12),(8,12,8,0)],
            "N": [(0,0,0,12),(0,12,8,0),(8,0,8,12)],
            "O": [(2,12,6,12),(6,12,8,10),(8,10,8,2),(8,2,6,0),(6,0,2,0),(2,0,0,2),(0,2,0,10),(0,10,2,12)],
            "P": [(0,0,0,12),(0,12,6,12),(6,12,8,10),(8,10,8,7),(8,7,6,6),(6,6,0,6)],
            "Q": [(2,12,6,12),(6,12,8,10),(8,10,8,2),(8,2,6,0),(6,0,2,0),(2,0,0,2),
                  (0,2,0,10),(0,10,2,12),(5,3,9,0)],
            "R": [(0,0,0,12),(0,12,6,12),(6,12,8,10),(8,10,8,7),(8,7,6,6),(6,6,0,6),(4,6,8,0)],
            "S": [(7,11,6,12),(6,12,2,12),(2,12,0,10),(0,10,0,7),(0,7,2,6),(2,6,6,6),
                  (6,6,8,4),(8,4,8,1),(8,1,6,0),(6,0,2,0),(2,0,0,2)],
            "T": [(0,12,4,12),(4,12,8,12),(4,12,4,0)],
            "U": [(0,12,0,2),(0,2,2,0),(2,0,6,0),(6,0,8,2),(8,2,8,12)],
            "V": [(0,12,4,0),(4,0,8,12)],
            "W": [(0,12,0,0),(0,0,4,6),(4,6,8,0),(8,0,8,12)],
            "X": [(0,12,4,6),(4,6,8,0),(0,0,4,6),(4,6,8,12)],
            "Y": [(0,12,4,6),(8,12,4,6),(4,6,4,0)],
            "Z": [(0,12,8,12),(8,12,0,0),(0,0,8,0)],
            " ": [],
        ]
        for ch in text.uppercased() {
            let segs = glyphs[ch] ?? []
            let holder = SKNode(); holder.position = CGPoint(x: cursorX, y: 0)
            for (x1,y1,x2,y2) in segs {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x1, y: y1)); p.addLine(to: CGPoint(x: x2, y: y2))
                let s = SKShapeNode(path: p)
                s.strokeColor = .white; s.lineWidth = sw; s.glowWidth = segGlow
                s.lineCap = .butt; s.alpha = segAlpha; holder.addChild(s)
            }
            var tally: [String: (CGFloat, CGFloat, Int)] = [:]
            for (x1,y1,x2,y2) in segs {
                for (px,py) in [(x1,y1),(x2,y2)] {
                    let key = "\(px),\(py)"
                    tally[key] = (px, py, (tally[key]?.2 ?? 0) + 1)
                }
            }
            let hs = sw * 0.5
            for (_, entry) in tally where entry.2 >= 2 {
                let rect = CGRect(x: entry.0 - hs, y: entry.1 - hs, width: sw, height: sw)
                let dot = SKShapeNode(rect: rect)
                dot.fillColor = .white; dot.strokeColor = .clear
                dot.glowWidth = sw * 1.5; dot.alpha = dotAlpha; dot.zPosition = 1
                holder.addChild(dot)
            }
            container.addChild(holder); cursorX += (8 + spacing)
        }
        container.setScale(scale)
        return container
    }
}
