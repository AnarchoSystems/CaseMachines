//
//  CaseMachine.swift
//  
//
//  Created by Markus Kasperczyk on 29.12.22.
//

public struct EquatableVoid : Equatable {}

public protocol CaseMachine : State where Whole == Self {
    associatedtype Whole = Self
    associatedtype Effect = Void
    associatedtype RawCases : Equatable = EquatableVoid
    var rawCase : RawCases {get}
    var onEnter : Effect? {get}
    var onLeave : Effect? {get}
}

public extension CaseMachine where RawCases == EquatableVoid {
    var rawCase : RawCases {
        .init()
    }
}

public extension CaseMachine {
    var onEnter : Effect? {nil}
    var onLeave : Effect? {nil}
}

public extension CaseMachine {
    
    @inlinable
    static func extract(from whole: Whole) -> Self? {
        whole
    }
    
    @inlinable
    func embed(into whole: inout Whole) {
        whole = self
    }
    
    @inlinable
    static func tryModify(_ state: inout Whole, using closure: (inout Self) -> Whole.Effect?) -> Whole.Effect? {
        closure(&state)
    }
    
}
