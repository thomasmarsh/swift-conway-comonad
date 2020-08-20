//
//  Prelude.swift
//  ConwayComonad
//
//  Created by Thomas Marsh on 8/18/20.
//

import Foundation

func mod(_ a: Int, _ n: Int) -> Int {
    precondition(n > 0, "modulus must be positive")
    let r = a % n
    return r >= 0 ? r : r + n
}

extension Array {
    func chunks(of size: Int) -> [[Element]] {
        precondition(size > 0)
        return stride(from: 0, to: count, by: size)
            .map { Array(self[$0 ..< Swift.min($0 + size, count)]) }
    }
}

func memoize<A: Hashable, B>(_ f: @escaping (A) -> B) -> (A) -> B {
    var cache: [A: B] = [:]
    return { a in
        guard let result = cache[a] else {
            let x = f(a)
            cache[a] = x
            return x
        }
        return result
    }
}

extension Bool {
    var intValue: Int { self ? 1 : 0 }
}
