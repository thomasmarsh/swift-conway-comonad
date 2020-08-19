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
    let left: A
    let right: A
}

extension Pair: Equatable where A: Equatable {}

extension Pair: Representable {
    static func tabulate(_ f: (Bool) -> A) -> Pair {
        Pair(left: f(true), right: f(false))
    }

    func index(_ r: Bool) -> A {
        r ? self.left : self.right
    }
}

//let p = Pair(left: "hot", right: "cold")
//p == Pair.tabulate(p.index)

// ----------------------------------------------------------------

// TODO: curry in this constant
typealias Bound = (x: Int, y: Int)

let BOUND: Bound = (500, 300)

struct BoundedGrid<A>: Representable {
    let data: [A]

    func index(_ c: Coord) -> A {
        let x = mod(c.x, BOUND.x)
        let y = mod(c.y, BOUND.y)
        return data[y*BOUND.x+x]
    }

    static func tabulate(
        _ desc: (Coord) -> A
    ) -> BoundedGrid {
        var data: [A] = []
        for y in 0..<BOUND.y {
            for x in 0..<BOUND.x {
                data.append(desc(Coord(x, y)))
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

    func peek(_ c: Coord) -> A {
        self.grid.index(c)
    }

    // w a -> s -> w a
    func seek(_ c: Coord) -> Self { duplicate.peek(c) }

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
