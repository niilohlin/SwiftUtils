import Foundation
import UIKit


infix operator >>=: MultiplicationPrecedence
infix operator <^>: MultiplicationPrecedence
infix operator ^>: MultiplicationPrecedence

precedencegroup FunctionApplicationPrecedence {
    associativity: left
    lowerThan: NilCoalescingPrecedence
    higherThan: AssignmentPrecedence
}

infix operator |>: FunctionApplicationPrecedence
@inline(__always) func |><T, U> (left: T, right: @escaping (T) -> U ) -> U {
    return right(left)
}

infix operator <|: FunctionApplicationPrecedence
@inline(__always) func <|<T, U> (left: @escaping (T) -> U, right: T ) -> U {
    return left(right)
}

infix operator >>>: MultiplicationPrecedence
@inline(__always) func >>><A, B, C> (lhs: @escaping (A) -> B, rhs: @escaping (B) -> C) -> (A) -> C {
    return { (x) in rhs(lhs(x)) }
}

infix operator <<<: MultiplicationPrecedence
@inline(__always) func <<<<A, B, C> (lhs: @escaping (B) -> C, rhs: @escaping (A) -> B) -> (A) -> C {
    return { (x) in lhs(rhs(x)) }
}

public func curry2<A, B, C, D>(_ function: @escaping (A, B, C) -> D) -> (A) -> (B) -> (C) -> D {
    return { (a: A) -> (B) -> (C) -> D in { (b: B) -> (C) -> D in { (c: C) -> D in function(a, b, c) } } }
}

public func curry<A, B, C>(_ f : @escaping (A, B) -> C) -> (A) -> (B) -> C {
    return { (a: A) -> (B) -> C in { (b: B) -> C in
            f(a, b)
        }
    }
}

public func flip<A, B, C>(_ f: @escaping (A, B) -> C) -> (B, A) -> C {
    return { (b, a) in
        return f(a, b)
    }
}

public enum Result<Value> {
    case success(Value)
    case failure(Error)

    /// Returns `true` if the result is a success, `false` otherwise.
    public var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }

    /// Returns `true` if the result is a failure, `false` otherwise.
    public var isFailure: Bool {
        return !isSuccess
    }

    /// Returns the associated value if the result is a success, `nil` otherwise.
    public var value: Value? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }

    /// Returns the associated error value if the result is a failure, `nil` otherwise.
    public var error: Error? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
}

extension Result {
    func map<T>(_ f: @escaping (Value) -> T) -> Result<T> {
        switch self {
        case .success(let value):
            return .success(f(value))
        case .failure(let err):
            return .failure(err)
        }
    }

    func flatMap<T>(_ f: @escaping (Value) -> Result<T>) -> Result<T> {
        switch self {
        case .success(let value):
            return f(value)
        case .failure(let err):
            return .failure(err)
        }
    }

    func mapError<T: Error>(_ f: @escaping (Error) -> T) -> Result<Value> {
        if let error = self.error {
            return Result.failure(f(error))
        }
        return self
    }

    static func >>= <T> (left: Result<Value>, right: @escaping (Value) -> Result<T> ) -> Result<T> {
        return left.flatMap(right)
    }

    static func <^> <T>(_ f: @escaping (Value) -> T, left: Result<Value>) -> Result<T> {
        return left.map(f)
    }

    static func ^> <T>(_ f: @escaping (Value) -> T, left: Result<Value>) {
        let _ = left.map(f)
    }
}
extension Array {
    func all(_ f: @escaping (Element) -> Bool) -> Bool {
        for element in self {
            if !f(element) {
                return false
            }
        }
        return true
    }

    func any(_ f: @escaping (Element) -> Bool) -> Bool {
        for element in self {
            if f(element) {
                return true
            }
        }
        return false
    }

    func span(_ p: @escaping (Element) -> Bool) -> ([Element], [Element]) {
        if self.isEmpty {
            return ([], [])
        }
        let x = self.first!
        let xs = Array(self.dropFirst())
        if p(x) {
            let (ys, zs) = xs.span(p)
            return ([x] + ys, zs)
        } else {
            return ([], self)
        }
    }

    func takeWhile(_ f: @escaping (Element) -> Bool) -> [Element] {
        var array: [Element] = []
        for element in self {
            if !f(element) {
                return array
            }
            array.append(element)
        }
        return array
    }

    func takeFirst(_ n: Int) -> ArraySlice<Element> {
        return self.dropLast(self.count - n)
    }

    func pop() -> (Element?, [Element]) {
        return (self.first, Array(self.dropFirst()))
    }

    func mapOptional<T>(_ f: @escaping (Element) -> T?) -> [T] {
        var result: [T] = []
        for element in self {
            if let value = f(element) {
                result.append(value)
            }
        }
        return result
    }

    func firstOptional<T>(_ f: @escaping (Element) -> T?) -> T? {
        for element in self {
            if let value = f(element) {
                return value
            }
        }
        return nil
    }

    static func count(_ array: [Element]) -> Int {
        return array.count
    }

    static func filter(_ isIncluded: @escaping (Element) -> Bool, array: Array) -> Array {
        return array.filter(isIncluded)
    }

}

func zipWith<A, B, C>(_ firstArray: [A], _ secondArray: [B], _ f: @escaping ((A), (B)) -> C) -> [C] {
    return zip(firstArray, secondArray).map(f)
}

func sequence<A>(_ array: [Result<A>]) -> Result<[A]> {
    if(!array.all { $0.isSuccess }) {
        for element in array {
            switch element {
            case .failure(let error):
                return .failure(error)
            default:
                break
            }
        }
    }
    return .success(array.map({ (result) in
        return result.value!
    }))
}

infix operator ⊕: MultiplicationPrecedence
infix operator ⇒: AdditionPrecedence
extension Bool {
    func implies(_ x: Bool) -> Bool {
        return !self || x
    }
    static func ⇒(lhs: Bool, rhs: Bool) -> Bool {
        return lhs.implies(rhs)
    }

    func xOr(_ x: Bool) -> Bool {
        return (self && !x) || (!self && x)
    }

    static func ⊕(lhs: Bool, rhs: Bool) -> Bool {
        return lhs.xOr(rhs)
    }
}

func *<A, B>(lhs: [A], rhs: [B]) -> [(A, B)] {
    return lhs.flatMap { (a) in
        return rhs.map { (b) in
            return (a, b)
        }
    }
}

infix operator /|: MultiplicationPrecedence

func /|<A, B>(_ accumulator: A, lst: [B]) -> ((A, B) -> A) -> A {
    return { reductor in lst.reduce(accumulator, reductor) }
}

infix operator ~>: AdditionPrecedence

/**
 Executes the lefthand closure on a background thread and,
 upon completion, the righthand closure on the main thread.
 Passes the background closure's output, if any, to the main closure.
 */
func ~> <R> (
    backgroundClosure: @escaping () -> R,
    mainClosure:       @escaping (_ result: R) -> Void) {
    queue.async {
        let result = backgroundClosure()
        DispatchQueue.main.async {
            mainClosure(result)
        }
    }
}

/** Serial dispatch queue used by the ~> operator. */
private let queue = DispatchQueue(label: "serial-worker")

func delay(_ delay: Double, closure:@escaping () -> Void) {
    let when = DispatchTime.now() + delay
    DispatchQueue.main.asyncAfter(deadline: when, execute: closure)

}

extension Int {
    var seconds: Int {
        return self
    }
    var minutes: Int {
        return self * 60
    }
    var hours: Int {
        return self.minutes * 60
    }
    var days: Int {
        return self.hours * 24
    }
    var weeks: Int {
        return self.days * 7
    }
}

extension FileManager {
    func file(atPath path: String, isOlderThan timeInterval: Int) throws -> Bool {
        let fileAttributes = try self.attributesOfItem(atPath: path)
        guard let creationDate = fileAttributes[.creationDate] as? Date else {
            // Default to remove file. We do not want old files laying around.
            return true
        }
        return creationDate.compare(Date.init(timeIntervalSinceNow: -(Double)(timeInterval))) == .orderedAscending
    }
}

extension Dictionary {
    func dictionary(insertingValue value: Value, forKey key: Key) -> Dictionary {
        var dictionary = self
        dictionary[key] = value
        return dictionary
    }
}

extension String {
    func countOccurences(of string: String) -> Int {
        return self.components(separatedBy: string).count - 1
    }

    var words: [String] {
        return self.components(separatedBy: " ")
    }
}

extension IndexPath {
    static var zero: IndexPath {
        return IndexPath.init(row: 0, section: 0)
    }
}

extension URLComponents {
    mutating func addQueryItems(_ dictionary: [String: String]) {
        for (key, value) in dictionary {
            self.queryItems?.append(URLQueryItem.init(name: key, value: value))
        }
    }
}

func * <A>(lhs: Int, rhs: [A]) -> [A] {
    var accumulator: [A] = []
    for _ in 0..<lhs {
        accumulator += rhs
    }
    return accumulator
}

func * <A>(lhs: [A], rhs: Int) -> [A] {
    return rhs * lhs
}

extension CGRect {
    func under(inset: CGFloat, height: CGFloat) -> CGRect {
        return CGRect(x: self.origin.x, y: self.maxY + inset, width: self.width, height: height)
    }
}

func fst<A, B>(tuple: (A, B)) -> A {
    return tuple.0
}
func snd<A, B>(tuple: (A, B)) -> B {
    return tuple.1
}
