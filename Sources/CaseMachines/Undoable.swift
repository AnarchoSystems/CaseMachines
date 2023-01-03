//
//  Undoable.swift
//  
//
//  Created by Markus Kasperczyk on 03.01.23.
//

import Foundation

/// Enables you to easily undo your action.
///
/// If you need any effects to play on undo, you can implement onRevert.
///
/// The default implementation just stores the old state, reverts to it and plays the effects defined by onRevert.
///  If your state is too expensive to save or is for some peculiar reason a reference type, you should implement the reverse method and write a dedicated Undo type.
public protocol Undoable<Whole> : Morphism where Undo.Whole == Whole {
    
    associatedtype Undo : Undoable = DefaultUndo<Self>
    
    var isDiscardable : Bool {get}
    var actionName : String {get}
    func onRevert(to oldState: Whole) -> Effects<Whole>
    func reverse(relativeTo oldState: Whole) -> Undo
    
}

public extension Undoable {
    
    var isDiscardable : Bool {false}
    var actionName : String {""}
    func onRevert(to oldState: Whole) -> Effects<Whole> {
        Effects()
    }
    
}

public extension Undoable where Undo == DefaultUndo<Self> {
    
    func reverse(relativeTo state: Whole) -> Undo {
        .init(oldState: state, redo: self)
    }
    
}

public struct DefaultUndo<U : Undoable> : Undoable {
 
    let oldState : U.Whole
    let redo : U
    
    public var isDiscardable : Bool {
        redo.isDiscardable
    }
    
    public var actionName : String {
        "Undo " + redo.actionName
    }
    
    public func reverse(relativeTo oldState: U.Whole) -> U {
        redo
    }
    
    public func execute(_ state: inout U.Whole) -> Effects<U.Whole> {
        state = oldState
        return redo.onRevert(to: oldState)
    }
    
    public func onRevert(to oldState: U.Whole) -> Effects<U.Whole> {
        var copy = oldState
        return redo.execute(&copy)
    }
    
}


@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
public extension MachineController {
    
    @MainActor
    func send<U : Undoable<Machine>>(_ arrow: U, undoManager: UndoManager?) {
        
        let undo = arrow.reverse(relativeTo: state)
        send(arrow)
        
        undoManager?.registerUndo(withTarget: self) {this in
            this.send(undo, undoManager: undoManager)
        }
        
        undoManager?.setActionName(arrow.actionName)
        undoManager?.setActionIsDiscardable(arrow.isDiscardable)
        
    }
    
}
