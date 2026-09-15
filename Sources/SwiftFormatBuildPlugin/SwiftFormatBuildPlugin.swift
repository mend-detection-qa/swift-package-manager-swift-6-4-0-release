// Minimal build tool plugin stub.
// Real build tool plugins conform to BuildToolPlugin.
import PackagePlugin

@main
struct SwiftFormatBuildPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) async throws -> [Command] {
        []
    }
}
