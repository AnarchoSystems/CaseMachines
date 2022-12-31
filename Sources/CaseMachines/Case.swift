//
//  Case.swift
//  
//
//  Created by Markus Kasperczyk on 29.12.22.
//

import CasePaths


public protocol Case : State where Whole: CaseMachine {
    
    associatedtype Whole
    static var casePath : CasePath<Whole, Self> {get}
    
}

public extension Case {
    
    static func extract(from whole: Whole) -> Self? {
        casePath.extract(from: whole)
    }
    
    func embed() -> Whole {
        Self.casePath.embed(self)
    }
    
}
