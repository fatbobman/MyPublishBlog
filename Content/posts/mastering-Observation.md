---
date: 2023-06-19 08:12
description: 在 WWDC 2023 中，苹果介绍了 Swift 标准库中的新成员：Observation 框架。它的出现有望缓解开发者长期面临的 SwiftUI 视图无效更新问题。本文将采取问答的方式，全面而详尽地探讨 Observation 框架，内容涉及其产生原因、使用方法、工作原理以及注意事项等。
tags: SwiftUI,WWDC23
title: 深度解读 Observation —— SwiftUI 性能提升的新途径 
image: images/observation-study.jpg
mediumURL: https://medium.com/p/f299831c664b
---
在 WWDC 2023 中，苹果介绍了 Swift 标准库中的新成员：Observation 框架。它的出现有望缓解开发者长期面临的 SwiftUI 视图无效更新问题。本文将采取问答的方式，全面而详尽地探讨 Observation 框架，内容涉及其产生原因、使用方法、工作原理以及注意事项等。

## 为什么要创建 Observation 框架

在 Swift 5.9 版本之前，苹果没有为开发者提供一种统一高效的机制来观察引用类型属性对变化。KVO 仅限于 NSObject 子类使用，Combine 无法提供属性级别的精确观察，而且两者都无法实现跨平台支持。

此外，在 SwiftUI 中，引用类型的数据源（Source of Truth）采用了基于 Combine 框架的 ObservableObject 协议实现。这导致在 SwiftUI 中，极易产生了大量不必要的视图刷新，从而影响 SwiftUI 应用的性能。

为了改善这些限制，Swift 5.9 版本推出了 Observation 框架。相比现有的 KVO 和 Combine，它具有以下优点：

1. 适用于所有 Swift 引用类型，不限于 NSObject 子类，提供跨平台支持。
2. 提供属性级别的精确观察，且无需对可观察属性进行特别注解。
3. 减少 SwiftUI 中对视图的无效更新，提高应用性能。

## 如何声明可观察对象

使用 Combine 框架，我们可以这样声明一个可被观察的引用类型：

```swift
class Store: ObservableObject {
    @Published var firstName: String
    @Published var lastName: String
    var fullName: String {
        firstName + " " + lastName
    }

    @Published private var count: Int = 0
    
    init(firstName: String, lastName: String, count: Int) {
        self.firstName = firstName
        self.lastName = lastName
        self.count = count
    }
}
```

当实例的 firstName、lastName 以及 count 发生变化时，`@Published` 会通过 `objectWillChange`( ObjectWillChangePublisher ) 发送通知，告诉所有订阅者，当前的实例即将发生变化。

使用 Observation 框架，我们将采用完全不同的声明方式：

```swift
@Observable
class Store {
    var firstName: String = "Yang"
    var lastName: String = "Xu"
    var fullName: String {
        firstName + " " + lastName
    }

    private var count: Int = 0

    init(firstName: String, lastName: String, count: Int) {
        self.firstName = firstName
        self.lastName = lastName
        self.count = count
    }
}
```

- 在类的声明前添加 `@Observalbe` 标注，不需要指定 Store 类型要遵守某个协议。
- 不需要通过 `@Published` 来标注能引发通知的属性，没有特别标注的存储属性都可以被观察
- 可以观察计算属性（ 在例中，fullName 也可被观察 ）
- 对于不想被观察的属性，需要在其前方标注 `@ObservationIgnored`

```swift
// count 不可被观察
@ObservationIgnored
private var count: Int = 0
```

- 所有的属性必须有字面默认值，即使提供了自定义的 init 方法

相较于基于 Combine 的声明方式，Observation 让可观察对象的声明更加简洁、更加符合直觉，同时也提供了对计算属性的观察支持。

```responser
id:1
```

## @Observable 做了哪些工作

与其他常见的使用 `@` 开头的关键字不同（例如`@Published` 属性包装器和`@available` 条件编译），`@Observable` 在这里表示的是宏（Macro）。

宏（Macro）是 Swift 5.9 中新增的一项功能。它允许开发者在编译时操纵和处理 Swift 代码。开发者可以提供一段宏定义，该定义会在编译器编译源代码时执行，并对源代码进行修改、添加或删除等操作。

在 Xcode 15 中，在`@Observable` 处点击鼠标右键，选择“Expand Macro”操作。通过这步操作，我们可以看到 `@Observable` 宏为我们生成的代码：

![expend-macro-demo-2_2023-06-19_08.38.08.2023-06-19 08_38_52](https://cdn.fatbobman.com/expend-macro-demo-2_2023-06-19_08.38.08.2023-06-19%2008_38_52.gif)

```swift
@Observable
class Store {
    @ObservationTracked
    var firstName: String = "Yang" {
        get {
            access(keyPath: \.firstName)
            return _firstName
        }

        set {
            withMutation(keyPath: \.firstName) {
                _firstName = newValue
            }
        }
    }

    @ObservationTracked // 可以进一步展开
    var lastName: String = "Xu"
    var fullName: String {
        firstName + " " + lastName
    }

    @ObservationIgnored
    private var count: Int = 0

    init(firstName: String, lastName: String, count: Int) {
        self.firstName = firstName
        self.lastName = lastName
        self.count = count
    }

    @ObservationIgnored private let _$observationRegistrar = ObservationRegistrar()

    internal nonisolated func access<Member>(
        keyPath: KeyPath<Store, Member>
    ) {
        _$observationRegistrar.access(self, keyPath: keyPath)
    }

    internal nonisolated func withMutation<Member, T>(
        keyPath: KeyPath<Store, Member>,
        _ mutation: () throws -> T
    ) rethrows -> T {
        try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
    }

    @ObservationIgnored private var _firstName: String = "Yang"

    @ObservationIgnored private var _lastName: String = "Xu"
}

extension Store: Observable {}
```

可以看到，`Observable` 宏对我们原本的声明进行了调整。在 Store 中，声明了一个 ObservationRegistrar 结构，用于维护和管理可观察属性和观察者之间的关系。存储属性被改写为计算属性，原有值被保存在同名但带`_`前缀的版本中。在 get 和 set 方法中，通过 `_$observationRegistrar` 来注册和通知观察者。最后，宏添加了让可观察对象遵守 Observable 协议的代码（Observable 协议类似于 Sendable, 它不提供任何实现，仅起标示作用）。

## 如何在视图中使用可观察对象

### 在视图中声明可观察对象

与遵守 ObservableObject 协议的 Source of Truth 不同，我们会在视图中使用 `@State` 来确保可观察对象的声明周期。

```swift
@Observable
class Store {
   ....
}

struct ContentView: View {
    @State var store = Store()
    var body: some View {
       ...
    }
}
```

### 通过环境在视图树中注入可观察对象

相较于遵守 ObservableObject 协议的 Source of Truth，用 Observation 框架声明的可观察对象拥有更加多样和灵活的环境注入选项。

- 通过 environment 注入实例

```swift
@Observable
class Store {
   ....
}

struct ObservationTest: App {
    @State var store = Store()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}

struct ContentView: View {
    @Environment(Store.self) var store // 在视图中通过环境注入
    var body: some View {
       ...
    }
}
```

- 通过自定义 EnvironmentKey

```swift
struct StoreKey: EnvironmentKey {
    static var defaultValue = Store()
}

extension EnvironmentValues {
    var store: Store {
        get { self[StoreKey.self] }
        set { self[StoreKey.self] = newValue }
    }
}

struct ContentView: View {
    @Environment(\.store) var store // 在视图中通过环境注入
    var body: some View {
       ...
    }
}
```

- 注入可选值

```swift
struct ObservationTest: App {
    @State var store = Store()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}

struct ContentView: View {
    @Environment(Store.self) var store:Store? // 在视图中注入可选值
    var body: some View {
       if let firstName = store?.firstName  {
                Text(firstName)
       }
    }
}
```

其中，自定义 EnvironmentKey 和注入可选值两者方式都完美的解决了忘记注入后导致的 Preview 崩溃问题。尤其是 EnvironmentKey，让开发者具备了提供默认值的能力。

也许有人会感到困惑，为什么使用 Observation 框架声明的可观察对象的注入方式与值类型类似，而遵守 ObservableObject 协议的引用类型，都需要使用注明了 Object 的方法才能注入（StateObject、EnvironmentObject），这样不会引起混淆吗？

可以预期，在开发 iOS 17+ 应用程序时，通过 Observation 框架声明的可观察对象和遵循 ObservableObject 协议的可观察对象，同时出现的场景将越来越少。因此，在不久后，引用类型和值类型在注入形式上将获得高度统一（ 几乎不会再出现使用 environmentObject 或 StateObject 的场景 ）。

### 在视图中传递可观察对象

```swift
struct ContentView: View {
    @State var store = Store()
    var body: some body {
        SubView(store: store)
    }
}

struct SubView:View {
    let store:Store
    var body: some body {
       ....
    }
}
```

使用 `let` 和 `var` 都可以

### 创建 Binding 类型

Binding 类型为 SwiftUI 提供了实现数据双向绑定的能力。使用 Observation 框架，我们可以通过如下方式创建属性对应的 Binding 类型。

方法一：

```swift
struct ContentView: View {
    @State var store = Store()
    var body: some body {
        SubView(store: store)
    }
}

struct SubView:View {
    @Bindale var store:Store
    var body: some body {
       TextField("",text:$store.name)
    }
}
```

方法二：

```swift
struct SubView:View {
    var store:Store
    var body: some body {
       @Bindable var store = store
       TextField("",text:$store.name)
    }
}
```

方法三：

```swift
struct SubView:View {
    var store:Store
    var name:Binding<String>{
        .init(get: { store.name }, set: { store.name = $0 })
    }
    var body: some body {
       TextField("",text:name)
    }
}
```

## Observation 框架支持低版本的 SwiftUI 吗

不支持。

## 如何观察可观察对象

Observation 框架提供了一个全局函数 `withObservationTracking`。使用此函数，开发者可以跟踪可观察对象的属性是否发生变化。

函数签名：

```swift
func withObservationTracking<T>(
    _ apply: () -> T,
    onChange: @autoclosure () -> () -> Void
) -> T
```

测试一：

```swift
@Observable
class Store {
    var a = 10
    var b = 20
    var c = 20
}

let sum = withObservationTracking {
    store.a + store.b
} onChange: {
    print("Store Changed a:\(store.a) b:\(store.b) c:\(store.c)")
}

store.c = 100

// No output

store.b = 100

// Output
// Store Changed a:10 b:20 c:100

store.a = 100

// No output
```

测试二：

```swift
withObservationTracking {
   print(store)
   DispatchQueue.main.asyncAfter(deadline: .now() + 0.3){
      store.a = 100
   }
} onChange: {
    print("Store Changed")
}

store.b = 100

// No output

store.a = 100

// No output
```

在苹果为 `withObservationTracking` 提供的 [官方文档](https://developer.apple.com/documentation/observation/withobservationtracking(_:onchange:)) 中，对函数的解释如下：

- apply：一个包含要跟踪的属性的闭包（ A closure that contains properties to track ）
- onChange：当属性值更改时调用的闭包（ The closure invoked when the value of a property changes ）
- 返回值：如果`apply`闭包有返回值，则返回该值；否则，没有返回值（ The value that the `apply` closure returns if it has a return value; otherwise, there is no return value ）

由于描述的过于简单，阅读后还是有不少让人困惑的地方：

- `withObservationTracking` 是如何判断 apply 闭包中哪些属性可以被观察？
- 为什么同样出现在 apply 闭包中的可观察属性，修改后并不会触发回调（ 测试二 ）？
- `withObservationTracking` 创建的观察行为是一次性的还是持久性的？
- onChange 闭包的调用时机是什么？所谓的 “when the value of a property changes” 是在属性被更改前还是更改后？

庆幸的是，Observation 框架是 Swift 5.9 标准库的一部分。我们可以通过查看其 [源代码](https://github.com/apple/swift/tree/main/stdlib/public/Observation/Sources/Observation) 来了解更多信息。

```responser
id:1
```

## Observation 框架的观察原理是什么

通过阅读代码，我们将对 `withObservationTracking` 创建观察的操作流程有一定的了解。我将其梳理如下：

### 创建观察阶段

- `withObservationTracking` 在当前线程的 `_ThreadLocal.value` 中创建一个 `_AccessList`
- 执行 apply 闭包
- 可观察对象的可观察属性在 get 方法被调用时（ 调用由 apply 闭包引发 ）, 会通过 `access` 方法在可观察对象实例的 ObservationRegistrar 中保存 apply 闭包中出现的可观察属性与回调闭包之间的对应关系 ( 这里的回调闭包用于调用 withObservationTracking 中的 onChange 闭包）。
- `withObservationTracking` 在 `_AccessList` 中保存可观察属性与 onChange 回调闭包之间的对应关系

### 当被观察属性即将变化时

- 被观察属性会调用 ObservationRegistrar 中的 `willSet` 方法，找到当前属性 KeyPath 对应的回调闭包
- 通过调用该闭包，在 `withObservationTracking` 发起的线程中调用 onChange 闭包
- onChange  闭包调用完成后，会清除 `withObservationTracking` 当前线程中 `_AccessList` 中对应的信息
- 清除 ObservationRegistrar 中与本次观察操作有关的属性与回调闭包之间的对应关系

### 结论

通过梳理，我们可以得到如下结论：

- 只有 apply 闭包中被读取的可观察属性（通过调用其 get 方法）才会被观察（这解释了测试二中的问题）
- `withObservationTracking` 创建的观察操作是一次性的行为，任意一个被观察属性发生变化，在调用了 onChange 函数后，本次观察都将结束
- onChange 闭包是在属性值变化之前（willSet 方法中）被调用的
- 在一次观察操作中，可以观察多个可观察属性。任一属性值变化都会结束本次观察。
- 观察行为是线程安全的，`withObservationTracking` 可以运行在另一个线程中，onChange 闭包将运行于 `withObservationTracking` 发起的线程中
- 只有可观察属性可以被观察。apply 闭包中仅出现的可观察对象并不会创建观察操作（这解释了测试二）

> 目前，Observation 框架并未提供创建持续观察行为的 API。或许在之后的版本中会增加这部分功能。
>

## SwiftUI 的视图如何观察属性的变化

根据 Observation 框架的工作原理，我们可以推测 SwiftUI 大概会采用下面的方法在可观察属性与视图更新之间创建联系：

```swift
struct A:View {
   var body: some View {
       ...
   }
}

let bodyValue = withObservationTracking {
    viewA.body
} onChange: {
    PreparingToRe-evaluateTheBodyValue()
}
```

在上文中，我们总结出“只有在 apply 闭包中被读取的可观察属性（通过调用其 get 方法）才会被观察”。因此可以得出以下结论：

```swift
Text(store.a) // Changes in store.a will trigger a re-evaluation of the body.

Button("Hi"){
    store.b = "abc" // Changes in store.b will not trigger a re-evaluation of the body.
}
```

## 通过 @Obervable 标注的类，是否还可以遵守 ObservableObject 协议

可以，不过由于 @Published 属性包装器 和 @Observable 宏之间会产生冲突，因此我们需要通过 `withObservationTracking` 来达成目的：

```swift

@Observable
final class Store: ObservableObject {
    var name = ""
    var age = 0

    init(name: String = "", age: Int = 0) {
        self.name = name
        self.age = age
        observeProperties()
    }

    private func observeProperties() {
        withObservationTracking {
            let _ = name
            let _ = age
        } onChange: { [weak self] in
            guard let self else { return }
            objectWillChange.send()
            observeProperties()
        }
    }
}
```

> 如有需要，你可以通过自定义宏来完成在 observeProperties 方法中引入所有可观察属性的重复工作。
>

## 在视图中 @Obervable 与 ObservableObject 可以共存吗

可以。在一个视图中，可以同时存在以不同的方式声明的可观察对象。SwiftUI 将根据可观察对象在视图中的注入方式选择对应的观察手段。

例如，上文中同时满足两种观察途径的可观察对象，根据其注入的方式不同，SwiftUI 采用的更新策略也将不同。

```swift
@State var store = Store() // 根据属性的变化，精细地决定是否重新评估 body

@StateObject var store = Store() // 只要有属性（ @Publsiehd ）发生变化，便对 body 重新评估
```

## 可观察对象支持嵌套吗（ 一个可观察对象的属性为另一个可观察对象 ）

支持。

由于 `@Published` 仅支持值类型，因此对于遵守 ObservableObject 协议的可观察对象，很难实现类似的嵌套逻辑：

```swift
class A:ObservableObject {
    @Published var b = B()
}

class B:ObserableObject {
    @Published var a = 10
}

let a = A()
a.b.a = 100 // 并不会触发视图更新
```

我曾经编写过一个 `@PublishedObject` 属性包装器来解决这个问题。详细信息，请阅读 [为自定义属性包装类型添加类 @Published 的能力](https://www.fatbobman.com/posts/adding-Published-ability-to-custom-property-wrapper-types/) 一文。原理上，`@PublishedObject` 是通过找到外部对象 A（*enclosing instance*）的 `objectWillChange` ，在 B 的属性发生变化时通知 A 的订阅者。也就是说，用了高度耦合的方式才实现了可观察对象的嵌套。

然而，通过 Observation 框架创建的可观察对象实现嵌套则会简单得多。通过 `withObservationTracking` 创建观察操作时，每个被读取的可观察属性都会主动地创建与订阅者之间的关联。无论它处在关系链中的任何层级，或以任何形式存在（如数组、字典等），都能被正确地跟踪。

例如：

```swift
@Observabl
class A {
   var a = 1
   var b = B()
}

@Observable
class B {
   var b = 1
}

let a = A()

withObservationTracking {
   let _ = a.b.b
} onChange: {
    print("update")
}
```

对于上面的代码，下面两种方式都会调用 onChange 闭包（ 只会调用一次 ）。

```swift
a.b.b = 100

// or

a.b = B()
```

在 `let _ = a.b.b` 这一行代码中，同时创建了对两个不同对象、不同层级的可观察属性的观察，`a.b` 以及 `b.b` 。这也是 Observation 框架的强大之处。

## Observation 是否解决了 ObservableObject 的性能问题

是的，Observation 框架从两方面改善了可观察对象在 SwiftUI 中的性能表现：

- 通过观察视图中的可观察属性而不是可观察对象，可以减少大量无效的视图更新。
- 相较于 Combine 的发布者-订阅者模式，Observation 的回调机制更加高效。

然而，由于 Observation 框架暂不支持创建可持续性的观察行为，每次评估后视图都需要重新创建观察操作（ 用时极少 ）。我们需要更多时间来评估这是否会导致新的性能问题。

## Observation 框架会影响 SwiftUI 编程习惯吗

对我来说，是的。

比如，当前开发者通常会使用结构体（ Struct ）来构建应用的状态模型。使用了 Observation 框架后，为了实现属性级别的观察，我们应该改用 Observation 框架创建可观察对象，甚至多层嵌套的对可观察对象来构建状态模型。

另外， 我们之前在视图中很多的优化技巧也将发生改变。例如，在使用 ObservableObject 时，我们会通过只引入与当前视图有用的数据，来减少不必要的刷新。

> 更多对视图优化技巧，请阅读 [避免 SwiftUI 视图的重复计算](https://www.fatbobman.com/posts/avoid_repeated_calculations_of_SwiftUI_views/) 一文。
>

```swift
class Store:ObservableObject {
    @Published var a = 1
    @Published var b = "hello"
}

struct Root:View {
    @StateObject var store = Store()
    var body: some View {
        VStack{
            A(a: store.a)
            B(b: store.b)
        }
    }
}

struct A:View {
    let a:Int    // only get a(Int)
    var body:some View {
        Text("\(store.a)")
    }
}

struct B:View { // only get b(String)
    let b:String
    var body:some View {
        Text(store.b)
    }
}
```

当 `store.b` 发生变化时，只有 Root 和 B 两个视图会重新评估。

在改用 Observation 框架后，上述的优化策略将不再是最优解。相反，以前不推荐的方式更加适合新的可观察对象。

```swift
@Observabl
class Store {
    var a = 1
    var b = "hello"
}

struct Root:View {
    @State var store = Store()
    var body: some View {
        VStack{
            A(store: store)
            B(store: store)
        }
    }
}

struct A:View {
    let store: Store
    var body:some View {
        Text("\(store.a)")
    }
}

struct B:View {
    let store: Store
    var body:some View {
        Text(store.b)
    }
}
```

只有出现在 body 中且被读取的属性才会触发视图的更新。经过修改后，当 `store.b` 发生变化时，只有 B 视图会重新评估。

由于 Observation 框架仍然是一个新事物，其 API 也还在不断演化中。随着越来越多的 SwiftUI 应用转换到这个框架上，开发者会总结出更多的使用心得。

## 最后

通过本文的论述，读者应该对 Observation 框架以及该框架如何改善 SwiftUI 的性能有了进一步的认识。尽管 Observation 框架目前与 SwiftUI 紧密绑定，但随着其 API 的丰富，相信它会出现在越来越多的应用场景中，而不仅仅是 SwiftUI。

