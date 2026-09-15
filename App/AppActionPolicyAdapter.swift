import ContextCoreFFIKit
import ContextCoreKit
import DaylineProductKit

struct AppActionPolicyAdapter: ExternalActionPolicyEvaluating {
  private let bridge: RustContextBridge

  init(bridge: RustContextBridge = RustContextBridge()) {
    self.bridge = bridge
  }

  func evaluate(_ proposal: ActionProposalDocument) throws -> ExternalActionEvaluation {
    let evaluation = try bridge.evaluateAction(proposal)
    let decision =
      switch evaluation.decision {
      case .allow: ExternalActionDecision.allow
      case .ask: ExternalActionDecision.ask
      case .deny: ExternalActionDecision.deny
      }
    return ExternalActionEvaluation(decision: decision, reason: evaluation.reason)
  }
}
