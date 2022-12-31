//
//  Case.swift
//  
//
//  Created by Markus Kasperczyk on 29.12.22.
//

import CasePaths


public protocol Case : State where Whole: CaseMachine {
    
    associatedtype Whole
    associatedtype Enum = Whole
    static var keyPath : WritableKeyPath<Whole, Enum> {get}
    static var casePath : CasePath<Enum, Self> {get}
    
}

public extension Case where Whole == Enum {
    static var keyPath : WritableKeyPath<Whole, Enum> {\.self}
}

public extension Case {
    
    static func extract(from whole: Whole) -> Self? {
        casePath.extract(from: whole[keyPath: keyPath])
    }
    
    func embed(into whole: inout Whole) {
        whole[keyPath: Self.keyPath] = Self.casePath.embed(self)
    }
    
}
