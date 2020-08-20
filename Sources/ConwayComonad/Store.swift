//
//  Store.swift
//  ConwayComonad
//
//  Created by Thomas Marsh on 8/18/20.
//

struct Store<S, A> {
    let peek: (S) -> A
    let pos: S

    // w a -> s -> w a
    func seek(_ s: S) -> Store { duplicate.peek(s) }

    // w a -> (s -> f s) -> f a
    func experiment(_ f: (S) -> [S]) -> [A] {
        f(pos).map(peek)
    }
}

// Comonad
extension Store {
    // w a -> a
    var extract: A { peek(pos) }

    // w a -> (w a -> b) -> w b
    func extend<B>(
        _ f: @escaping (Store<S,A>) -> B
    ) -> Store<S,B> {
        Store<S,B>(
            peek: { f(Store(peek: self.peek, pos: $0)) },
            pos: self.pos)
    }

    // w a -> w (w a)
    var duplicate: Store<S, Store<S,A>> {
        extend { $0 }
    }
}

// ---------------------------------------------------------------

struct MemoStore<S: Hashable, A> {
    let peek: (S) -> A
    let pos: S

    // w a -> s -> w a
    func seek(_ s: S) -> MemoStore { duplicate.peek(s) }

    // w a -> (s -> f s) -> f a
    func experiment(_ f: (S) -> [S]) -> [A] {
        f(pos).map(peek)
    }
}

// Comonad
extension MemoStore where S: Hashable {
    // w a -> a
    var extract: A { peek(pos) }

    // w a -> (w a -> b) -> w b
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

    // w a -> w (w a)
    var duplicate: MemoStore<S, MemoStore<S,A>> {
        extend { $0 }
    }
}
