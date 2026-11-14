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
    case climbEdge             // walk to the nearest screen edge on purpose and climb it
    case dizzy                 // spiral eyes after the cursor is shaken at it
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
    let canClimb: Bool                 // on the Dock floor with climbing enabled
    let media: MediaActivity           // what is playing on the Mac
    let userAway: Bool                 // nobody has touched the Mac for a while
}

/// The seam for future AI: anything that can pick the next Decision.
/// Today: `RuleBrain`. Later: an `LLMBrain` that calls a model.
protocol Brain {
    func nextDecision(_ ctx: PetContext) -> Decision
}

/// Weighted-random behavior, no AI.
struct RuleBrain: Brain {
    func nextDecision(_ ctx: PetContext) -> Decision {
        if ctx.userAway { return Decision(action: .sleep, duration: 30) }

        let late = ctx.hour >= 23 || ctx.hour < 6
        let sleepy = ctx.secondsSinceInteraction > 180 || late

        var axis: CGFloat = Bool.random() ? 1 : -1
        if ctx.axisFraction < 0.12 { axis = 1 }
        if ctx.axisFraction > 0.88 { axis = -1 }

        func d(_ a: PetAction, _ lo: TimeInterval, _ hi: TimeInterval) -> Decision {
            Decision(action: a, duration: .random(in: lo...hi))
        }
        var o: [(Double, Decision)] = []

        switch ctx.media {
        case .call:
            // On a call: stay quiet and still.
            o = [(10, d(.idle, 4, 8)), (2, d(.lookAround, 2, 3))]
            if sleepy { o.append((2, d(.sleep, 10, 20))) }

        case .video:
            // Watching along.
            o = [(9, d(.idle, 5, 10)), (2, d(.lookAround, 2, 3)), (1, d(.stretch, 2, 3))]
            if sleepy { o.append((3, d(.sleep, 10, 20))) }

        case .music, .other:
            let fan: Double = ctx.media == .music ? 9 : 4
            o = [(fan, d(.dance, 6, 10)), (3, d(.idle, 2, 4)), (4, d(.walk(axis: axis), 2, 6)),
                 (2, d(.happy, 1.5, 2)), (1.5, d(.spin, 0.9, 0.9)), (1, d(.zoomies, 3, 4))]
            if ctx.cursorDistance < 500 { o.append((2, d(.chase, 3, 6))) }

        case .none:
            if ctx.surface == .floor || ctx.surface == .air {
                o = [(6, d(.idle, 2, 5)), (10, d(.walk(axis: axis), 2, 7)), (1.5, d(.happy, 1.5, 1.5)),
                     (2, d(.stretch, 2.4, 2.4)), (1.5, d(.spin, 0.9, 0.9)), (1.5, d(.dance, 4, 4)),
                     (2.5, d(.lookAround, 3, 3)), (1.5, d(.zoomies, 3.5, 3.5))]
            } else {
                // Clinging to an edge: it's mostly busy climbing around.
                o = [(3, d(.idle, 2, 4)), (14, d(.walk(axis: axis), 3, 9)), (1.5, d(.lookAround, 2, 3)),
                     (1, d(.happy, 1.5, 1.5)), (1, d(.stretch, 2.4, 2.4))]
            }
            if ctx.cursorDistance < 500 { o.append((4, d(.chase, 3, 6))) }
            if sleepy { o.append((6, d(.sleep, 8, 20))) }
        }

        if ctx.platformAbove && ctx.surface == .floor && ctx.media != .call {
            o.append((3, Decision(action: .leap, duration: 2)))
        }
        if ctx.canClimb && ctx.media != .call && ctx.media != .video {
            o.append((3.5, d(.climbEdge, 10, 14)))
        }

        let total = o.reduce(0) { $0 + $1.0 }
        var roll = Double.random(in: 0..<total)
        for (w, dec) in o {
            roll -= w
            if roll < 0 { return dec }
        }
        return o[0].1
    }
}
