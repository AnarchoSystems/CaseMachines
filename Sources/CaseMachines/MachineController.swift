//
//  MachineController.swift
//  
//
//  Created by Markus Kasperczyk on 31.12.22.
//

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
public protocol EffectInterpreter<Machine> : AnyObject {
    
    associatedtype Machine : CaseMachine
    
    var controller : MachineController<Machine>! {get set}
    func onEffect(_ effect: Machine.Effect)
    
}

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
fileprivate extension EffectInterpreter {
    
    func onEffect(_ any: Any) {
        onEffect(any as! Machine.Effect)
    }
    
}

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
@MainActor
open class MachineController<Machine : CaseMachine> {
    
    private(set) public var state : Machine
    private let interpreter : (any EffectInterpreter<Machine>)?
    private var actionQueue = [any Morphism<Machine>]()
    
    public init(state: Machine, interpreter: (any EffectInterpreter<Machine>)? = nil) {
        self.state = state
        self.interpreter = interpreter
        self.interpreter?.controller = self
        if let onEnter = self.state.onEnter {
            self.interpreter?.onEffect(onEnter)
        }
    }
    
    open func stateWillChange() {}
    
    public func send<Arrow : Morphism>(_ arrow: Arrow) where Arrow.Machine == Machine {
        actionQueue.append(arrow)
        if actionQueue.count == 1 {
            startDispatching()
        }
    }
    
    private func startDispatching() {
        
        stateWillChange()
        
        var idx = 0
        while actionQueue.indices.contains(idx) {
            
            let action = actionQueue[idx]
            
            let rawCase = state.rawCase
            let onLeave = state.onLeave
            
            let effect = state.run(action)
            
            if state.rawCase != rawCase {
                if let onLeave {
                    self.interpreter?.onEffect(onLeave)
                }
                if let onEnter = state.onEnter {
                    self.interpreter?.onEffect(onEnter)
                }
            }
            
            if let effect {
                self.interpreter?.onEffect(effect)
            }
            
            idx += 1
            
        }
        
        actionQueue = []
        
    }
    
}
