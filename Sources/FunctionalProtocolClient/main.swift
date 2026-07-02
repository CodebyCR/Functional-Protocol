import FunctionalProtocols

// MARK: - Example 1: Basic Transformer (two associated types)

@FunctionalProtocol
protocol Transformer {
    associatedtype Input
    associatedtype Output

    func transform(_ input: Input) -> Output
}

// MARK: - Example 2: Predicate (one associated type, concrete return)

@FunctionalProtocol
protocol Predicate {
    associatedtype Element

    func evaluate(_ element: Element) -> Bool
}

// MARK: - Example 3: Consuming parameter (ownership transfer)

@FunctionalProtocol
protocol Consumer {
    associatedtype Element
    func consume(_ element: consuming Element)
}

// MARK: - Usage

// 5. consuming – ownership transferred into the closure on each call
let logger = ConsumerFunctor<String> { print("Consumed: \($0)") }
logger.consume("ownership")


func processData<T: Transformer>(use transformer: T, input: T.Input) {
    let result = transformer.transform(input)
    print("Transformed: \(result)")
}

func filterElements(_ elements: [String], using predicate: PredicateFunctor<String>) {
    for element in elements {
        if predicate.evaluate(element) {
            print("✓ \(element)")
        }
    }
}

// 1. Trailing-Closure via .transform Factory
processData(use: .transform { (input: String) -> String in
    input.uppercased()
}, input: "Swift 6")

// 2. Direct init of the bridge struct
let lengthTransformer = TransformerFunctor<String, Int> { $0.count }
print("Length: \(lengthTransformer.transform("Hello"))")

// 3. callAsFunction – use the instance like a function
print("callAsFunction: \(lengthTransformer("World"))")

// 4. Predicate usage
let isLong = PredicateFunctor<String> { $0.count > 3 }
print("Is 'Hi' long? \(isLong.evaluate("Hi"))")
print("Is 'Hello' long? \(isLong("Hello"))")
