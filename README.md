# Swigo

Go concurrency primitives for Swift. 

<table>
<tr><th> 

![Swift](https://skillicons.dev/icons?i=swift)</th>
<th>
 
 ![Go](https://skillicons.dev/icons?i=go)</th>
</tr>
<tr><td> 

```swift
let msg = Chan<String>()
let done = Chan<Bool>()
let exit = Chan<Bool>()

go {
    var isDone = false
    while !isDone {
        select {
            rx(msg) { message in
                print(message!)
            }
            rx(done) {
                isDone = true
                exit <- true
            }
        }
    }
}

msg <- "Swift"
msg <- "❤️"
msg <- "Go"
done.close()
<-exit
```
</td><td>


```go
msg := make(chan string)
done := make(chan bool)
exit := make(chan bool)

go func() {

    for {
        select {
        case message := <-msg:
            fmt.Println(message)

        case <-done:
            exit <- true
            return

        }
    }
}()

msg <- "Swift"
msg <- "❤️"
msg <- "Go"
close(done)
<-exit
```
</td></tr>
</table>

## About

This repo is an experimental library to bring go-style concurrency primitives to Swift. The goal is to bring as close to 1:1 API support in Swift. Do not expect comparabile performance or reliability. Swift does not have a runtime similar to go, and thus "goroutines" are just OS threads managed by GCD's global queue. 

## Usage

1. Add `https://github.com/gh123man/Swigo` as a swift package dependency to your project. 
2. `import Swigo` and have fun!

## Documentation 

### Range over chan

In Swift, `Chan` implements the `Sequence` and `IteratorProtocol` protocols. So you can enumerate a channel until it's closed. 


<table>
<tr><th> 

![Swift](https://skillicons.dev/icons?i=swift)</th>
<th>
 
 ![Go](https://skillicons.dev/icons?i=go)</th>
</tr>
<tr style="vertical-align: top;"><td> 

```swift
let msg = Chan<String>()
let done = Chan<Bool>()

go {
    for m in msg {
        print(m)
    }
    print("closed")
    done <- true
}

msg <- "hi"
msg.close()
<-done
```
</td><td>


```go
msg := make(chan string)
done := make(chan bool)

go func() {
    for m := range msg {
        fmt.Println(m)
    }
    fmt.Println("closed")
    done <- true
}()

msg <- "hi"
close(msg)
<-done
```
</td></tr>
</table>

### Buffered Channels

Swigo Channels can be buffered or unbuffered


<table>
<tr><th> 

![Swift](https://skillicons.dev/icons?i=swift)</th>
<th>
 
 ![Go](https://skillicons.dev/icons?i=go)</th>
</tr>
<tr style="vertical-align: top;"><td> 

```swift
let count = Chan<Int>(buffer: 100)

for i in (0..<100) {
    count <- i
}
count.close()


let sum = count.reduce(0) { sum, next in
    sum + next
}
print(sum)
```
</td><td>


```go
count := make(chan int, 100)

for i := 0; i < 100; i++ {
    count <- i
}
close(count)

sum := 0
for v := range count {
    sum += v
}
fmt.Println(sum)
```
</td></tr>
</table>

Also `map`, `reduce`, etc work on Swigo channels too thanks to `Sequence`!


### Select 

Swift has reserve words for `case` and `default` and the operator support is not flexible enough to support inline channel operations in the select statement. So instead they are implemented as follows: 

<table>
<tr><th> 

![Swift](https://skillicons.dev/icons?i=swift)</th>
<th>
 
 ![Go](https://skillicons.dev/icons?i=go)</th>
</tr>

<tr style="vertical-align: top;">
<td> 

`rx(c)`
</td><td>

`case <-c:`
</td>
</tr>

<tr>
<td> 

`rx(c) { v in ... }`
</td><td>

`case v := <-c: ...`
</td>
</tr>

<tr>
<td> 

`tx(c, "foo")`
</td><td>

`case c <- "foo":`
</td>
</tr>

<tr>
<td> 

`none { ... }`
</td><td>

`default: ...`
</td>
</tr>

</table>

**Gotcha:** You cannot `return` from `none` to break an oter loop in Swift since it's inside a closure. To break a loop surrounding a `select`, you must explicitly set some control variable (ex: `while !done` and `done = true`)

#### Examples

<table>
<tr>
<th> 
Example
<th> 

![Swift](https://skillicons.dev/icons?i=swift)
</th>
<th>
 
 ![Go](https://skillicons.dev/icons?i=go)
</th>
</tr>


<tr>
<td> 


`chan receive`
</td>
<td> 

```swift
let a = Chan<String>(buffer: 1)
a <- "foo"

select {
    rx(a) {
        print($0!) 
    }
    none {
        print("Not called")
    }
}
```
</td><td>


```go
a := make(chan string, 1)
a <- "foo"

select {
case av := <-a:
    fmt.Println(av)

default:
    fmt.Println("Not called")

}
```
</td></tr>

<tr>
<td> 

`chan send`
</td>
<td> 

```swift
let a = Chan<String>(buffer: 1)

select {
    tx(a, "foo")
    none {
        print("Not called")
    }
}
print(<-a)

```
</td><td>


```go
a := make(chan string, 1)

select {
case a <- "foo":
default:
    fmt.Println("Not called")
}

fmt.Println(<-a)

```
</td></tr>

<tr>
<td> 

`default`
</td>
<td> 

```swift
let a = Chan<Bool>()

select {
    rx(a)
    none {
        print("Default case!")
    }
}
```
</td><td>


```go
a := make(chan bool)

select {
case <-a:
default:
    fmt.Println("Default case!")
}

```
</td></tr>
</table> 

### Closing Channels

A `Chan` can be closed. In Swift, the (LHS) `<-` operator returns `T?` because a channel read will return `nil` when the channel is closed. If you try to write to a closed channel, a `fatalError` will be thrown. 

Because of Swift's optional semantics and strict type system, it is not always convenient to have to unwrap an optional every time you read a channel. To solve this you can use `OpenChan`. 

### OpenChan

Unlike `Chan`, `OpenChan` cannot be closed - it is always open. As a result `<-` will return a `T`. This has some other side effects however: 

- If reading using the `Sequence` protocol, `next() -> T?` will never return `nil` and thus your loop will never terminate. 
- There is no way to break a blocking channel read without writing to the channel. 

#### Usage

```swift 
let c = OpenChan<String>()
c <- "hi"
let result: String = <-c // Not an optional
```