//
//  Morphism.swift
//  
//
//  Created by Markus Kasperczyk on 29.12.22.
//

public struct Effects<Eff> {
    public let onLeave : Eff?
    public let onEnter : Eff?
    public let onTransition : Eff?
    public init(onLeave: Eff? = nil, onEnter: Eff? = nil, onTransition: Eff? = nil) {
        self.onLeave = onLeave
        self.onEnter = onEnter
        self.onTransition = onTransition
    }
}

// TODO: find some convenient way to make this into Morphism<StateChart>

public protocol Morphism<Machine> {
    
    associatedtype Machine : CaseMachine
    var keyPath : WritableKeyPath<Machine.Whole, Machine> {get}
    func execute(_ state: inout Machine.Whole) -> Effects<Machine.Effect>
    
}

public extension Morphism where Machine.Whole == Machine {
    var keyPath : WritableKeyPath<Machine.Whole, Machine> {\.self}
}

public protocol Do : Morphism {
    func shouldRun(on state: Machine.Whole) -> Bool
    var effect : Machine.Effect {get}
}

public extension Do {
    
    func shouldRun(on state: Machine.Whole) -> Bool {true}
    
    func execute(_ state: inout Machine.Whole) -> Effects<Machine.Effect> {
        shouldRun(on: state) ? Effects(onTransition: effect) : Effects()
    }
    
}

public protocol Move : Morphism where From.Whole == To.Whole, To.Whole == Machine {
    
    associatedtype Machine = From.Whole
    associatedtype From : State
    associatedtype To : State
    
    func shouldRun(on state: Machine.Whole) -> Bool
    func doMove(from state: From) -> (To, Machine.Effect?)
    
}

public extension Move {
    
    func shouldRun(on state: Machine.Whole) -> Bool {true}
    
    func execute(_ state: inout Machine.Whole) -> Effects<Machine.Effect> {
        guard shouldRun(on: state),
              let this = From.extract(from: state[keyPath: keyPath]) else {return Effects()}
        let onLeave = state[keyPath: keyPath].onLeave
        let (next, eff) : (To, Machine.Effect?) = doMove(from: this)
        next.embed(into: &state[keyPath: keyPath])
        return Effects(onLeave: onLeave, onEnter: state[keyPath: keyPath].onEnter, onTransition: eff)
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

public protocol CaseMethod : Morphism where Machine == Case.Whole {
    
    associatedtype Machine = Case.Whole
    associatedtype Case : State
    
    func shouldRun(on state: Machine.Whole) -> Bool
    func execute(_ state: inout Case) -> Case.Effect?
    
}

public extension CaseMethod {
    
    func shouldRun(on state: Machine.Whole) -> Bool {true}
    
    func execute(_ state: inout Machine.Whole) -> Effects<Machine.Effect> {
        guard shouldRun(on: state) else {return Effects()}
        let eff = Case.tryModify(&state[keyPath: keyPath], using: execute)
        return Effects(onTransition: eff)
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
