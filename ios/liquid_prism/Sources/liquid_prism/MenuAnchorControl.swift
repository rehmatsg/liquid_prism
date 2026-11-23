import UIKit

final class MenuAnchorControl: UIButton {
  var attachmentUnitPoint: CGPoint?

  var onWillPresent: (() -> Void)?
  var onWillDismiss: (() -> Void)?

  var presentedMenu: UIMenu? {
    get { menu }
    set { menu = newValue }
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    showsMenuAsPrimaryAction = true
    isOpaque = false
    backgroundColor = .clear
    setTitle(nil, for: .normal)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  override func menuAttachmentPoint(for configuration: UIContextMenuConfiguration) -> CGPoint {
    if let unit = attachmentUnitPoint {
      return CGPoint(
        x: bounds.minX + unit.x * bounds.width,
        y: bounds.minY + unit.y * bounds.height
      )
    }
    return super.menuAttachmentPoint(for: configuration)
  }

  override func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    willDisplayMenuFor configuration: UIContextMenuConfiguration,
    animator: (any UIContextMenuInteractionAnimating)?
  ) {
    super.contextMenuInteraction(
      interaction,
      willDisplayMenuFor: configuration,
      animator: animator
    )
    onWillPresent?()
  }

  override func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    willEndFor configuration: UIContextMenuConfiguration,
    animator: (any UIContextMenuInteractionAnimating)?
  ) {
    super.contextMenuInteraction(
      interaction,
      willEndFor: configuration,
      animator: animator
    )
    onWillDismiss?()
  }
}
