import Foundation

public protocol SelectHandler {
    func handle(_ sm: DispatchSemaphore) -> Bool
}

struct RxOpenHandler<T>: SelectHandler {
    private var chan: ChanInternal<T>
    private let outFunc: (T) -> ()
    
    init(chan: ChanInternal<T>, outFunc: @escaping (T) -> ()) {
        self.chan = chan
        self.outFunc = outFunc
    }
    
    func handle(_ sm: DispatchSemaphore) -> Bool {
        if let val = chan.receiveOrListen(sm) {
            outFunc(val)
            return true
        }
        return false
    }
}

struct RxHandler<T>: SelectHandler {
    private var chan: ChanInternal<T>
    private let outFunc: (T?) -> ()
    
    init(chan: ChanInternal<T>, outFunc: @escaping (T?) -> ()) {
        self.chan = chan
        self.outFunc = outFunc
    }
    
    func handle(_ sm: DispatchSemaphore) -> Bool {
        if let val = chan.receiveOrListen(sm) {
            outFunc(val)
            return true
        }
        if chan.isClosed {
            outFunc(nil)
            return true
        }
        return false
    }
}

struct NoneHandler: SelectHandler {
    private let handler: () -> ()
    
    init(handler: @escaping () -> ()) {
        self.handler = handler
    }
    
    func handle(_ sm: DispatchSemaphore) -> Bool {
        handler()
        return true
    }
}

struct TxHandler<T>: SelectHandler {
    private var chan: ChanInternal<T>
    private let val: T
    
    init(chan: ChanInternal<T>, val: T) {
        self.chan = chan
        self.val = val
    }
    
    func handle(_ sm: DispatchSemaphore) -> Bool {
        return chan.sendOrListen(sm, value: val)
    }
}

@resultBuilder
public struct SelectCollector {
    public static func buildBlock(_ handlers: SelectHandler...) {
        while true {
            let sm = DispatchSemaphore(value: 0)
            if handle(sm, handlers: handlers) {
                return
            }
            sm.wait()
        }
    }
    
    static func handle(_ sm: DispatchSemaphore, handlers: [SelectHandler]) -> Bool {
        var defaultCase: NoneHandler?
        
        for handler in handlers.shuffled() {
            if let noneHnadler = handler as? NoneHandler {
                defaultCase = noneHnadler
            } else if handler.handle(sm) {
                return true
            }
        }
        return defaultCase?.handle(sm) ?? false
    }
}

public func select(@SelectCollector cases: () -> ()) {
    cases()
}

public func rx<T>(_ chan: OpenChan<T>, _ outFunc: @escaping (T) -> ()) -> SelectHandler {
    return RxOpenHandler(chan: chan.inner, outFunc: outFunc)
}

public func rx<T>(_ chan: OpenChan<T>, _ outFunc: @escaping () -> ()) -> SelectHandler {
    return RxOpenHandler(chan: chan.inner, outFunc: { _ in outFunc() })
}

public func rx<T>(_ chan: OpenChan<T>) -> SelectHandler {
    return RxOpenHandler(chan: chan.inner, outFunc: { _ in })
}

public func tx<T>(_ chan: OpenChan<T>, _ val: T) -> SelectHandler {
    return TxHandler(chan: chan.inner, val: val)
}

public func rx<T>(_ chan: Chan<T>, _ outFunc: @escaping (T?) -> ()) -> SelectHandler {
    return RxHandler(chan: chan.inner, outFunc: outFunc)
}

public func rx<T>(_ chan: Chan<T>, _ outFunc: @escaping () -> ()) -> SelectHandler {
    return RxHandler(chan: chan.inner, outFunc: { _ in outFunc() })
}

public func rx<T>(_ chan: Chan<T>) -> SelectHandler {
    return RxHandler(chan: chan.inner, outFunc: { _ in })
}

public func tx<T>(_ chan: Chan<T>, _ val: T) -> SelectHandler {
    return TxHandler(chan: chan.inner, val: val)
}

public func none(handler: @escaping () -> ()) -> SelectHandler {
    return NoneHandler(handler: handler)
}

