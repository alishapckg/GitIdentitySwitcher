import SwiftUI
import AppKit

/// Owns the custom commit window directly, so it opens reliably from the
/// menu bar popover and always floats above other apps.
@MainActor
final class CommitWindowController: NSObject, NSWindowDelegate {
  static let shared = CommitWindowController()

  private var window: NSWindow?
  private var hostingController: CommitHostingController?

  func show(repoManager: RepoManager, scheduler: ScheduledCommitManager) {
    scheduler.refresh()

    if let window {
      present(window)
      return
    }

    let root = AnyView(
      CustomCommitView()
        .environmentObject(repoManager)
        .environmentObject(scheduler)
    )

    let hosting = CommitHostingController(rootView: root)
    let window = NSWindow(contentViewController: hosting)
    window.title = "Custom Commit"
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.isReleasedWhenClosed = false
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.hidesOnDeactivate = false
    window.delegate = self
    window.center()

    hosting.onContentSizeChange = { [weak window] size in
      guard let window, size.width > 0, size.height > 0 else { return }
      var frame = window.frame
      let contentRect = window.contentRect(forFrameRect: frame)
      guard abs(contentRect.width - size.width) > 0.5
        || abs(contentRect.height - size.height) > 0.5 else { return }
      let top = frame.maxY
      frame.size = window.frameRect(forContentRect: NSRect(origin: .zero, size: size)).size
      frame.origin.y = top - frame.height
      window.setFrame(frame, display: true)
    }

    self.hostingController = hosting
    self.window = window

    window.contentView?.layoutSubtreeIfNeeded()
    let fittingSize = hosting.view.fittingSize
    if fittingSize.width > 0, fittingSize.height > 0 {
      window.setContentSize(fittingSize)
    }

    present(window)
  }

  private func present(_ window: NSWindow) {
    window.orderFrontRegardless()
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    // Re-assert after the menu bar popover finishes closing.
    DispatchQueue.main.async { [weak window] in
      guard let window else { return }
      window.orderFrontRegardless()
      window.makeKey()
      NSApp.activate(ignoringOtherApps: true)
    }
  }
}

private final class CommitHostingController: NSHostingController<AnyView> {
  var onContentSizeChange: ((CGSize) -> Void)?

  override func viewDidLayout() {
    super.viewDidLayout()
    let size = view.fittingSize
    guard size.width > 0, size.height > 0 else { return }
    onContentSizeChange?(size)
  }
}
