//
//  State.swift
//  
//
//  Created by Markus Kasperczyk on 29.12.22.
//


public protocol State {
    
    associatedtype Whole : CaseMachine
    associatedtype Effect = Whole.Effect
    
    static func extract(from whole: Whole) -> Self?
    func embed(into whole: inout Whole)
    
    static func tryModify(_ state: inout Whole, using closure: (inout Self) -> Effect?) -> Whole.Effect?
    
    static func embed(_ effect: Effect) -> Whole.Effect
    
}

public extension State where Effect == Whole.Effect {
    @inlinable
    static func embed(_ effect: Effect) -> Whole.Effect {
        effect
    }
}

public extension State {
    
    static func tryModify(_ state: inout Whole, using closure: (inout Self) -> Effect?) -> Whole.Effect? {
        guard var this = extract(from: state) else {return nil}
        defer {this.embed(into: &state)}
        return closure(&this).map(Self.embed)
    }
    
}
