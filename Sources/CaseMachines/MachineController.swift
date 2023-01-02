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

protocol StateChartMethod<Chart> {
    
    associatedtype Chart : StateChart
    associatedtype Arrow : Morphism
    var property : WritableKeyPath<Chart, Arrow.Whole> {get}
    var arrow : Arrow {get}
    
}

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
extension StateChartMethod {
    
    @MainActor
    func run(on state: inout Chart, interpreter: (any EffectInterpreter<Chart>)?) {
        let effects = arrow.execute(&state[keyPath: property])
        guard let interpreter else {return}
        for effect in effects.onLeave + effects.onEnter + effects.onTransition {
            interpreter.onEffect(effect)
        }
    }
    
}

struct ChartMethod<Arrow : Morphism> : StateChartMethod {
    typealias Chart = Arrow.Whole
    var property: WritableKeyPath<Arrow.Whole, Arrow.Whole> {\.self}
    let arrow: Arrow
}

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
open class MachineController<Machine : StateChart> {
    
    @MainActor
    private(set) public var state : Machine
    private var interpreter : (any EffectInterpreter<Machine>)?
    @MainActor
    private var actionQueue = [any StateChartMethod<Machine>]()
    
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
        actionQueue.append(ChartMethod(arrow: arrow))
        if actionQueue.count == 1 {
            startDispatching()
        }
    }
    
    @MainActor
    private func startDispatching() {
        
        var idx = 0
        
        stateWillChange()
        
        while actionQueue.indices.contains(idx) {
            
            let action = actionQueue[idx]
            
            action.run(on: &state, interpreter: interpreter)
            
            idx += 1
            
        }
        
        stateDidChange()
        
        actionQueue = []
        
    }
    
}
