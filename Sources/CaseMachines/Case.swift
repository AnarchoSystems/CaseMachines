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
    
    func embed(into whole: inout Whole) {
        whole = Self.casePath.embed(self)
    }
    
}
