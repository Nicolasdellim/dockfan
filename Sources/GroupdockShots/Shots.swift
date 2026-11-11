import AppKit
import Groupdock

@main
struct Shots {
    @MainActor static func main() throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.first == "--self-test" {
            let failures = GroupdockDevelopment.selfTest()
            print(failures.isEmpty ? "self-test: OK" : "self-test FAILED:\n" + failures.joined(separator: "\n"))
            exit(failures.isEmpty ? 0 : 1)
        }
        let out = URL(fileURLWithPath: arguments.first ?? "shots/editor")
        try GroupdockDevelopment.renderEditor(to: out)
        print("rendered to \(out.path)")
    }
}
