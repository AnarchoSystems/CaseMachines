import XCTest
@testable import CaseMachines
import CasePaths

typealias Arrow = Morphism<TestState>

final class CaseMachineTests: XCTestCase {
    
    
    @available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
    func testExample() throws {
        
        var test = TestState()
        
        let arrows : [any Arrow] = [TestState.Assert1(),
                                    StringState.SetValue(value: 42),
                                    TestState.Assert2(),
                                    IntState.Add(addedValue: 42),
                                    TestState.RunEff(effect: IntState.embed(42)),
                                    IntState.Stringify(),
                                    TestState.RunEff(effect: StringState.embed("answer: 42")),
                                    StringState.SetValue(value: 1337),
                                    TestState.RunEff(effect: IntState.embed(1337)),]
        
        for arrow in arrows {
            if let eff = arrow.execute(&test).onTransition {
                switch eff {
                case .assertInt(let val):
                    guard case .state1(let state) = test else {
                        XCTFail()
                        continue
                    }
                    XCTAssertEqual(state.value, val)
                case .assertString(let val):
                    guard case .state2(let state) = test else {
                        XCTFail()
                        continue
                    }
                    XCTAssertEqual(state.value, val)
                }
            }
        }
        
    }
    
    @available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
    @MainActor
    func testProduceConsume() {
        
        class DummyInterpreter : EffectInterpreter {
            var controller: CaseMachines.MachineController<ProducerConsumer>!
            @MainActor
            func onEffect(_ effect: ProducerConsumer.Effect) {
                controller.send(effect)
            }
        }
        
        let controller = MachineController(state: ProducerConsumer(), interpreter: DummyInterpreter())
        
        controller.send(ProducerConsumer.IdleConsumer.Consume())
        
        guard
            case .idle = controller.state.producer, // producer hasn't done anything yet
            case .idle = controller.state.consumer, // nothing to consume yet
            case .empty = controller.state.buffer else { // buffer still empty
            return XCTFail()
        }
        
        controller.send(ProducerConsumer.IdleProducer.Produce())
        
        guard
            case .producing = controller.state.producer, // producer started production
            case .idle = controller.state.consumer, // nothing to consume yet
            case .empty = controller.state.buffer else { // buffer still empty
            return XCTFail()
        }
        
        
        controller.send(ProducerConsumer.Producing.Finish())
        
        guard
            case .idle = controller.state.producer, // producer is idle again
            case .idle = controller.state.consumer, // nothing to consume yet
            case .goodsAvailable = controller.state.buffer else { // producer has filled buffer
            return XCTFail()
        }
        
        controller.send(ProducerConsumer.IdleConsumer.Consume())
        
        guard
            case .idle = controller.state.producer, // producer is idle again
            case .consuming = controller.state.consumer, // finally we get to consume
            case .empty = controller.state.buffer else { // buffer empty again
            return XCTFail()
        }
        
        controller.send(ProducerConsumer.Consuming.Finish())
        
        guard
            case .idle = controller.state.producer, // producer is idle again
            case .idle = controller.state.consumer, // done consuming
            case .empty = controller.state.buffer else { // buffer empty again
            return XCTFail()
        }
        
        
    }
}

enum Eff {
    case assertInt(Int)
    case assertString(String)
}

enum TestState : CaseMachine, State {
    
    typealias Effect = Eff
    typealias Whole = TestState
    
    case state1(IntState)
    case state2(StringState)
    init() {self = .state1(IntState())}
    
    struct Assert1 : Move {
        func doMove(from state: TestState) -> (TestState, Effect?) {
            switch state {
            case .state1(let int):
                return (state, .assertInt(int.value))
            case .state2(let str):
                return (state, .assertString(str.value))
            }
        }
    }
    
    struct Assert2 : CaseMethod {
      func execute(_ state: inout TestState) -> Effect? {
            switch state {
            case .state1(let int):
                return .assertInt(int.value)
            case .state2(let str):
                return .assertString(str.value)
            }
        }
    }
    
    struct RunEff : Do {
        typealias Machine = TestState
        let effect: Eff
    }
    
    @inlinable
    static func extract(from whole: Whole) -> Self? {
        whole
    }
    
    @inlinable
    func embed(into whole: inout Whole) {
        whole = self
    }
    
    @inlinable
    static func tryModify(_ state: inout Whole, using closure: (inout Self) -> Whole.Effect?) -> Whole.Effect? {
        closure(&state)
    }
    
}

struct IntState : Case {
    
    typealias Whole = TestState
    
    static let casePath = /TestState.state1
    
    var value : Int = 0
    
    static func embed(_ effect: Int) -> Eff {
        .assertInt(effect)
    }
    
    struct Stringify : PureMove {
        
        func doMove(from state: IntState) -> StringState {
            StringState(value: "answer: \(state.value)")
        }
        
    }
    
    struct Add : PureMethod {
        let addedValue : Int
        func execute(_ state: inout IntState) {
            state.value += addedValue
        }
    }
    
}

struct StringState : Case {
    
    typealias Whole = TestState
    
    static let casePath = /TestState.state2
    
    let value : String
    
    static func embed(_ effect: String) -> Eff {
        .assertString(effect)
    }
    
    struct SetValue : GoTo {
        typealias From = StringState
        let value : Int
        var newValue : IntState {
            IntState(value: value)
        }
    }
}

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
struct ProducerConsumer : StateChart {
    
    typealias Effect = any Morphism<Buffer>
    
    var producer = Producer.idle(IdleProducer())
    var buffer = Buffer.empty(EmptyBuffer())
    var consumer = Consumer.idle(IdleConsumer())
    
    enum Producer : CaseMachine {
        typealias Whole = ProducerConsumer
        case idle(IdleProducer)
        case producing(Producing)
    }
    
    enum Buffer : CaseMachine {
        typealias Whole = ProducerConsumer
        case empty(EmptyBuffer)
        case goodsAvailable(Goods)
    }
    
    enum Consumer : CaseMachine {
        typealias Whole = ProducerConsumer
        case idle(IdleConsumer)
        case consuming(Consuming)
    }
    
}

@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
extension ProducerConsumer {
    
    struct IdleProducer : Case {
        
        typealias Whole = Producer
        static let casePath = /Producer.idle
        
        struct Produce : GoTo {
            typealias From = IdleProducer
            let keyPath = \ProducerConsumer.producer
            let newValue = Producing()
        }
        
    }
    
    struct Producing : Case {
        
        typealias Whole = Producer
        static let casePath = /Producer.producing
        
        struct Finish : GoTo {
            typealias From = Producing
            let keyPath = \ProducerConsumer.producer
            let newValue = IdleProducer()
            let effect : Effect? = EmptyBuffer.Fill()
            func shouldRun(on state: ProducerConsumer) -> Bool {
                guard case .empty = state.buffer else {return false}
                return true
            }
        }
        
    }
    
}


@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
extension ProducerConsumer {
    
    struct EmptyBuffer : Case {
        
        typealias Whole = Buffer
        static let casePath = /Buffer.empty
        
        struct Fill : GoTo {
            typealias From = EmptyBuffer
            let keyPath = \ProducerConsumer.buffer
            let newValue = Goods()
        }
        
    }
    
    struct Goods : Case {
        
        typealias Whole = Buffer
        static let casePath = /Buffer.goodsAvailable
        
        struct Use : GoTo {
            typealias From = Goods
            let keyPath = \ProducerConsumer.buffer
            let newValue = EmptyBuffer()
        }
        
    }
    
}


@available(iOS 16.0.0, macOS 13.0.0, tvOS 16.0.0, watchOS 9.0.0, *)
extension ProducerConsumer {
    
    struct IdleConsumer : Case {
        
        typealias Whole = Consumer
        static let casePath = /Consumer.idle
        
        struct Consume : GoTo {
            typealias From = IdleConsumer
            let keyPath = \ProducerConsumer.consumer
            let newValue = Consuming()
            let effect : Effect? = Goods.Use()
            func shouldRun(on state: ProducerConsumer) -> Bool {
                guard case .goodsAvailable = state.buffer else {return false}
                return true
            }
        }
        
    }
    
    struct Consuming : Case {
        
        typealias Whole = Consumer
        static let casePath = /Consumer.consuming
        
        struct Finish : GoTo {
            typealias From = Consuming
            let keyPath = \ProducerConsumer.consumer
            let newValue = IdleConsumer()
        }
        
    }
}
