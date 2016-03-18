//
//  Punycode.swift
//  BrowserPrototype
//
//  Created by Alexander Larionov on 17.12.15.
//  Copyright © 2015 Alexander Larionov. All rights reserved.
//

import Foundation

public class Punycode {
    //MARK: public static
    // RFC 3492 implementation
    public static let official = Punycode(
        delimiter: "-",
        encodeTable: "abcdefghijklmnopqrstuvwxyz0123456789"
    )
    // used for Swift name mangling - presumably to avoid digit interference
    public static let swift = Punycode(
        delimiter: "_",
        encodeTable: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJ"
    )
    //MARK: variables
    private let prefix = "xn--"
    private let base = 36
    private let tMin = 1
    private let tMax = 26
    private let skew = 38
    private let damp = 700
    private let initialBias = 72
    private let initialN = 0x80
    private let delimiter : Character
    private let encodeTable : [Character]
    private let decodeTable : [Character : Int]
    //MARK: initializers
    public convenience init(delimiter: Character, encodeTable: String) {
        self.init(delimiter: delimiter, encodeTable: [Character](encodeTable.characters))
    }
    public required init(delimiter: Character, encodeTable: [Character]) {
        self.delimiter = delimiter
        self.encodeTable = encodeTable
        var decodeTable = [Character : Int]()
        encodeTable.enumerate().forEach { ( kvp: (Int, Character)) -> () in
            decodeTable[kvp.1] = kvp.0
        }
        self.decodeTable = decodeTable
    }
    //MARK: encode
    public func encode(unicode: String) -> String {
        var retval = ""
        var d : Int = 0
        var extendedChars = [Int]()
        for c in unicode.unicodeScalars {
            let ci = Int(c.value)
            if ci < initialN {
                ++d
                retval.append(c)
            } else {
                extendedChars.append(ci)
            }
        }
        if extendedChars.count == 0 {
            return retval
        }
        if d > 0 {
            retval.append(delimiter)
        }
        
        // extendedChars.sortInPlace()
        var bias = initialBias
        var delta = 0
        var n = initialN
        var h : Int = 0
        let b : Int
        
        if d > 0 {
            h = retval.unicodeScalars.count - 1
            b = retval.unicodeScalars.count - 1
            
        } else {
            h = retval.unicodeScalars.count
            b = retval.unicodeScalars.count
        }
            
        
        for _ = 0; h < unicode.unicodeScalars.count; {
            var char = Int(0x7fffffff)
            for c in unicode.unicodeScalars {
                let ci = Int(c.value)
                if char > ci && ci >= n {
                    char = ci
                }
                
            }
            delta = delta + (char - n) * (h + 1)
            if delta < 0 {
                print("error: invalid char:")
                retval = ""
                return retval
            }
            n = char
            for c in unicode.unicodeScalars {
                let ci = Int(c.value)
                if ci < n || ci < initialN {
                    delta++
                    continue
                }
                if ci > n {
                    continue
                }
                var q = delta
                for var k = self.base; ; k += base {
                    let t = max(min(k - bias, self.tMax), self.tMin)
                    if q < t {
                        break
                    }
                    let code = t + ((q - t) % (self.base - t))
                    retval.append(self.encodeTable[code])
                    q = (q - t) / (self.base - t)
                }
                retval.append(self.encodeTable[q])
                
                bias = self.adapt(delta, h + 1, h == b)
                delta = 0
                h++
                
            }
            delta++
            n++
        }
        return retval
    }
    private func adapt(var delta: Int, _ numPoints: Int, _ firstTime: Bool) -> Int {
        delta = delta / (firstTime ? self.damp : 2)
        delta += delta / numPoints
        var k = 0
        while (delta > ((self.base - self.tMin) * self.tMax) / 2) {
            delta = delta / (self.base - self.tMin)
            k = k + self.base
        }
        k += ((self.base - self.tMin + 1) * delta) / (delta + self.skew)
        return k
    }
    //MARK: decode
    public func decode(punycode: String) -> String {
        var input = [Character](punycode.characters)
        var n = self.initialN
        var i = 0
        var bias = self.initialBias
        var output = [Character]()
        var pos = 0
        if let ipos = input.indexOf(self.delimiter) {
            pos = ipos
            output.appendContentsOf(input[0 ..< pos++])
        }
        var outputLength = output.count
        let inputLength = input.count
        while pos < inputLength {
            let oldi = i
            var w = 1
            for var k = self.base;; k += self.base {
                let digit = self.decodeTable[input[pos++]]!
                i = i + (digit * w)
                let t = max(min(k - bias, self.tMax), self.tMin)
                if (digit < t) {
                    break
                }
                w = w * (self.base - t)
            }
            bias = self.adapt(i - oldi, ++outputLength, (oldi == 0))
            n = n + i / outputLength
            i = i % outputLength
            output.insert(Character(UnicodeScalar(n)), atIndex: i)
            i++
        }
        return String(output)
    }
    
    func ascii (s:String) -> Bool{
        for c in s.unicodeScalars{
            let ci = Int(c.value)
            if ci >= initialN {
                return false
            }
            
            
        }
        return true
    }
    
    public func toAscii (s:String) -> String{
        if ascii(s) {
            return s
        }
        var labels = s.componentsSeparatedByString(".")
        var i : Int = 0
        for part in labels{
            if ascii(part) != true{
                let a = encode(part)
                labels[i] = prefix+a
                
            }
            ++i
        }
        let resultString = labels.joinWithSeparator(".")
        
        return resultString
    }
    
    
    
}
