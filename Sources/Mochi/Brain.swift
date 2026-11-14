import Foundation

/// Where the pet is currently attached.
enum Surface { case floor, leftWall, rightWall, ceiling, air }

/// What the pet can do. Add new behaviors here, then handle them in PetController + PetView.
enum PetAction: Equatable {
    case idle
    case walk(axis: CGFloat)   // +1 / -1 along the current surface (right/up), set when chosen
    case sleep
    case chase                 // follow the cursor
    case happy
    case greet                 // hop + say something
    case leap                  // jump up onto a window
    case stretch               // big yawn + stretch
    case spin                  // a full twirl
    case dance                 // wiggle with music notes
    case lookAround            // glance left and right
    case zoomies               // sprint back and forth
}

struct Decision {
    let action: PetAction
    let duration: TimeInterval
}

/// Everything the brain is allowed to know about the world.
struct PetContext {
    let surface: Surface
    let axisFraction: CGFloat          // 0...1 position along the current surface
    let cursorDistance: CGFloat
    let secondsSinceInteraction: TimeInterval
    let hour: Int
    let platformAbove: Bool            // a window is within leaping reach
}

/// The seam for future AI: anything that can pick the next Decision.
/// Today: `RuleBrain`. Later: an `LLMBrain` that calls a model.
protocol Brain {
    func nextDecision(_ ctx: PetContext) -> Decision
}

/// Weighted-random behavior, no AI.
struct RuleBrain: Brain {
    func nextDecision(_ ctx: PetContext) -> Decision {
        let late = ctx.hour >= 23 || ctx.hour < 6
        let sleepy = ctx.secondsSinceInteraction > 180 || late

        var axis: CGFloat = Bool.random() ? 1 : -1
        if ctx.axisFraction < 0.12 { axis = 1 }
        if ctx.axisFraction > 0.88 { axis = -1 }

        var options: [(weight: Double, decision: Decision)] = [
            (6, Decision(action: .idle, duration: .random(in: 2...5))),
            (10, Decision(action: .walk(axis: axis), duration: .random(in: 2...7))),
            (1.5, Decision(action: .happy, duration: 1.5)),
            (2, Decision(action: .stretch, duration: 2.4)),
            (1.5, Decision(action: .spin, duration: 0.9)),
            (1.5, Decision(action: .dance, duration: 4)),
            (2.5, Decision(action: .lookAround, duration: 3)),
            (1.5, Decision(action: .zoomies, duration: 3.5))
        ]
        if ctx.cursorDistance < 500 {
            options.append((4, Decision(action: .chase, duration: .random(in: 3...6))))
        }
        if sleepy {
            options.append((6, Decision(action: .sleep, duration: .random(in: 8...20))))
        }
        if ctx.platformAbove && ctx.surface == .floor {
            options.append((3, Decision(action: .leap, duration: 2)))
        }

        let total = options.reduce(0) { $0 + $1.weight }
        var roll = Double.random(in: 0..<total)
        for o in options {
            roll -= o.weight
            if roll < 0 { return o.decision }
        }
        return options[0].decision
    }
}
