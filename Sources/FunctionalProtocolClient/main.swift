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

// MARK: - Usage

func processData<T: Transformer>(using transformer: T, input: T.Input) {
    let result = transformer.transform(input)
    print("Transformed: \(result)")
}

func filterElements(_ elements: [String], using predicate: AnyPredicate<String>) {
    for element in elements {
        if predicate.evaluate(element) {
            print("✓ \(element)")
        }
    }
}

// 1. Trailing-Closure via .create Factory
processData(using: .create { (input: String) -> String in
    input.uppercased()
}, input: "Swift 6")

// 2. Direct init of the bridge struct
let lengthTransformer = AnyTransformer<String, Int> { $0.count }
print("Length: \(lengthTransformer.transform("Hello"))")

// 3. callAsFunction – use the instance like a function
print("callAsFunction: \(lengthTransformer("World"))")

// 4. Predicate usage
let isLong = AnyPredicate<String> { $0.count > 3 }
print("Is 'Hi' long? \(isLong.evaluate("Hi"))")
print("Is 'Hello' long? \(isLong("Hello"))")
