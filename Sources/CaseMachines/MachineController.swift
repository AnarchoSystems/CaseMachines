//
//  MachineController.swift
//  
//
//  Created by Markus Kasperczyk on 31.12.22.
//

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
public protocol EffectInterpreter<Machine> {
    
    associatedtype Machine : StateChart
    
    var controller : MachineController<Machine>! {get set}
    @MainActor
    func onEffect(_ effect: Machine.Effect)
    
}

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
fileprivate extension EffectInterpreter {
    
    @MainActor
    func onEffect(_ any: Any) {
        onEffect(any as! Machine.Effect)
    }
    
}

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
open class MachineController<Machine : StateChart> {
    
    @MainActor
    private(set) public var state : Machine
    private var interpreter : (any EffectInterpreter<Machine>)?
    
    public init(state: Machine, interpreter: (any EffectInterpreter<Machine>)? = nil) {
        self.state = state
        self.interpreter = interpreter
        self.interpreter?.controller = self
        if let onEnter = self.state.onInit {
            Task {
                await self.interpreter?.onEffect(onEnter)
            }
        }
    }
    
    @MainActor
    open func stateWillChange() {}
    @MainActor
    open func stateDidChange() {}
    
    @MainActor
    public func send<Arrow : Morphism>(_ arrow: Arrow) where Arrow.Whole == Machine {
        _stateWillChange()
        let effects = arrow.execute(&state)
        guard let interpreter else {return}
        for effect in effects.onLeave + effects.onEnter + effects.onTransition {
            interpreter.onEffect(effect)
        }
        _stateDidChange()
    }
    
    private var actions = 0
    
    @MainActor
    private func _stateWillChange() {
        if actions == 0 {
            stateWillChange()
        }
        actions += 1
    }
    
    @MainActor
    private func _stateDidChange() {
        actions -= 1
        if actions == 0 {
            stateDidChange()
        }
    }
    
}
