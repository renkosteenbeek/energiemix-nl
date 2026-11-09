import SwiftUI
import UIKit

struct ScrubSurface: UIViewRepresentable {
    let onTap: (CGFloat) -> Void
    let onScrub: (CGFloat) -> Void
    let onScrubEnd: (CGFloat?) -> Void
    let onPinch: (_ zoomIn: Bool, _ x: CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        pan.maximumNumberOfTouches = 1
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinch.delegate = context.coordinator
        context.coordinator.pan = pan
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pinch)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.surface = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(surface: self)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var surface: ScrubSurface
        weak var pan: UIPanGestureRecognizer?
        private var pinchHandled = false

        init(surface: ScrubSurface) {
            self.surface = surface
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            surface.onTap(recognizer.location(in: recognizer.view).x)
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let x = recognizer.location(in: recognizer.view).x
            switch recognizer.state {
            case .began, .changed: surface.onScrub(x)
            case .ended: surface.onScrubEnd(x)
            case .cancelled, .failed: surface.onScrubEnd(nil)
            default: break
            }
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                pinchHandled = false
                if let pan, pan.state == .began || pan.state == .changed {
                    pan.isEnabled = false
                    pan.isEnabled = true
                }
            case .changed:
                guard !pinchHandled else { return }
                let x = recognizer.location(in: recognizer.view).x
                if recognizer.scale < 0.7 {
                    pinchHandled = true
                    surface.onPinch(false, x)
                } else if recognizer.scale > 1.4 {
                    pinchHandled = true
                    surface.onPinch(true, x)
                }
            default:
                pinchHandled = false
            }
        }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer, pan === self.pan else { return true }
            let velocity = pan.velocity(in: pan.view)
            return pan.numberOfTouches == 1 && abs(velocity.x) > abs(velocity.y)
        }

        func gestureRecognizer(
            _ recognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            recognizer is UIPinchGestureRecognizer || other is UIPinchGestureRecognizer
        }
    }
}
