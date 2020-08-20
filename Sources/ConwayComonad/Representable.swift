//
//  Representable.swift
//  ConwayComonad
//
//  Created by Thomas Marsh on 8/18/20.
//

// A Functor f is representable if tabulate and index witness
// an isomorphism to (->) x.
protocol Representable {
    associatedtype Rep
    associatedtype Arg

    // (Key f -> a) -> f a
    static func tabulate(_ t: (Rep) -> Arg) -> Self

    // f a -> (Key f -> a)
    func index(_ r: Rep) -> Arg
}


// ----------------------------------------------------------------

// EXAMPLE: Pair

struct Pair<A> {
    let fst: A
    let snd: A
}

extension Pair: Representable {
    static func tabulate(_ f: (Bool) -> A) -> Pair {
        Pair(fst: f(true), snd: f(false))
    }

    func index(_ r: Bool) -> A {
        r ? self.fst : self.snd
    }
}

extension Pair: Equatable where A: Equatable {}

//let p = Pair(fst: "hot", snd: "cold")
//p == Pair.tabulate(p.index)

// ----------------------------------------------------------------

typealias Bound = (x: Int, y: Int)

// NOTE: global constant
let BOUND: Bound = (400, 150)
let COUNT: Int = BOUND.x * BOUND.y

struct BoundedGrid<A>: Representable {
    let data: [A]

    init(data: [A]) {
        self.data = data
    }

    func index(_ c: Coord) -> A {
        return data[c.y*BOUND.x+c.x]
    }

    static func tabulate(
        _ desc: (Coord) -> A
    ) -> BoundedGrid {
        var data: [A] = []
        data.reserveCapacity(COUNT)
        for y in 0..<BOUND.y {
            for x in 0..<BOUND.x {
                data.append(desc(Coord(x,y)))
            }
        }
        return BoundedGrid(data: data)
    }
}

// Functor
extension BoundedGrid {
    func map<B>(
        _ f: @escaping (A) -> B
    ) -> BoundedGrid<B> {
        BoundedGrid<B>(data: self.data.map(f))
    }
}

// a.k.a., RepresentableStore<BoundedGrid<_>, Coord, A>. We can't represent
// this type (easily) in a generic manner without higher kinded type support.
struct FocusedBoundedGrid<A> {
    let grid: BoundedGrid<A>
    let pos: Coord

    init(grid: BoundedGrid<A>, pos: Coord) {
        self.grid = grid
        self.pos = pos
    }

    func peek(_ c: Coord) -> A {
        self.grid.index(c)
    }

    // w a -> s -> w a
    func seek(_ c: Coord) -> FocusedBoundedGrid<A> { duplicate.peek(c) }

    // w a -> (s -> f s) -> f a
    func experiment(_ f: (Coord) -> [Coord]) -> [A] {
        f(pos).map(peek)
    }
}

// Functor
extension FocusedBoundedGrid {
    func map<B>(
        _ f: @escaping (A) -> B
    ) -> FocusedBoundedGrid<B> {
        FocusedBoundedGrid<B>(
            grid: self.grid.map(f),
            pos: self.pos
        )
    }
}

// Comonad
extension FocusedBoundedGrid {
    // w a -> a
    var extract: A { peek(pos) }

    // w a -> (w a -> b) -> w b
    func extend<B>(
        _ f: @escaping (FocusedBoundedGrid<A>) -> B
    ) -> FocusedBoundedGrid<B> {
        self.duplicate.map(f)
    }

    // w a -> w (w a)
    var duplicate: FocusedBoundedGrid<FocusedBoundedGrid<A>> {
        FocusedBoundedGrid<FocusedBoundedGrid<A>>(
            grid: BoundedGrid.tabulate {
                FocusedBoundedGrid<A>(
                    grid: self.grid,
                    pos: $0)
            },
            pos: self.pos)
    }
}
