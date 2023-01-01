//
//  CaseMachine.swift
//  
//
//  Created by Markus Kasperczyk on 29.12.22.
//

public struct EquatableVoid : Equatable {}

public protocol CaseMachine : StateChart where Effect == Whole.Effect {
    associatedtype Whole : StateChart = Self
    associatedtype Effect = Whole.Effect
    var onEnter : Effect? {get}
    var onLeave : Effect? {get}
}

public extension CaseMachine {
    var onEnter : Effect? {nil}
    var onLeave : Effect? {nil}
    var onInit : Effect? {onEnter}
}
