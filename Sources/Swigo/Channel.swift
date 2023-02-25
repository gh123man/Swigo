import Foundation

infix operator <- :AssignmentPrecedence
public func <- <T>(c: OpenChan<T>, value: T) {
    c.send(value)
}
public func <- <T>(value: inout T, chan: OpenChan<T>) {
    value = chan.receive()
}
public func <- <T>(c: Chan<T>, value: T) {
    c.send(value)
}
public func <- <T>(value: inout T?, chan: Chan<T>) {
    value = chan.receive()
}

prefix operator <-
@discardableResult public prefix func <- <T>(chan: OpenChan<T>) -> T {
    return chan.receive()
}
@discardableResult public prefix func <- <T>(chan: Chan<T>) -> T? {
    return chan.receive()
}

public class Chan<T> {
    let inner: ChanInternal<T>
    
    public init (buffer: Int = 0) {
        self.inner = ChanInternal<T>(buffer: buffer)
    }
    
    func receiveOrListen(_ sema: DispatchSemaphore) -> T? {
        return inner.receiveOrListen(sema)
    }
    
    func sendOrListen(_ sema: DispatchSemaphore, value: T) -> Bool {
        return inner.sendOrListen(sema, value: value)
    }
    
    public func send(_ value: T) {
        inner.send(value)
    }
    
    public func receive() -> T? {
        return inner.receive()
    }
    
    public func close() {
        inner.close()
    }
}

extension Chan: Sequence, IteratorProtocol {
    public typealias Element = T
    
    public func makeIterator() -> Chan {
        return self
    }
    
    public func next() -> T? {
        return <-self
    }
}

public class OpenChan<T> {
    let inner: ChanInternal<T>
    
    public init (buffer: Int = 0) {
        self.inner = ChanInternal<T>(buffer: buffer)
    }
    
    func receiveOrListen(_ sema: DispatchSemaphore) -> T? {
        return inner.receiveOrListen(sema)
    }
    
    func sendOrListen(_ sema: DispatchSemaphore, value: T) -> Bool {
        return inner.sendOrListen(sema, value: value)
    }
    
    public func send(_ value: T) {
        inner.send(value)
    }
    
    public func receive() -> T {
        // receive can never return nil if the channel cannot ever be closed
        return inner.receive()!
    }
}

extension OpenChan: Sequence, IteratorProtocol {
    public typealias Element = T
    
    public func makeIterator() -> OpenChan {
        return self
    }
    
    public func next() -> T? {
        return <-self
    }
}
