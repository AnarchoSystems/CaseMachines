//
//  Case.swift
//  
//
//  Created by Markus Kasperczyk on 29.12.22.
//

import CasePaths


public protocol Case : State where Machine: CaseMachine {
    
    associatedtype Machine
    static var casePath : CasePath<Machine, Self> {get}
    
}

public extension Case {
    
    static func extract(from whole: Machine) -> Self? {
        casePath.extract(from: whole)
    }
    
    func embed(into whole: inout Machine) {
        whole = Self.casePath.embed(self)
    }
    
}
