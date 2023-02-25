import Foundation

class ChanInternal<T> {
    class Sender<T> {
        private let sema = DispatchSemaphore(value: 0)
        private var _value: T
        
        init(value: T) {
            self._value = value
        }
        
        var value: T {
            get {
                sema.signal()
                return _value
            }
        }
        
        func wait() {
            sema.wait()
        }
    }
    
    class Receiver<T> {
        private let sema = DispatchSemaphore(value: 0)
        private var _value: T!
        
        var value: T {
            set {
                _value = newValue
                sema.signal()
            }
            get {
                sema.wait()
                return _value
            }
        }
    }

    var lock = NSLock()
    let capacity: Int
    var closed = false
    var buffer = [T]()
    var sendQ = [Sender<T>]()
    var recvQ = [Receiver<T>]()

    init (buffer: Int = 0) {
        self.capacity = buffer
    }

    var count: Int {
        return buffer.count
    }
    
    var selectWaiter: DispatchSemaphore?
    
    var isClosed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return closed
    }
    
    func receiveOrListen(_ sema: DispatchSemaphore) -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        if let val = nonBlockingReceive() {
            return val
        }
        
        if closed {
            return nil
        }
        
        self.selectWaiter = sema
        return nil
    }
    
    func sendOrListen(_ sema: DispatchSemaphore, value: T) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        if nonBlockingSend(value) {
            return true
        }
        
        self.selectWaiter = sema
        return false
    }
    
    func removeWaiter() {
        lock.lock()
        defer { lock.unlock() }
        self.selectWaiter = nil
    }
    
    private func nonBlockingSend(_ value: T) -> Bool {
        if let recvW = recvQ.popFirst() {
            recvW.value = value
            return true
        }

        if self.buffer.count < self.capacity {
            self.buffer.append(value)
            return true
        }
        return false
    }
    

    func send(_ value: T) {
        lock.lock()
        selectWaiter?.signal()
        
        if closed {
            fatalError("Cannot send on a closed channel")
        }
        
        if nonBlockingSend(value) {
            lock.unlock()
            return
        }

        let sender = Sender<T>(value: value)
        sendQ.append(sender)
        lock.unlock()
        sender.wait()
    }
    
    private func nonBlockingReceive() -> T? {
        if let val = buffer.popFirst() {
            if let sendW = sendQ.popFirst() {
                buffer.append(sendW.value)
            }
            return val
        }
        return sendQ.popFirst()?.value
    }

    func receive() -> T? {
        lock.lock()
        selectWaiter?.signal()

        if let val = nonBlockingReceive() {
            lock.unlock()
            return val
        }
        
        if closed {
            return nil
        }

        let receiver = Receiver<T>()
        recvQ.append(receiver)
        lock.unlock()
        return receiver.value
    }
    
    func close() {
        lock.lock()
        defer { lock.unlock() }
        closed = true
    }
}



