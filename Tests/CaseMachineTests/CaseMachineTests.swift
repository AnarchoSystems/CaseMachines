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
            if let eff = test.run(arrow) {
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
}

enum Eff {
    case assertInt(Int)
    case assertString(String)
}

enum TestState : CaseMachine {
    
    typealias Effect = Eff
    
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
