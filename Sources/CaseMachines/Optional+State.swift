//
//  Optional+State.swift
//  
//
//  Created by Markus Kasperczyk on 04.01.23.
//


extension Dictionary {
    public subscript(key: Key, droppingWritesOnNil defaultValue: Value) -> Value {
        get {self[key, default: defaultValue]}
        set {
            guard self[key] != nil else {return}
            self[key] = newValue
        }
    }
}

extension Optional : StateChart where Wrapped : StateChart {
    public typealias Effect = Wrapped.Effect
    public var onInit : Wrapped.Effect? {
        switch self {
        case .none:
            return nil
        case .some(let wrapped):
            return wrapped.onInit
        }
    }
}

extension Optional : CaseMachine, State where Wrapped : CaseMachine {
    public typealias Machine = Self
    public typealias Whole = Wrapped.Whole
    public init() {self = .none}
}
