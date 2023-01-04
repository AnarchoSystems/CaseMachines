//
//  CaseMachine.swift
//  
//
//  Created by Markus Kasperczyk on 29.12.22.
//

public protocol CaseMachine : StateChart {
    var onEnter : Effect? {get}
    var onLeave : Effect? {get}
    init()
}

public extension CaseMachine {
    var onEnter : Effect? {nil}
    var onLeave : Effect? {nil}
    var onInit : Effect? {onEnter}
}
