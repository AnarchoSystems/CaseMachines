//
//  State.swift
//  
//
//  Created by Markus Kasperczyk on 29.12.22.
//


public protocol State {
    
    associatedtype Machine : CaseMachine
    associatedtype Effect = Machine.Effect
    
    static func extract(from whole: Machine) -> Self?
    func embed(into whole: inout Machine)
    
    static func tryModify(_ state: inout Machine, using closure: (inout Self) -> Effect?) -> Machine.Effect?
    
    static func embed(_ effect: Effect) -> Machine.Effect
    
}

public extension State where Effect == Machine.Effect {
    @inlinable
    static func embed(_ effect: Effect) -> Machine.Effect {
        effect
    }
}

public extension State {
    
    static func tryModify(_ state: inout Machine, using closure: (inout Self) -> Effect?) -> Machine.Effect? {
        guard var this = extract(from: state) else {return nil}
        state = .init()
        defer {this.embed(into: &state)}
        return closure(&this).map(Self.embed)
    }

}

public extension State where Machine == Self {
    
    @inlinable
    static func extract(from whole: Machine) -> Self? {
        whole
    }
    
    @inlinable
    func embed(into whole: inout Machine) {
        whole = self
    }
    
    @inlinable
    static func tryModify(_ state: inout Machine, using closure: (inout Self) -> Machine.Effect?) -> Machine.Effect? {
        closure(&state)
    }
    
}
