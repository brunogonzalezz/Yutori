import SwiftUI
import UIKit

struct SessionTimeRuler: UIViewRepresentable {
    @Binding var value: Int
    let limits: ClosedRange<Int>

    func makeUIView(context: Context) -> TimeRulerView { TimeRulerView() }

    func updateUIView(_ view: TimeRulerView, context: Context) {
        view.onSelection = { value = $0 }
        view.configure(value: value, limits: limits)
    }
}

final class TimeRulerView: UIView, UIScrollViewDelegate {
    private let scroll = UIScrollView()
    private let ticks = UIView()
    private let indicator = UIView()
    private let feedback = UISelectionFeedbackGenerator()
    private var limits = 0...0
    private var selected = 0
    private var previousWidth: CGFloat = 0
    private var needsPositionRestore = true
    private var isUpdatingLayout = false
    private let step: CGFloat = 12
    private var tickLayers: [CALayer] = []
    var onSelection: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        scroll.delegate = self
        scroll.showsHorizontalScrollIndicator = false
        scroll.bounces = false
        scroll.decelerationRate = .normal
        scroll.contentInsetAdjustmentBehavior = .never
        addSubview(scroll)
        scroll.addSubview(ticks)
        indicator.backgroundColor = AppTheme.inkColor
        indicator.layer.cornerRadius = 3
        indicator.isUserInteractionEnabled = false
        addSubview(indicator)
        isAccessibilityElement = true
        accessibilityLabel = AppLanguage.localized("Adjust time in minutes")
        accessibilityTraits = .adjustable
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(value: Int, limits: ClosedRange<Int>) {
        let changed = self.limits != limits || tickLayers.isEmpty
        self.limits = limits
        if changed {
            tickLayers.forEach { $0.removeFromSuperlayer() }
            tickLayers = limits.map { _ in
                let layer = CALayer()
                layer.backgroundColor = AppTheme.inkColor.cgColor
                ticks.layer.addSublayer(layer)
                return layer
            }
        }
        if changed || value != selected {
            selected = value
            needsPositionRestore = true
        }
        accessibilityValue = AppLanguage.formatted("%@ minutes", String(value))
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        isUpdatingLayout = true
        defer { isUpdatingLayout = false }
        scroll.frame = bounds
        let width = CGFloat(limits.count - 1) * step + bounds.width
        ticks.frame = CGRect(x: 0, y: 0, width: width, height: bounds.height)
        scroll.contentSize = ticks.bounds.size
        indicator.frame = CGRect(x: bounds.midX - 3, y: bounds.midY - 25, width: 6, height: 50)
        if needsPositionRestore || previousWidth != bounds.width {
            needsPositionRestore = false
            previousWidth = bounds.width
            scroll.contentOffset = CGPoint(x: CGFloat(selected - limits.lowerBound) * step, y: 0)
        }
        updateTicks()
    }

    private func updateTicks() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let center = scroll.contentOffset.x + bounds.midX
        for (index, layer) in tickLayers.enumerated() {
            let x = bounds.midX + CGFloat(index) * step
            let distance = abs(x - center) / step
            layer.isHidden = distance * step > bounds.width / 2 + step
            guard !layer.isHidden else { continue }
            let prominence = max(0, 1 - distance / 3)
            let width = 2.5 + 3.5 * prominence
            let height = 26 + 24 * prominence
            layer.frame = CGRect(x: x - width / 2, y: bounds.midY - height / 2, width: width, height: height)
            layer.cornerRadius = width / 2
            layer.opacity = Float(0.25 + 0.45 * prominence)
        }
        CATransaction.commit()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { feedback.prepare() }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateTicks()
        guard !isUpdatingLayout, !needsPositionRestore,
              scrollView.isDragging || scrollView.isDecelerating else { return }
        let next = min(limits.upperBound, max(limits.lowerBound,
            limits.lowerBound + Int((scrollView.contentOffset.x / step).rounded())))
        guard next != selected else { return }
        selected = next
        accessibilityValue = AppLanguage.formatted("%@ minutes", String(next))
        if scrollView.isDragging || scrollView.isDecelerating {
            feedback.selectionChanged()
            onSelection?(next)
        }
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint,
                                  targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let index = (targetContentOffset.pointee.x / step).rounded()
        targetContentOffset.pointee.x = min(CGFloat(limits.count - 1) * step, max(0, index * step))
    }

    override func accessibilityIncrement() { adjust(by: 1) }
    override func accessibilityDecrement() { adjust(by: -1) }
    private func adjust(by amount: Int) {
        let next = min(limits.upperBound, max(limits.lowerBound, selected + amount))
        onSelection?(next)
        configure(value: next, limits: limits)
    }
}
