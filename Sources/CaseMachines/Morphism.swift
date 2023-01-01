//
//  Morphism.swift
//  
//
//  Created by Markus Kasperczyk on 29.12.22.
//

public struct Effects<Eff> {
    public let onLeave : [Eff]
    public let onEnter : [Eff]
    public let onTransition : [Eff]
    public init(onLeave: [Eff] = [], onEnter: [Eff] = [], onTransition: [Eff] = []) {
        self.onLeave = onLeave
        self.onEnter = onEnter
        self.onTransition = onTransition
    }
}

public protocol Morphism<Whole> {
    
    associatedtype Whole : StateChart
    func execute(_ state: inout Whole) -> Effects<Whole.Effect>
    
}

public protocol GuardedMorphism<Whole> : Morphism {
    func shouldRun(on state: Whole) -> Bool
}

public protocol Do : GuardedMorphism {
    var effect : Whole.Effect {get}
}

public extension Do {
    
    func shouldRun(on state: Whole) -> Bool {true}
    
    func execute(_ state: inout Whole) -> Effects<Whole.Effect> {
        shouldRun(on: state) ? Effects(onTransition: [effect]) : Effects()
    }
    
}

public protocol Move : GuardedMorphism where From.Whole == To.Whole, To.Whole == Machine, Whole == Machine.Whole {
    
    associatedtype Whole = Machine.Whole
    associatedtype Machine = From.Whole
    associatedtype From : State
    associatedtype To : State
    
    var keyPath : WritableKeyPath<Whole, Machine> {get}
    func doMove(from state: From) -> (To, Machine.Effect?)
    
}

public extension Move where Machine == Whole {
    var keyPath : WritableKeyPath<Whole, Machine> {
        \.self
    }
}

public extension Move {
    
    func shouldRun(on state: Machine.Whole) -> Bool {
        From.extract(from: state[keyPath: keyPath]) != nil
    }
    
    func execute(_ state: inout Machine.Whole) -> Effects<Machine.Effect> {
        guard shouldRun(on: state),
              let this = From.extract(from: state[keyPath: keyPath]) else {return Effects()}
        let onLeave = state[keyPath: keyPath].onLeave
        let (next, eff) : (To, Machine.Effect?) = doMove(from: this)
        next.embed(into: &state[keyPath: keyPath])
        return Effects(onLeave: onLeave.map{[$0]} ?? [], onEnter: state[keyPath: keyPath].onEnter.map{[$0]} ?? [], onTransition: eff.map{[$0]} ?? [])
    }
    
}

public protocol PureMove : Move {
    
    associatedtype Machine = From.Whole
    associatedtype From
    associatedtype To
    
    func doMove(from state: From) -> To
    
}

public extension PureMove {
    
    func doMove(from state: From) -> (To, Machine.Effect?) {
        (doMove(from: state), nil)
    }
    
}

public protocol GoTo : Move {
    
    associatedtype Machine = From.Whole
    associatedtype From
    associatedtype To
    
    var newValue : To {get}
    var effect : Machine.Effect? {get}
    
}

public extension GoTo {
    
    @inlinable
    var effect : Machine.Effect? {nil}
    
    func doMove(from state: From) -> (To, Machine.Effect?) {
        (newValue, effect)
    }
    
}

public protocol CaseMethod : GuardedMorphism where Machine == Case.Whole, Whole == Machine.Whole {
    
    associatedtype Machine = Case.Whole
    associatedtype Case : State
    
    var keyPath : WritableKeyPath<Whole, Machine> {get}
    func execute(_ state: inout Case) -> Case.Effect?
    
}

public extension CaseMethod where Machine == Whole {
    var keyPath : WritableKeyPath<Whole, Machine> {
        \.self
    }
}

public extension CaseMethod {
    
    func shouldRun(on state: Machine.Whole) -> Bool {
        Case.extract(from: state[keyPath: keyPath]) != nil
    }
    
    func execute(_ state: inout Machine.Whole) -> Effects<Machine.Effect> {
        guard shouldRun(on: state) else {return Effects()}
        let eff = Case.tryModify(&state[keyPath: keyPath], using: execute)
        return Effects(onTransition: eff.map{[$0]} ?? [])
    }
    
}

public protocol PureMethod : CaseMethod where Case : State {
    
    associatedtype Machine = Case.Whole
    associatedtype Case
    
    func execute(_ state: inout Case)
    
}

public extension PureMethod {
    
    func execute(_ state: inout Case) -> Case.Effect? {
        execute(&state); return nil
    }
    
}

class CustomTypeErasure<Whole : StateChart> : Morphism {
    func execute(_ state: inout Whole) -> Effects<Whole.Effect> {
        fatalError()
    }
}

class Eraser<Arrow : Morphism> : CustomTypeErasure<Arrow.Whole> {
    let arrow : Arrow
    init(arrow: Arrow) {
        self.arrow = arrow
    }
    override func execute(_ state: inout Arrow.Whole) -> Effects<Arrow.Whole.Effect> {
        arrow.execute(&state)
    }
}

extension Morphism {
    func erased() -> CustomTypeErasure<Whole> {
        Eraser(arrow: self)
    }
}

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
public protocol MultiArrow : GuardedMorphism where Arrows.Whole == Whole {
    associatedtype Arrows : GuardedMorphism
    var arrows : Arrows {get}
}

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
public extension MultiArrow {
    
    func shouldRun(on state: Whole) -> Bool {
        arrows.shouldRun(on: state)
    }
    
    func execute(_ state: inout Whole) -> Effects<Whole.Effect> {
        arrows.execute(&state)
    }
    
}

@resultBuilder
@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
public enum ArrowBuilder {
    public static func buildBlock<Whole : StateChart>(_ components: (any GuardedMorphism<Whole>)...) -> some GuardedMorphism<Whole> {
        Arrows(_arrows: components)
    }
}

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
struct Arrows<Whole : StateChart> : MultiArrow {
    let _arrows: [any GuardedMorphism<Whole>]
    var arrows : Self {self}
    func shouldRun(on state: Whole) -> Bool {
        _arrows.allSatisfy{$0.shouldRun(on: state)}
    }
    func execute(_ state: inout Whole) -> Effects<Whole.Effect> {
        guard shouldRun(on: state) else {
            return Effects()
        }
        var onLeave : [Whole.Effect] = []
        var onEnter : [Whole.Effect] = []
        var onTransition : [Whole.Effect] = []
        for arrow in _arrows {
            let erased : CustomTypeErasure<Whole> = arrow.erased() // necessary for whatever reason...
            let effs = erased.execute(&state)
            onLeave.append(contentsOf: effs.onLeave)
            onEnter.append(contentsOf: effs.onEnter)
            onTransition.append(contentsOf: effs.onTransition)
        }
        return Effects(onLeave: onLeave, onEnter: onEnter, onTransition: onTransition)
    }
}
