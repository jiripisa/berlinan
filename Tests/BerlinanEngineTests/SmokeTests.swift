import Testing
@testable import BerlinanEngine

@Suite("Package skeleton smoke tests")
struct SmokeTests {

    @Test("Engine reports a semantic version")
    func engineVersion() {
        let parts = EngineInfo.version.split(separator: ".")
        #expect(parts.count == 3)
        #expect(parts.allSatisfy { Int($0) != nil })
    }
}
