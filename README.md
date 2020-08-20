# swift-conway-comonad
Conway's game of life in Swift using Comonads and Representable Functors.

This is based primarily on Chris Penner's
[article](https://chrispenner.ca/posts/conways-game-of-life), in which he
implements a similar solution in Haskell. There were a few things that were
unclear to me, so I tried to recreate his solution from scratch.

I also looked at the Haskell source for [RepresentableStore](https://hackage.haskell.org/package/adjunctions-4.4/docs/Control-Comonad-Representable-Store.html)
from Edward Kmett's adjunctions package. After squinting at it enough, it
started to become useful.

I like to build these things in Swift because the extra syntax, ceremony, and
even type-system limitations often elucidate the shape of the problem. Haskell
is often a little too subtle and magical for me to see what's happening at
first.

These notes here are to help me remember what I did. Maybe they are useful to
you too.

Quick start:

```sh
$ swift run --configuration release
```

## Comonadic Life
To set the stage, we want to capture the essence of the Game of Life in
simple code. There are two parts to the definition of the game. The first step
is to define neighboring positions, which are orthogonally and diagonally
adjacent locations to a point on some grid (also known as the [Moore
neighbourhood](https://www.conwaylife.com/wiki/Moore_neighbourhood)).


```swift
let adjacent = [
    (-1,-1), (0, -1), (1, -1), (-1, 0),
    (1, 0), (-1, 1), (0, 1), (1, 1)
].map(Coord.init)

func neighbourCoords(_ c: Coord) -> [Coord] {
    adjacent.map { $0 + c }
}
```

Here, `Coord` is a struct equivalent to a 2-tuple `(Int, Int)`.

We would like to describe a step function for an individual point. Something
like following where some code has been elided and replaced with `???`:

```swift
// The `Grid` we take as input has the notion of the current position under
// consideration, i.e., a focus.
func conway(grid: Grid) -> Bool {
    let alive = grid.??? // A boolean indicating if the current point is alive or dead
    let liveCount = grid.??? // A count of the neighbors that are alive

    if      alive  && liveCount < 2  || liveCount > 3 { return false }
    else if alive  && liveCount == 2 || liveCount == 3 { return true }
    else if !alive && liveCount == 3 { return true }
    return alive
}
```

This is the type of problem that comonads are ideally suited for representing.
If `Grid` is a `Store` comonad then our implementation is now:

```swift
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
```

Note that I've taken some liberties and made `experiment` operate over lists
rather than just any arbitrary type constructor (due to lack of higher kinded
types).

With the above complete, our step function is just the `extend` method of a
comonad.  Comonadic extend is the dual of monadic bind. This takes a function
`w a -> b` and applies it to `w a` to produce an `w b`. In this case,
we want: `Grid -> (Grid -> Bool) -> Grid` (remembering that each grid
is focused on some point.)

```swift
func step(_ grid: Grid) -> Grid {
    grid.extend(conway)
}
```


## Store
The `Store<S,A>` comonad is the first thing you reach for.  The `Store<S,A>`
comonad is the categorical dual of the `State<S,A>` monad.  Store has a focus on
the current position and a mapping for any position to a value.  The
implementation is fairly straightforward.

```swift
struct Store<S, A> {
    let peek: (S) -> A
    let pos: S

    func seek(_ s: S) -> Store { duplicate.peek(s) }

    func experiment(_ f: (S) -> [S]) -> [A] {
        f(pos).map(peek)
    }
}

// Comonad
extension Store {
    var extract: A { peek(pos) }

    func extend<B>(
        _ f: @escaping (Store<S,A>) -> B
    ) -> Store<S,B> {
        Store<S,B>(
            peek: { f(Store(peek: self.peek, pos: $0)) },
            pos: self.pos)
    }

    var duplicate: Store<S, Store<S,A>> {
        extend { $0 }
    }
}
```

The most complicated point of understanding here (aside from the level of
abstraction) is the intuition around comonadic `duplicate` (i.e., `cojoin`)
which is needed for the `seek` operation.

`extend` also has a complicated looking implementation, and its lazy
computation will cause us some headaches.

For the remaining examples, we will assume an `initialState` of type
`Set<Coord>`. Using `Store<S,A>` we get the following binding. `makeGrid` is
just a helper to show how to construct a `Grid` from such an initial state.

```swift
typealias Grid = Store<Coord,Bool>

func makeGrid(_ state: Set<Coord>) -> Grid {
    Grid(peek: state.contains, pos: Coord(0,0))
}
```

What we find (and as everyone notices right away) is that to compute any next
frame, we must first recompute every preceding frame. This is a consequence of
that lazy computation through `extend` which builds a large web of chained
functions, upon which we add an additional layer each time step.

## Memoized Store
I found several solutions that add in some ad hoc memoization, such as in the
article [Life Is A Comonad](https://eli-jordan.github.io/2018/02/16/life-is-a-comonad/)
by Eli Jordan. (Note, the linked source code in that article also shows an
alternate RepresentableStore version.) These rely on some garbage collection or
smartness around weak references to avoid memory leaks.

Adding memoization to our `Store<S,A>` is a matter of providing a `memoize`
function:

```swift
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
```

With this we can provide a new `MemoStore<S,A>`. It is identical to `Store<S,A>`
in every way except that it's `extend` method uses this memoization function.

```swift
    func extend<B>(
        _ f: @escaping (MemoStore<S,A>) -> B
    ) -> MemoStore<S,B> {
        MemoStore<S,B>(
            peek: memoize {
                f(MemoStore(
                    peek: self.peek,
                    pos: $0))
            },
            pos: self.pos)
    }
```

This will leak like crazy. I didn't bother trying to address that because there
is a better way. (Though if you have an easy fix, please send it my way!)

To use it, we switch out our `Grid` and `makeGrid` implementation.

```swift
typealias Grid = MemoStore<Coord,Bool>

func makeGrid(_ state: Set<Coord>) -> Grid {
    Grid(peek: state.contains, pos: Coord(0,0))
}
```

We can confirm this runs much faster, but with unbounded memory growth.


## Representable
I had a hard time getting my head around representable functors. Once I had them
understood, it was then difficult for me to see what a `RepresentableStore`
should be.

To help keep the types straight, I started with a protocol.

```swift
protocol Representable {
    associatedtype Rep
    associatedtype Arg

    static func tabulate(_ t: (Rep) -> Arg) -> Self

    func index(_ r: Rep) -> Arg
}
```

A simple example of a representable functor is a `Pair<A>` that contains two
values:

```swift
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
```

It's easy to convince yourself that a function `Bool -> A` can be used to create
an instance of `Pair<A>`. That's all `tabulate` does. Similarly, given a
`Pair<A>`, and a `Bool`, you can see that you can use the `Bool` to index into
the `Pair` type and pluck out a value.

As literature states, "a Functor f is representable if tabulate and index
witness an isomorphism to (->) x". We can demonstrate that:

```swift
extension Pair: Equatable where A: Equatable {}

let p = Pair(fst: "hot", snd: "cold")
p == Pair.tabulate(p.index)
```

## RepresentableStore

In the Game of Life, our representable functor is a grid. It has to be bounded
in dimension or else we won't know how to implement `tabulate` in finite time.
(Note the global constant `BOUND` in some of the code.)

`BoundedGrid<A>` is essentially a two dimensional array like `[[A]]`. Note it
could also be a dictionary `[Coord: A]` (simplifiable to `Set<Coord>` for the
case of `BoundedGrid<Bool>`), a quadtree, or any number of alternatives.
I chose to use a one dimensional array and some indexing math. The important
part here is the signatures of `index` and `tabulate`.

```swift
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
```

`index` simply indexes into the grid. `tabulate` constructs a new grid using a
function `Coord -> A`. This latter part might seem inefficient, but note how it
is used. `tabulate` is called by `duplicate`, which is called by `extend`. We
invoke `extend` with the argument `conway` (our step logic). So we are just
composing the `conway` function over each re-focused grid.  There is some
wastage here that is worth discussing later.

Now that we have a representable functor in the form of `BoundedGrid<A>` we can
construct a `RepresentableStore<F<_>, S,A>` that uses it. Without higher kinded
types, we can't actually define this type generically. We'll create a concrete
instance for the types we care about.

```swift
// a.k.a., RepresentableStore<BoundedGrid<_>, Coord, A>
struct FocusedBoundedGrid<A> {
    let grid: BoundedGrid<A>
    let pos: Coord

    func peek(_ c: Coord) -> A {
        self.grid.index(c)
    }

    func seek(_ c: Coord) -> Self { duplicate.peek(c) }

    func experiment(_ f: (Coord) -> [Coord]) -> [A] {
        f(pos).map(peek)
    }
}
```

Notice that `peek` is no longer user provided. It is now is implemented via the 
underlying representable functor's `index` method.

`FocusedBoundedGrid` has a straightforward functor instance which we will need.

```swift
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
```

Finally we can build our comonad instance.

```swift
extension FocusedBoundedGrid {
    var extract: A { peek(pos) }

    func extend<B>(
        _ f: @escaping (FocusedBoundedGrid<A>) -> B
    ) -> FocusedBoundedGrid<B> {
        self.duplicate.map(f)
    }

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
```

Of primary interest here is how `duplicate` works. It uses the underlying
representable functor's `tabulate` method to build out the grid with all
possible different focus points. This is also where we construct a lot of
redundant `BoundedGrid` instances. (Using better copy-on-write patterns or
persistent data structures might help here.) This is also how we get
"memoization for free". By invoking `tabulate`, we are constructing a new
`BoundedGrid`, thereby avoiding all recompute we saw with the original `Store`.

We can now switch out our implementation.

```swift
typealias Grid = FocusedBoundedGrid<Bool>

func makeGrid(_ state: Set<Coord>) -> Grid {
    Grid(
        grid: BoundedGrid.tabulate(state.contains),
        pos: Coord(0,0))
}
```

This version has great performance and flat memory consumption. For all of the
pointless data copying it does, it's surprisingly fast. That's where this
exploration ends. I'm left with a few questions for another day.

*Questions:*
- Can we get some easy performance wins with lazy collections / iterators?
- Can we get some easy wins with some persistent data structures?
- Can I use the Reader monad to read in the bounds
- Can I use the State or IO monad to free myself from the information constraints of
  tabulate?
- This problem is trivially made data parallel. What would that look like?
