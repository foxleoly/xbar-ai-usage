import SwiftUI

public struct AgentUsageBridgeRoot: View {
    @StateObject private var store = BridgeStore()

    public init() {}

    public var body: some View {
        BridgeHomeView(store: store)
            .task {
                store.startBluetooth()
            }
    }
}
