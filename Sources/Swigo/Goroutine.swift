import Foundation

public func go(_ routine: @escaping () -> ()) {
    DispatchQueue.global().async {
        routine()
    }
}

public func go(_ routine: @escaping @autoclosure () -> ()) {
    go(routine)
}
