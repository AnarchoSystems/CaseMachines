//
//  StateChart.swift
//  
//
//  Created by Markus Kasperczyk on 01.01.23.
//


public protocol StateChart {
    associatedtype Effect = Void
    var onInit : Effect? {get}
}

public extension StateChart {
    var onInit : Effect? {nil}
}
