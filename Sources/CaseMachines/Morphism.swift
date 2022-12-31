//
//  Morphism.swift
//  
//
//  Created by Markus Kasperczyk on 29.12.22.
//

public protocol Morphism<Machine> {
    
    associatedtype Machine : CaseMachine
    func execute(_ state: inout Machine) -> Machine.Effect?
    
}

public extension CaseMachine {
    
    mutating func run<M : Morphism>(_ morphism: M) -> Effect? where M.Machine == Self {
        morphism.execute(&self)
    }
    
}

public protocol Do : Morphism {
    var effect : Machine.Effect {get}
}

public extension Do {
    func execute(_ state: inout Machine) -> Machine.Effect? {
        effect
    }
}

public protocol Move : Morphism where From.Whole == Machine, To.Whole == Machine {
    
    associatedtype Machine = From.Whole
    associatedtype From : State
    associatedtype To : State
    
    func doMove(from state: From) -> (To, Machine.Effect?)
    
}

public extension Move {
    
    func execute(_ state: inout Machine) -> Machine.Effect? {
        guard let this = From.extract(from: state) else {return nil}
        let (next, eff) : (To, Machine.Effect?) = doMove(from: this)
        next.embed(into: &state)
        return eff
    }
    
}

public extension State {
    
    func run<M : Move>(_ move: M) -> (M.To, Whole.Effect?) where M.From == Self {
        move.doMove(from: self)
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

public extension State {
    
    func run<M : PureMove>(_ move: M) -> M.To where M.From == Self {
        move.doMove(from: self)
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
    
    func execute(_ state: inout Case) -> Case.Effect?
    
}

public extension CaseMethod {
    
    func execute(_ state: inout Machine) -> Machine.Effect? {
        Case.tryModify(&state, using: execute)
    }
    
}

public extension State {
    
    mutating func run<M : CaseMethod>(_ method: M) -> Effect? where M.Case == Self {
        method.execute(&self)
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

public extension State {
    
    mutating func run<M : PureMethod>(_ method: M) where M.Case == Self {
        method.execute(&self)
    }
    
}
