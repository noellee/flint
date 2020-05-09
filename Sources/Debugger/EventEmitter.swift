import Foundation

public class EventEmitter<E: Hashable> {
  public typealias EventHandler = () -> Void

  private var handlers: [E: EventHandler] = [:]

  init() {}

  func emit(_ event: E) {
    handlers[event]?()
  }

  public func on(event: E, _ handler: @escaping EventHandler) {
    handlers[event] = handler
  }
}
