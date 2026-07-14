/// Tick math shared by the anchor check (phase 03) and the convergence
/// display (phase 05, FR-PH-4).

@inline(__always)
public func gcd(_ a: Tick, _ b: Tick) -> Tick {
    var (a, b) = (abs(a), abs(b))
    while b != 0 { (a, b) = (b, a % b) }
    return a
}

@inline(__always)
public func lcm(_ a: Tick, _ b: Tick) -> Tick {
    precondition(a > 0 && b > 0, "lcm requires positive values")
    return a / gcd(a, b) * b
}

public func lcm(_ values: Tick...) -> Tick {
    precondition(!values.isEmpty)
    return values.dropFirst().reduce(values[0]) { lcm($0, $1) }
}
