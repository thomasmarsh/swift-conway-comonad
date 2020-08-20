//
//  main.swift
//  ConwayComonad
//
//  Created by Thomas Marsh on 8/18/20.
//

extension Array where Element == (Int, Int) {
    func at(_ x: Int, _ y: Int) -> Set<Coord> {
        self.reduce(into: Set.init()) {
            $0.insert(Coord($1.0 + x, $1.1 + y))
        }
    }
}


let glider: [(Int,Int)] = [
    (1, 0), (2, 1), (0, 2), (1, 2), (2, 2),
]

let blinker: [(Int,Int)] = [
    (0, 0), (1, 0), (2, 0)
]

let beacon: [(Int,Int)] = [
    (0, 0), (1, 0), (0, 1), (3, 2), (2, 3), (3, 3)
]

// ----------------------------------------------------

//let initialState =
//    glider.at(0, 0)
//        .union(beacon.at(15, 5))
//        .union(blinker.at(16, 4))

var initialState: Set<Coord> = Set()
for y in 0..<BOUND.y {
    for x in 0..<BOUND.x {
        if Bool.random() {
            initialState.insert(Coord(x,y))
        }
    }
}

import Foundation

struct Timer {
    var startTime: CFTimeInterval

    init() {
        self.startTime = CFAbsoluteTimeGetCurrent()
    }

    mutating func elapsed() -> Double {
        let current = CFAbsoluteTimeGetCurrent()
        let elapsed = current - self.startTime
//        self.startTime = current
        return Double(elapsed)
    }
}

print("\u{001B}[2J")
var i = 0
var timer = Timer()
var current = makeGrid(initialState)
render(current)
while true {
    current = step(current)
    render(current)
    print("Rate: \(Double(i)/timer.elapsed())")
    i += 1
}
