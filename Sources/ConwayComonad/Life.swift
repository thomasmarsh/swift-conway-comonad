//
//  Life.swift
//  ConwayComonad
//
//  Created by Thomas Marsh on 8/18/20.
//

// Needed since tuples are not hashable. Note the BOUND wrapping.
struct Coord: Hashable {
    let x: Int
    let y: Int

    init(_ x: Int, _ y: Int) {
        self.x = mod(x, BOUND.x)
        self.y = mod(y, BOUND.y)
    }
}

func +(
    lhs: Coord,
    rhs: Coord
) -> Coord {
    Coord(lhs.x + rhs.x, lhs.y + rhs.y)
}

// -------------------------------------------------------------------------------

// ATTEMPT 1:
//
// The Store<S,A> comonad is the categorical dual of the State<S,A> monad.
// Store has a focus on the current position and a mapping for any position to
// a value.
//
// Using Store<Coord,Bool> we must compute each frame by recomputing every
// preceding frame.

//  typealias Grid = Store<Coord,Bool>
//
//  func makeGrid(_ state: Set<Coord>) -> Grid {
//      Grid(peek: state.contains, pos: Coord(0,0))
//  }

// -------------------------------------------------------------------------------

// ATTEMPT 2:
//
// We can try to memoize at each step. This gives us a speedup, but we
// have now way to recognize that our memory can't be collected. So, though
// we've fixed the recompute problem, we now have an unbounded growth problem.

//  typealias Grid = MemoStore<Coord,Bool>
//
//  func makeGrid(_ state: Set<Coord>) -> Grid {
//      Grid(peek: state.contains, pos: Coord(0,0))
//  }

// -------------------------------------------------------------------------------

// ATTEMPT 3:
//
// We can use a RepresentableStore to get memoization for "free".  This solves
// both the recompute issue as well as the memory growth issue. Our representation
// and our bounds now becomes our performance bottleneck.

typealias Grid = FocusedBoundedGrid<Bool> // i.e., RepresentableStore<Grid<_>, Coord, Bool>

func makeGrid(_ state: Set<Coord>) -> Grid {
    Grid(
        grid: BoundedGrid<Bool>.tabulate(state.contains),
        pos: Coord(0,0))
}

let adjacent = [
    (-1,-1), (0, -1), (1, -1), (-1, 0),
    (1, 0), (-1, 1), (0, 1), (1, 1)
].map(Coord.init)

func neighbourCoords(_ c: Coord) -> [Coord] {
    adjacent.map { $0 + c }
}

func conway(grid: Grid) -> Bool {
    // Comonads allow us to extract our current focus
    let alive = grid.extract

    // The Store comonad allows us to look at other positions relative to
    // the current position via `experiment :: (key -> [key]) -> [a]`.
    let liveCount = grid
        .experiment(neighbourCoords)
        .reduce(0) { $0 + $1.intValue }

    if      alive  && liveCount < 2  || liveCount > 3 { return false }
    else if alive  && liveCount == 2 || liveCount == 3 { return true }
    else if !alive && liveCount == 3 { return true }
    return alive
}

func step(_ grid: Grid) -> Grid {
    // Comonadic extend is the dual of monadic bind. This takes a function
    // `f a -> b` and applies it to `f a` to produce an `f b`. In this case,
    // we want: Grid -> (Grid -> Bool) -> Grid, remembering that each grid
    // is focused on some point.
    grid.extend(conway)
}

func render(_ grid: Grid) {
    var xs: [Coord] = []
    for y in 0..<BOUND.y {
        for x in 0..<BOUND.x {
            xs.append(Coord(x, y))
        }
    }

    let str = grid.experiment { _ in xs }
        .map { $0 ? "#" : " " }
        .chunks(of: BOUND.x)
        .map { $0.joined() }
        .joined(separator: "\n")

    print("\u{001B}[;H" + str)
}
