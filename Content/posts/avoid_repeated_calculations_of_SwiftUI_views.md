---
date: 2022-08-02 08:20
description: 随着近年来有关 SwiftUI 的文章与书籍越来越多，开发者应该都已经清楚地掌握了 —— “视图是状态的函数” 这一 SwiftUI 的基本概念。每个视图都有与其对应的状态，当状态变化时，SwiftUI 都将重新计算与其对应视图的 body 值。如果视图响应了不该响应的状态，或者视图的状态中包含了不该包含的成员，都可能造成 SwiftUI 对该视图进行不必要的更新（ 重复计算 ），当类似情况集中出现，将直接影响应用的交互响应，并产生卡顿的状况。通常我们会将这种多余的计算行为称之为过度计算或重复计算。本文将介绍如何减少（ 甚至避免 ）类似的情况发生，从而改善 SwiftUI 应用的整体表现。
tags: SwiftUI
title: 避免 SwiftUI 视图的重复计算
image: images/avoid_repeated_calculations_of_SwiftUI_views.png
mediumURL: https://medium.com/p/dcf0a65d3758
---
随着近年来有关 SwiftUI 的文章与书籍越来越多，开发者应该都已经清楚地掌握了 —— “视图是状态的函数” 这一 SwiftUI 的基本概念。每个视图都有与其对应的状态，当状态变化时，SwiftUI 都将重新计算与其对应视图的 body 值。

如果视图响应了不该响应的状态，或者视图的状态中包含了不该包含的成员，都可能造成 SwiftUI 对该视图进行不必要的更新（ 重复计算 ），当类似情况集中出现，将直接影响应用的交互响应，并产生卡顿的状况。

通常我们会将这种多余的计算行为称之为过度计算或重复计算。本文将介绍如何减少（ 甚至避免 ）类似的情况发生，从而改善 SwiftUI 应用的整体表现。

```responser
id:1
```

## 视图状态的构成

可以驱动视图进行更新的源被称之为 Source of Truth，它的类型有：

* 使用 @State、@StateObject 这类属性包装器声明的变量
* 视图类型（ 符合 View 协议 ）的构造参数
* 例如 onReceive 这类的事件源

一个视图可以包含多个不同种类的 Source of Truth，它们共同构成了视图状态（ 视图的状态是个复合体 ）。

基于不同种类的 Source of Truth 的实现原理与驱动机制之间的区别，下文中，我们将以此为分类，分别介绍其对应的优化技巧。

## 符合 DynamicProperty 协议的属性包装器

几乎每一个 SwiftUI 的使用者，在学习 SwiftUI 的第一天就会接触到例如 @State、@Binding 这些会引发视图更新的属性包装器。

随着 SwiftUI 的不断发展，这类的属性包装器越来越多，已知的有（ 截至 SwiftUI 4.0）：@AccessibilityFocusState、@AppStorage、@Binding、@Environment、@EnvironmentObject、@FetchRequest、@FocusState、@FocusedBinding、@FocusedObject、@FocusedValue、@GestureState、@NSApplicationDelegateAdaptor、@Namespace、@ObservadObject、@ScaledMetric、@SceneStorage、@SectionedFetchRequest、@State、@StateObject、@UIApplicationDelegateAdaptor、@WKApplicationDelegateAdaptor、@WKExtentsionDelegateAdaptor 等。所有可以让变量成为 Source of Truth 的属性包装器都有一个特点 —— 符合 DynamicProperty 协议。

因此，了解 DynamicProperty 协议的运作机制对于优化因该种类 Source of Truth 造成的重复计算尤为重要。

### DynamicProperty 的工作原理

苹果并没有提供太多有关 DynamicProperty 协议的资料，公开的协议方法只有 update ，其完整的协议要求如下：

```swift
public protocol DynamicProperty {
  static func _makeProperty<V>(in buffer: inout _DynamicPropertyBuffer, container: _GraphValue<V>, fieldOffset: Int, inputs: inout _GraphInputs)
  static var _propertyBehaviors: UInt32 { get }
  mutating func update()
}
```

其中 `_makeProperty` 方法是整个协议的灵魂所在。通过 `_makeProperty` 方法，SwiftUI 得以实现在将视图加载到视图树时，把所需的数据（ 值、方法、引用等 ）保存在 SwiftUI 的托管数据池中，并在属性图（ AttributeGraph ）中将视图与该 Source of Truth 关联起来，让视图响应其变化（ **当 SwiftUI 数据池中的数据给出变化信号时，更新视图** ）。

以 @State 为例：

```swift
@propertyWrapper public struct State<Value> : DynamicProperty {
  internal var _value: Value
  internal var _location: SwiftUI.AnyLocation<Value>? // SwiftUI 托管数据池中的数据引用
  public init(wrappedValue value: Value)
  public init(initialValue value: Value) {
        _value = value // 创建实例时，只会暂存初始值
    }
  public var wrappedValue: Value {
    get  //  guard let _location else { return _value} ...
    nonmutating set // 只能改动 _location 指向的数据
  }
  public var projectedValue: SwiftUI.Binding<Value> {
    get
  }
  // 在将视图加载到视图树中时，调用此方法，完成关联工作
  public static func _makeProperty<V>(in buffer: inout _DynamicPropertyBuffer, container: _GraphValue<V>, fieldOffset: Int, inputs: inout _GraphInputs)
}
```

* 在初始化 State 时，initialValue 仅被保存在 State 实例的内部属性 _value 中，此时，使用 Stae 包装的变量值没有被保存在 SwiftUI 的托管数据池中，并且 SwiftUI 也尚未在属性图中将其作为 Source of Truth 与视图关联起来。

* 当 SwiftUI 将视图加载到视图树时，通过调用 `_makeProperty` 完成将数据保存到托管数据池以及在属性图中创建关联的操作，并将数据在托管数据池中的引用保存在 `_location` （ AnyLocation 为引用类型，为 AnyLocationBase 的子类 ） 中。wrappedValue 的 get 和 set 方法都是针对 `_location` 操作的（ projectedValue 也一样 ）。

* 当 SwiftUI 将视图从视图树上删除时，会一并完成对 SwiftUI 数据池以及关联的清理工作。如此，使用 State 包装的变量，其存续期将与视图的存续期保持完全一致。并且 SwiftUI 会在其变化时自动更新（ 重新计算 ）对应的视图。

SwiftUI 上有一个困扰了不少人的问题：为什么无法在视图的构造函数中，更改 State 包装的变量值？了解了上述过程，问题便有了答案。

```swift
struct TestView: View {
    @State private var number: Int = 10
    init(number: Int) {
        self.number = 11 // 更改无效
    }
    var body: some View {
        Text("\(number)") // 首次运行，显示 10
    }
}
```

在构造函数中使用 `self.number = 11` 赋值时，视图尚未加载，_location 为 nil , 因此赋值对应的 wrappedValue set 操作并不会起作用。

对于像 @StateObject 这类针对引用类型的属性包装器，SwiftUI 会在属性图中将视图与包装对象实例（ 符合 ObservableObject 协议 ）的 objectWillChange（ ObjectWillChangePublisher ）关联起来，**在该 Publisher 发送数据时，更新视图**。任何通过 `objectWillChange.send` 进行的操作都将导致视图被刷新，无论实例中的属性内容是否被修改。

```swift
@propertyWrapper public struct StateObject<ObjectType> : DynamicProperty where ObjectType : ObservableObject {
  internal enum Storage { // 通过内部定义的枚举来标注视图是否已经被加载、数据是否已被数据池托管
    case initially(() -> ObjectType)
    case object(ObservedObject<ObjectType>)
  }

  internal var storage: StateObject<ObjectType>.Storage
  public init(wrappedValue thunk: @autoclosure @escaping () -> ObjectType) {
        storage = .initially(thunk) // 初始化，视图尚未加载
    }
  @_Concurrency.MainActor(unsafe) public var wrappedValue: ObjectType {
    get
  }
  @_Concurrency.MainActor(unsafe) public var projectedValue: SwiftUI.ObservedObject<ObjectType>.Wrapper {
    get
  }
    // 在 DynamicProperty 要求的方法中，实现将实例保存在托管数据池，并将视图与托管实例的 objectWillChange 进行关联
  public static func _makeProperty<V>(in buffer: inout _DynamicPropertyBuffer, container: _GraphValue<V>, fieldOffset: Int, inputs: inout _GraphInputs)
}
```

@ObservedObject 与 @StateObject 最大的区别是，ObservedObject 并不会在 SwiftUI 托管数据池中保存引用对象的实例（ @StateObject 会将实例保存在托管数据池中 ），仅会在属性图中创建视图与视图类型实例中的引用对象的 objectWillChange 之间的关联。

```swift
@ObservedObject var store = Store() // 每次创建视图类型实例，都会重新创建 Store 实例
```

由于 SwiftUI 会不定时地创建视图类型的实例（ 非加载视图 ），每次创建的过程都会重新创建一个新的引用对象，因此假设使用上面的代码（ 用 @ObservedObject 创建实例 ），让 @ObservedObject 指向一个不稳定的引用实例时，很容易出现一些怪异的现象。

> 阅读如下的文章，可以帮助你更好地理解本节的内容：[SwiftUI 视图的生命周期研究](https://fatbobman.com/posts/swiftUILifeCycle/)、[@state 研究](https://fatbobman.com/posts/swiftUI-state/)、[@StateObject 研究](https://fatbobman.com/posts/stateobject/)

### 避免非必要的声明

任何可以在当前视图之外进行改动的 Source of Truth（ 符合 DynamicProperty 协议的属性包装器 ），只要在视图类型中声明了，无论是否在视图 body 中被使用，在它给出刷新信号时，当前视图都将被刷新。

例如下面的代码：

```swift
struct EnvObjectDemoView:View{
    @EnvironmentObject var store:Store
    var body: some View{
        Text("abc")
    }
}
```

虽然当前的视图中并没有调用 store 实例的属性或方法，但无论在任何场合，但只要该实例的 objectWillChange.send 方法被调用（ 例如修改了使用 @Published 包装的属性 ），所有与之相关联的视图（ 包括当前视图 ）都会被刷新（ 对 body 求值 ）。

类型的情况在 @ObservedObject、@Environment 上也会出现：

```swift
struct MyEnvKey: EnvironmentKey {
    static var defaultValue = 10
}

extension EnvironmentValues {
    var myValue: Int {
        get { self[MyEnvKey.self] }
        set { self[MyEnvKey.self] = newValue }
    }
}

struct EnvDemo: View {
    @State var i = 100
    var body: some View {
        VStack {
            VStack {
                EnvSubView()
            }
            .environment(\.myValue, i)
            Button("change") {
                i = Int.random(in: 0...100)
            }
        }
    }
}

struct EnvSubView: View {
    @Environment(\.myValue) var myValue // 声明了，但并没有在 body 中使用
    var body: some View {
        let _ = print("sub view update")
        Text("Sub View")
    }
}
```

即使 EnvSubView 的 body 中没有使用 myValue，但由于其祖先视图对 EnvironmentValues 中的 myValue 进行了修改，EnvSubView 也会被刷新。

只要多检查代码，清除掉这些没有使用的声明，就可以避免因此种方式产生重复计算。

### 其他建议

* 需要跳跃视图层级时，考虑使用 Environment 或 EnvironmentObject

* 对于不紧密的 State 关系，考虑在同一个视图层级使用多个 EnvironmentObject 注入，将状态分离
* 在合适的场景中，可以使用 objectWillChange.send 替换 @Published
* 可以考虑使用第三方库，对状态进行切分，减少视图刷新几率
* 无需追求完全避免重复计算，应在依赖注入便利性、应用性能表现、测试难易度等方面取得平衡
* 不存在完美的解决方案，即使像 TCA 这类的热门项目，面对切分粒度高、层次多的 State 时，也会有明显的性能瓶颈

```responser
id:1
```

## 视图的构造参数

在尝试改善 SwiftUI 视图的重复计算行为时，开发者通常会将注意力集中于那些符合 DynamicProperty 协议的属性包装器之上，然而，对视图类型构造参数进行优化，有时会取得更加明显的收益。

SwiftUI 会将视图类型的构造参数作为 Source of Truth 对待。与符合 DynamicProperty 协议的属性包装器主动驱动视图更新的机制不同，SwiftUI 在更新视图时，会通过检查子视图的实例是否发生变化（ 绝大多数都由构造参数值的变化导致 ）来决定对子视图更新与否。

例如：当 SwiftUI 在更新 ContentView 时，如果 SubView 的构造参数（ name 、age ）的内容发生了变化，SwiftUI 会对 SubView 的 body 重新求值（ 更新视图 ）。

```swift
struct SubView{
    let name:String
    let age:Int
    
    var body: some View{
        VStack{
            Text(name)
            Text("\(age)")
        }
    }
}

struct ContentView {
    var body: some View{
        SubView(name: "fat" , age: 99)
    }
}
```

### 简单、粗暴、高效的比对策略

我们知道，在视图的存续期中，SwiftUI 通常会多次地创建视图类型的实例。在这些创建实例的操作中，绝大多数的目的都是为了检查视图类型的实例是否发生了变化（ 绝大多数的情况下，变化是由构造参数的值发生了变化而导致 ）。

* 创建新实例
* 将新实例与 SwiftUI 当前使用的实例进行比对
* 如实例发生变化，用新实例替换当前实例，对实例的 body 求值，并用新的视图值替换老的视图值
* 视图的存续期不会因为实体的更替有所改变

由于 SwiftUI 并不要求视图类型必须符合 Equatable 协议，因此采用了一种简单、粗暴但十分高效地基于 Block 的比对操作（ 并非基于参数或属性 ）。

比对结果仅能证明两个实例之间是否不同，但 SwiftUI 无法确定这种不同是否会导致 body 的值发生变化，因此，它会无脑地对 body 进行求值。

为了避免产生重复计算，通过优化构造参数的设计，让实例仅在真正需要更新时才发生变化。

> 由于创建视图类型实例的操作异常地频繁，因此一定不要在视图类型的构造函数中进行任何会对系统造成负担的操作。另外，不要在视图的构造函数中为属性（ 没有使用符合 DynamicProperty 协议的包装器 ）设置不稳定值（ 例如随机值 ）。不稳定值会导致每次创建的实例都不同，从而造成非必要的刷新

### 化整为零

上述的比对操作是在视图类型实例中进行的，这意味着将视图切分成多个小视图（ 视图结构体 ）可以获得更加精细的比对结果，并会减少部分 body 的计算。

```swift
struct Student {
    var name: String
    var age: Int
}

struct RootView:View{
    @State var student = Student(name: "fat", age: 88)
    var body: some View{
        VStack{
            StudentNameView(student: student)
            StudentAgeView(student: student)
            Button("random age"){
                student.age = Int.random(in: 0...99)
            }
        }
    }
}

// 分成小视图
struct StudentNameView:View{
    let student:Student
    var body: some View{
        let _ = Self._printChanges()
        Text(student.name)
    }
}

struct StudentAgeView:View{
    let student:Student
    var body: some View{
        let _ = Self._printChanges()
        Text(student.age,format: .number)
    }
}
```

上面的代码虽然实现了将 Student 的显示子视图化，但是由于构造参数的设计问题，并没有起到减少重复计算的效果。

在点击 random age 按钮修改 age 属性后，尽管 StudentNameView 中并没有使用 age 属性，但 SwiftUI 仍然对 StudentNameView 和 StudentAgeView 都进行了更新。

这是因为，我们将 Student 类型作为参数传递给了子视图，SwiftUI 在比对实例的时候，并不会关心子视图中具体使用了 student 中的哪个属性，只要 student 发生了变化，那么就会重新计算。为了解决这个问题，我们应该调整传递给子视图的参数类型和内容，仅传递子视图需要的数据。

```swift
struct RootView:View{
    @State var student = Student(name: "fat", age: 88)
    var body: some View{
        VStack{
            StudentNameView(name: student.name) // 仅传递需要的数据
            StudentAgeView(age:student.age)
            Button("random age"){
                student.age = Int.random(in: 0...99)
            }
        }
    }
}

struct StudentNameView:View{
    let name:String // 需要的数据
    var body: some View{
        let _ = Self._printChanges()
        Text(name)
    }
}

struct StudentAgeView:View{
    let age:Int
    var body: some View{
        let _ = Self._printChanges()
        Text(age,format: .number)
    }
}
```

经过上面的改动后，仅当 name 属性发生变化时，StudentNameView 才会更新，同理，StudentAgeView 也只会在 age 发生变化时更新。

### 让视图符合 Equatable 协议以自定义比对规则

也许由于某种原因，你无法采用上面的方法来优化构造参数，SwiftUI 还提供了另外一种通过调整比对规则的方式用以实现相同的结果。

* 让视图符合 Equatable 协议
* 为视图自定义判断相等的比对规则

> 在早期的 SwiftUI 版本中，我们需要使用 EquatableView 包装符合 Equatable 协议的视图以启用自定义比较规则，近期的版本已经无需使用

仍以上面的代码举例：

```swift
struct RootView: View {
    @State var student = Student(name: "fat", age: 88)
    var body: some View {
        VStack {
            StudentNameView(student: student)
            StudentAgeView(student: student)
            Button("random age") {
                student.age = Int.random(in: 0...99)
            }
        }
    }
}

struct StudentNameView: View, Equatable {
    let student: Student
    var body: some View {
        let _ = Self._printChanges()
        Text(student.name)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.student.name == rhs.student.name
    }
}

struct StudentAgeView: View, Equatable {
    let student: Student
    var body: some View {
        let _ = Self._printChanges()
        Text(student.age, format: .number)
    }

    static func== (lhs: Self, rhs: Self) -> Bool {
        lhs.student.age == rhs.student.age
    }
}
```

> 此种方法仅会影响视图类型实例的比对，并不会影响因符合 DynamicProperty 协议的属性包装器产生的刷新

### 闭包 —— 容易被忽略的突破点

当构造参数的类型为函数时，稍不注意，就可以导致重复计算。

比如，下面的代码：

```swift
struct ClosureDemo: View {
    @StateObject var store = MyStore()
    var body: some View {
        VStack {
            if let currentID = store.selection {
                Text("Current ID: \(currentID)")
            }
            List {
                ForEach(0..<100) { i in
                    CellView(id: i){ store.sendID(i) } // 使用尾随闭包的方式为子视图设定按钮动作
                }
            }
            .listStyle(.plain)
        }
    }
}

struct CellView: View {
    let id: Int
    var action: () -> Void
    init(id: Int, action: @escaping () -> Void) {
        self.id = id
        self.action = action
    }

    var body: some View {
        VStack {
            let _ = print("update \(id)")
            Button("ID: \(id)") {
                action()
            }
        }
    }
}

class MyStore: ObservableObject {
    @Published var selection:Int?

    func sendID(_ id: Int) {
        self.selection = id
    }
}
```

当点击某一个 CellView 视图的按钮后，所有的 CellView （ 当前 List 显示区域 ）都会重新计算。

![closure_view_udpate1_2022-07-30_14.37.20.2022-07-30 14_41_08](https://cdn.fatbobman.com/closure_view_udpate1_2022-07-30_14.37.20.2022-07-30%2014_41_08.gif)

这是因为，乍看起来，我们并没有在 CellView 中引入会导致更新的 Source of Truth，但由于我们将 store 放置在闭包当中，点击按钮后，因为 store 发生了变动，从而导致 SwiftUI 在对 CellView 实例进行比对时认定其发生了变化。

```swift
CellView(id: i){ store.sendID(i) } 
```

解决的方法有两种：

* 让 CellView 符合 Equatable 协议，不比较 action 参数

```swift
struct CellView: View, Equatable {
    let id: Int
    var action: () -> Void
    init(id: Int, action: @escaping () -> Void) {
        self.id = id
        self.action = action
    }

    var body: some View {
        VStack {
            let _ = print("update \(id)")
            Button("ID: \(id)") {
                action()
            }
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool { // 将 action 排除在比较之外
        lhs.id == rhs.id
    }
}

ForEach(0..<100) { i in
    CellView(id: i){ store.sendID(i) }
}
```

* 修改构造参数中的函数定义，将 store 排除在 CellView 之外

```swift
struct CellView: View {
    let id: Int
    var action: (Int) -> Void // 修改函数定义
    init(id: Int, action: @escaping (Int) -> Void) {
        self.id = id
        self.action = action
    }

    var body: some View {
        VStack {
            let _ = print("update \(id)")
            Button("ID: \(id)") {
                action(id)
            }
        }
    }
}

ForEach(0..<100) { i in
    CellView(id: i, action: store.sendID) // 直接传递 store 中的 sendID 方法，将 store 排除在外
}
```

![closure_view_udpate2_2022-07-30_14.38.32.2022-07-30 14_41_52](https://cdn.fatbobman.com/closure_view_udpate2_2022-07-30_14.38.32.2022-07-30%2014_41_52.gif)

## 事件源

为了全面地向 SwiftUI life cycle 转型，苹果为 SwiftUI 提供了一系列可以直接在视图中处理事件的视图修饰器，例如：onReceive、onChange、onOpenURL、onContinueUserActivity 等。这些触发器被称为事件源，它们也被视为 Source of Truth ，是视图状态的组成部分。

这些触发器是以视图修饰器的形式存在的，因此触发器的生命周期同与其关联的视图的存续期完全一致。当触发器接收到事件后，无论其是否更改当前视图的其他状态，当前的视图都会被更新。因此，为了减少因事件源导致的重复计算，我们可以考虑采用如下的优化思路：

* 控制生命周期

  只在需要处理事件时才加载与其关联的视图，用关联视图的存续期来控制触发器的生命周期

* 减小影响范围

  为触发器创建单独的视图，将其对视图更新的影响范围降至最低

```swift
struct EventSourceTest: View {
    @State private var enable = false

    var body: some View {
        VStack {
            let _ = Self._printChanges()
            Button(enable ? "Stop" : "Start") {
                enable.toggle()
            }
            TimeView(enable: enable) // 单独的视图，onReceive 只能导致 TimeView 被更新
        }
    }
}

struct TimeView:View{
    let enable:Bool
    @State private var timestamp = Date.now
    var body: some View{
        let _ = Self._printChanges()
        Text(timestamp, format: .dateTime.hour(.twoDigits(amPM: .abbreviated)).minute(.twoDigits).second(.twoDigits))
            .background(
                Group {
                    if enable { // 只在需要使用时，才加载触发器
                        Color.clear
                            .task {
                                while !Task.isCancelled {
                                    try? await Task.sleep(nanoseconds: 1000000000)
                                    NotificationCenter.default.post(name: .test, object: Date())
                                }
                            }
                            .onReceive(NotificationCenter.default.publisher(for: .test)) { notification in
                                if let date = notification.object as? Date {
                                    timestamp = date
                                }
                            }
                    }
                }
            )
    }
}

extension Notification.Name {
    static let test = Notification.Name("test")
}
```

![event_source_2022-07-30_16.13.13.2022-07-30 16_14_08](https://cdn.fatbobman.com/event_source_2022-07-30_16.13.13.2022-07-30%2016_14_08.gif)

> 请注意，SwiftUI 会在主线程上运行触发器闭包，如果闭包中的操作比较昂贵，可以考虑将闭包发送到后台队列

## 总结

本文介绍了一些在 SwiftUI 中如何避免造成视图重复计算的技巧，除了从中查找是否有能解决你当前问题的方法外，我更希望大家将关注点集中于这些技巧在背后对应的原理。

