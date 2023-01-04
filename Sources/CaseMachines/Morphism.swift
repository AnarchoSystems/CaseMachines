//
//  Morphism.swift
//  
//
//  Created by Markus Kasperczyk on 29.12.22.
//

public struct Effects<Chart : StateChart> {
    public let onLeave : [Chart.Effect]
    public let onEnter : [Chart.Effect]
    public let onTransition : [Chart.Effect]
    public init(onLeave: [Chart.Effect] = [], onEnter: [Chart.Effect] = [], onTransition: [Chart.Effect] = []) {
        self.onLeave = onLeave
        self.onEnter = onEnter
        self.onTransition = onTransition
    }
}

public protocol Morphism<Whole> {
    
    associatedtype Whole : StateChart
    @discardableResult
    func execute(_ state: inout Whole) -> Effects<Whole>
    
}

public protocol GuardedMorphism<Whole> : Morphism {
    func shouldRun(on state: Whole) -> Bool
}

public protocol PropertyMorphism : Morphism {
    associatedtype Property
    associatedtype Whole = Property
    var keyPath : WritableKeyPath<Whole, Property> {get}
    func execute(_ state: inout Property) -> Effects<Whole>
}

public extension PropertyMorphism where Property == Whole {
    var keyPath : WritableKeyPath<Whole, Property> {\.self}
}

public extension PropertyMorphism {
    func execute(_ state: inout Whole) -> Effects<Whole> {
        execute(&state[keyPath: keyPath])
    }
}

public extension PropertyMorphism where Self : GuardedMorphism {
    func execute(_ state: inout Whole) -> Effects<Whole> {
        shouldRun(on: state) ? execute(&state[keyPath: keyPath]) : Effects()
    }
}

public protocol Do : GuardedMorphism {
    var effect : Whole.Effect {get}
}

public extension Do {
    
    func shouldRun(on state: Whole) -> Bool {true}
    
    func execute(_ state: inout Whole) -> Effects<Whole> {
        shouldRun(on: state) ? Effects(onTransition: [effect]) : Effects()
    }
    
}

public protocol Move : GuardedMorphism, PropertyMorphism where Property : CaseMachine, Property.Effect == Whole.Effect, From.Machine == Property, To.Machine == Property {
    
    associatedtype From : State
    associatedtype To : State
    
    func doMove(from state: From) -> (To, Whole.Effect?)
    
}

public extension Move {
    
    func shouldRun(on state: Whole) -> Bool {
        From.extract(from: state[keyPath: keyPath]) != nil
    }
    
    @discardableResult
    func execute(_ state: inout Property) -> Effects<Whole> {
        guard let this = From.extract(from: state) else {return Effects()}
        let onLeave = state.onLeave
        let (next, eff) : (To, Whole.Effect?) = doMove(from: this)
        next.embed(into: &state)
        return Effects(onLeave: onLeave.map{[$0]} ?? [], onEnter: state.onEnter.map{[$0]} ?? [], onTransition: eff.map{[$0]} ?? [])
    }
    
}

public protocol PureMove : Move {
    
    associatedtype Machine = From.Machine
    associatedtype From
    associatedtype To
    
    func doMove(from state: From) -> To
    
}

public extension PureMove {
    
    func doMove(from state: From) -> (To, Whole.Effect?) {
        (doMove(from: state), nil)
    }
    
}

public protocol GoTo : Move {
    
    associatedtype Machine = From.Machine
    associatedtype From
    associatedtype To
    
    var newValue : To {get}
    var effect : Whole.Effect? {get}
    
}

public extension GoTo {
    
    @inlinable
    var effect : Whole.Effect? {nil}
    
    func doMove(from state: From) -> (To, Whole.Effect?) {
        (newValue, effect)
    }
    
}

public protocol CaseMethod : PropertyMorphism, GuardedMorphism where Property : CaseMachine, Property.Effect == Whole.Effect, Property == Case.Machine {
    
    associatedtype Case : State
    
    func execute(_ state: inout Case) -> Case.Effect?
    
}

public extension CaseMethod {
    
    func shouldRun(on state: Whole) -> Bool {
        Case.extract(from: state[keyPath: keyPath]) != nil
    }
    
    @discardableResult
    func execute(_ state: inout Property) -> Effects<Whole> {
        let eff = Case.tryModify(&state, using: execute)
        return Effects(onTransition: eff.map{[$0]} ?? [])
    }
    
}

public protocol PureMethod : CaseMethod where Case : State {
    
    associatedtype Whole = Case.Machine
    associatedtype Machine = Case.Machine
    associatedtype Case
    
    func execute(_ state: inout Case)
    
}

public extension PureMethod {
    
    func execute(_ state: inout Case) -> Case.Effect? {
        execute(&state); return nil
    }
    
}

class CustomTypeErasure<Whole : StateChart> : Morphism {
    func execute(_ state: inout Whole) -> Effects<Whole> {
        fatalError()
    }
}

class Eraser<Arrow : Morphism> : CustomTypeErasure<Arrow.Whole> {
    let arrow : Arrow
    init(arrow: Arrow) {
        self.arrow = arrow
    }
    override func execute(_ state: inout Arrow.Whole) -> Effects<Arrow.Whole> {
        arrow.execute(&state)
    }
}

extension Morphism {
    func erased() -> CustomTypeErasure<Whole> {
        Eraser(arrow: self)
    }
}

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
public protocol CoordinatedArrow : GuardedMorphism where Arrows.Whole == Whole {
    associatedtype Arrows : GuardedMorphism
    var arrows : Arrows {get}
}

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
public extension CoordinatedArrow {
    
    func shouldRun(on state: Whole) -> Bool {
        arrows.shouldRun(on: state)
    }
    
    func execute(_ state: inout Whole) -> Effects<Whole> {
        arrows.execute(&state)
    }
    
}

@resultBuilder
@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
public enum ArrowBuilder {
    public static func buildBlock<Whole : StateChart>(_ components: (any GuardedMorphism<Whole>)...) -> [any GuardedMorphism<Whole>] {
        components
    }
}

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
public struct IfAll<Whole : StateChart> : GuardedMorphism {
    public let arrows: [any GuardedMorphism<Whole>]
    public func shouldRun(on state: Whole) -> Bool {
        arrows.allSatisfy{$0.shouldRun(on: state)}
    }
    
    @discardableResult
    public func execute(_ state: inout Whole) -> Effects<Whole> {
        guard shouldRun(on: state) else {
            return Effects()
        }
        var onLeave : [Whole.Effect] = []
        var onEnter : [Whole.Effect] = []
        var onTransition : [Whole.Effect] = []
        for arrow in arrows {
            let erased : CustomTypeErasure<Whole> = arrow.erased() // necessary for whatever reason...
            let effs = erased.execute(&state)
            onLeave.append(contentsOf: effs.onLeave)
            onEnter.append(contentsOf: effs.onEnter)
            onTransition.append(contentsOf: effs.onTransition)
        }
        return Effects(onLeave: onLeave, onEnter: onEnter, onTransition: onTransition)
    }
    public init(@ArrowBuilder arrows: () -> [any GuardedMorphism<Whole>]) {
        self.arrows = arrows()
    }
}


@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
public struct IfAny<Whole : StateChart> : GuardedMorphism {
    public let arrows: [any GuardedMorphism<Whole>]
    public func shouldRun(on state: Whole) -> Bool {
        arrows.contains{$0.shouldRun(on: state)}
    }
    
    @discardableResult
    public func execute(_ state: inout Whole) -> Effects<Whole> {
        guard shouldRun(on: state) else {
            return Effects()
        }
        var onLeave : [Whole.Effect] = []
        var onEnter : [Whole.Effect] = []
        var onTransition : [Whole.Effect] = []
        for arrow in arrows where arrow.shouldRun(on: state) {
            let erased : CustomTypeErasure<Whole> = arrow.erased() // necessary for whatever reason...
            let effs = erased.execute(&state)
            onLeave.append(contentsOf: effs.onLeave)
            onEnter.append(contentsOf: effs.onEnter)
            onTransition.append(contentsOf: effs.onTransition)
        }
        return Effects(onLeave: onLeave, onEnter: onEnter, onTransition: onTransition)
    }
    public init(@ArrowBuilder arrows: () -> [any GuardedMorphism<Whole>]) {
        self.arrows = arrows()
    }
}

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
public extension GuardedMorphism {
    
    /// The operator | (rather than ||) indicates that we take *all* applying arrow, not only the first one we find
    static func |<Rhs : GuardedMorphism<Whole>>(lhs: Self, rhs: Rhs) -> IfAny<Whole> {
        IfAny {
            lhs
            rhs
        }
    }
    
    static func &&<Rhs : GuardedMorphism<Whole>>(lhs: Self, rhs: Rhs) -> IfAll<Whole> {
        IfAll {
            lhs
            rhs
        }
    }
    
}

public struct Unconditional<Machine : CaseMachine> : State {
    public static func extract(from whole: Machine) -> Unconditional<Machine>? {
        Unconditional()
    }
    public func embed(into whole: inout Machine) {
        fatalError()
    }
}

public struct Identity<A, B : State> : PureMethod {
    
    public typealias Case = B
    
    public let keyPath: WritableKeyPath<A, B.Machine>
    
    public init(_ keyPath: WritableKeyPath<A, B.Machine>, expectedState: Case.Type = Case.self) {
        self.keyPath = keyPath
    }
    public init(expectedState: Case.Type = Case.self) where A == Case.Machine {
        self = .init(\.self, expectedState: expectedState)
    }
    
    public func execute(_ state: inout B) {}
    
}

public typealias Id<Case : State> = Identity<Case.Machine, Case>
