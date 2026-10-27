import Foundation
import Testing
@testable import FraudLite

/// Swift-порт має давати рівно ті самі бали, рівень і прапорці, що й Python.
/// Вектори: `python3 -I gen_l1_vectors.py <fraud_engine.py> Resources/l1_vectors.json`.
struct Vector: Decodable {
    let amount: Double
    let balance: Double
    let description: String
    let score: Int
    let level: String
    let flags: [String]
}

@Test func matchesPythonLayer1() throws {
    let url = try #require(Bundle.module.url(forResource: "l1_vectors", withExtension: "json"))
    let vectors = try JSONDecoder().decode([Vector].self, from: Data(contentsOf: url))
    #expect(vectors.count > 400)
    for v in vectors {
        let r = FraudLite.assess(amount: v.amount, balance: v.balance, description: v.description)
        #expect(r.score == v.score, "\(v.amount) / \(v.balance) / \(v.description)")
        #expect(r.level.rawValue == v.level)
        #expect(r.flags == v.flags)
    }
}

@Test func pythonRoundingIsBankers() {
    #expect(pyRound(2.5) == 2)
    #expect(pyRound(3.5) == 4)
}
