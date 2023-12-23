---
date: 2023-12-21 08:11
description: 在这篇文章中，我们将探讨几个在 SwiftUI 开发中经常使用且至关重要的属性包装器。本文旨在提供对这些属性包装器的主要功能和使用注意事项的概述，而非详尽的使用指南。
tags: SwiftUI
title: 探讨 SwiftUI 中的关键属性包装器：@State、@Binding、@StateObject、@ObservedObject、@EnvironmentObject 和 @Environment
image: images/exploring-key-property-wrappers-in-swiftui.jpg
mediumURL: https://medium.com/p/759b29c17e10
---
在这篇文章中，我们将探讨几个在 SwiftUI 开发中经常使用且至关重要的属性包装器。本文旨在提供对这些属性包装器的主要功能和使用注意事项的概述，而非详尽的使用指南。

> 本文应几位朋友之邀而写，旨在帮助已经熟悉通用编程但对 SwiftUI 相对陌生的开发者，快速理解这些属性包装器的核心作用和适用场景。

## @State

`@State` 是 SwiftUI 中最常用的属性包装器之一，主要用于在视图内部管理私有数据。它特别适合存储值类型数据，如字符串、整数、枚举或结构体实例。

- `@State` 用于管理视图的私有状态。
- 它主要用于存储值类型数据（与视图的生命周期一致）。

### 典型应用场景

- 当需要因视图内的数据变化而触发视图更新时，`@State` 是理想的选择。
- 它常用于简单的 UI 组件状态管理，如开关状态、文本输入等。
- 如果数据不需要复杂的跨视图共享，使用 `@State` 可以简化状态管理。

### 注意事项

- 尽量仅在视图的内部使用 `@State`，即使未显式标记为 `private`，也应当将其视为视图的私有属性。
- `@State` 为包装数据同时提供了双向数据绑定管道，可以通过 `$` 前缀来访问。
- `@State` 不适合用于存储大量数据或复杂数据模型，这种情况下更适合使用 `@StateObject` 或其他状态管理方案。

- 属性包装器本质上是一个结构体。使用 `@` 前缀时，它用于包装其他数据；而不带 `@` 时，表示其自身类型。更多细节参考 [John Sundell](https://www.swiftbysundell.com/articles/property-wrappers-in-swift/) 和 [Antoine van der Lee](https://www.avanderlee.com/swift/property-wrappers/)，或阅读 [@State 研究](https://fatbobman.com/posts/swiftUI-state/)。
- 在构造方法中赋值时，需通过 `_` 下划线访问 `@State` 的原始值并进行赋值。

```swift
@State var name: String
init(text: String) {
    // 给下划线版本赋值，需要用 State 类型本身进行包装
    _name = State(wrappedValue: text)
}
```

- `@State` 变量在视图的构造函数中只能赋值一次，后续的调整需要在视图的 `body` 内进行。详见 [避免 SwiftUI 视图的重复计算](https://fatbobman.com/posts/avoid_repeated_calculations_of_SwiftUI_views/)。
- 如果不需要在当前视图或在子视图中（通过 `@Binding` ）修改值，无需使用 `@State`。

- 在某些情况下， `@State` 也被用来存储非值类型数据，比如引用类型以保证其唯一性和生命周期。

```swift
@State var textField: UITextField?
TextField("", text: $text)
    .introspect(.textField, on: .iOS(.v17)) {
        // 持有 UITextField 实例
        self.textField = $0
    }
```

- `@State` 在 Observation 框架中用于确保 `@Observable` 实例的生命周期不短于视图本身。详细信息见 [深度解读 Observation](https://fatbobman.com/posts/mastering-Observation/)。
- `@State` 是线程的安全，可以在非主线程中进行修改。

```swift
@State var text: String = ""
Button("Change") {
    // 无需切换回主线程
    Task.detached {
        text = "hi"
    }
}
```

```responser
id:1
```

## @Binding

`@Binding` 是 SwiftUI 中用于实现双向数据绑定的属性包装器。它创建了值（如 Bool）与显示及修改这些值的 UI 元素之间的双向连接。

- `@Binding` 不直接持有数据，而是提供了对其他数据源的读写访问的包装。
- 它允许 UI 元素直接修改数据，并反映这些数据的变化。

### 典型应用场景
- `@Binding` 主要用于与支持双向数据绑定的 UI 组件，如和 `TextField`、`Stepper`、`Sheet` 和 `Slider` 等配合使用。
- 它适用于需要在子视图中直接修改父视图中的数据情况。

### 注意事项
- 应当谨慎使用 `@Binding`，当子视图只需响应数据变化而无需修改时，无需使用 `@Binding`。
- 在复杂的视图层级中，逐级传递 @Binding 可能导致数据流难以追踪，此时应考虑使用其他状态管理方法。
- 确保 `@Binding` 的数据源是可信的，错误的数据源可能导致数据不一致或应用崩溃。由于 `@Binding` 只是一个管道，它并不保证对应的数据源在调用时必然存在。

- 开发者可以通过提供 `get` 和 `set` 的方式来自定义 Binding。

```swift
let binding = Binding<String>(
    get: { text },
    // 限制字符串的长度
    set: { text = String($0.prefix(10)) }
)
```

* 通过为 `Binding` 类型创建扩展，可以极大地提高开发的效率和灵活性。相关内容请阅读：[SwiftUI Binding Extensions](https://betterprogramming.pub/swiftui-binding-extensions-b6a9f27d2858)。	

```swift
// 将一个 Binding<V?> 转换为 Binding<Bool>
extension Binding {
    static func isPresented<V>(_ value: Binding<V?>) -> Binding<Bool> {
        Binding<Bool>(
            get: { value.wrappedValue != nil },
            set: {
                if !$0 { value.wrappedValue = nil }
            }
        )
    }
}
```

- 在 Observation 框架中，可以使用 `@Bindable` 为 `@Observable` 实例创建对应的 `Binding` 接口，详细信息见 [深度解读 Observation](https://fatbobman.com/posts/mastering-Observation/)。。
- 在声明构造参数时，需要明确指定 `Binding` 的包装值类型（`get` 方法的返回值类型），如 `Binding<String>`。

- `@Binding` 并不是独立的数据源。实际上，它只是对已存在数据的引用。只有能够引发视图更新的值被 `get` 方法读取时，才会触发视图更新（ 比如 @State、@StateObject ），这点对于自定义 `Binding` 尤为重要。

```swift
struct Test: View {
    let a = A()
    var body: some View {
        let binding = Binding<String>(
            get: { a.name },
            set: { a.name = $0 }
        )
        // 尽管 A 符合 ObservableObject 协议，但是由于没有使用 StateObject 与视图关联，因此为其属性创建的 Binding 也同样不会引发视图更新
        Text(binding.wrappedValue)
        TextField("input:", text: binding)
    }

    class A: ObservableObject {
        @Published var name: String = ""
    }
}
```

## @StateObject

`@StateObject` 是 SwiftUI 中用于管理符合 ObservableObject 协议的对象实例的属性包装器，以确保这些实例的生命周期与当前视图一致（ 不短于）。

- `@StateObject` 专门用于管理符合 ObservableObject 协议的实例。
- 标注的对象实例在视图的整个生命周期中保持唯一，即使视图更新，对象实例也不会重新创建。

### 典型应用场景
- `@StateObject` 通常在视图树中最顶层使用，用于创建和维护 ObservableObject 实例。
- 常用于需要在视图的整个生命周期中持续存在的数据模型或业务逻辑。
- 相较 `@State` 而言，`@StateObject` 更适合管理复杂的数据模型及其执行逻辑

### 注意事项
- `@StateObject` 触发视图更新的条件包括使用 `@Published` 标注的属性被赋值（ 无论新旧值是否一致 ）和调用 `objectWillChange` 发布者。
- 只在必须响应实例属性变化的视图中使用 `@StateObject`，如果仅需读取数据而不需要观察变化，可考虑其他选项。

- 引入 `@StateObject` 意味着所有相关操作都在主线程上进行（ SwiftUI 会隐式为视图添加 `@MainActor` ），包括异步操作。应将需要在非主线程上运行的代码应该从视图代码中剥离。

```swift
struct B:View {
    // 使用 StateObject 后，相当于为当前的视图添加了 @MainActor
    @StateObject var store = Store()
    var body: some View {
        Button("Main Thread"){
            Task.detached{
                await printThradName()
                // output <_NSMainThread: 0x60000170c000>{number = 1, name = main}
            }
        }
    }
    
    func printThradName() async {
        print(Thread.current)
    }
}
```

- 如果在视图存续期有保障的地方创建实例（ 比如说 App 层级），且在当前层级也无需响应该实例中属性的变化，可以不使用 `@StateObject`

```swift
struct DemoApp: App {
    // 因为当前层级的视图的存续期与应用一致，如果当前层级无需响应 store 变化，可以不用 StateObject
    let store = Store()

    var body: some Scene {
        WindowGroup {
            Test()
                .environmentObject(store)
        }
    }
}
```

## @ObservedObject

`@ObservedObject` 是 SwiftUI 中用于为视图与 ObservableObject 实例之间创建关联的属性包装器，主要用于在视图存续期内引入外部的 ObservableObject 实例。

- `@ObservedObject` 不持有被观察的实例，不保证其生存期。
- `@ObservadObject` 可以在视图存续期内切换其所关联的实例。

### 典型应用场景

* 通常与 `@StateObject` 配合使用，父视图使用 `@StateObject` 创建实例，子视图通过 `@ObservedObject` 引入该实例，响应实例变化。

- 需要动态切换实例的场景。比如在 NavigationSplitView 中，sidebar 中选择不同的实例，detail 视图动态更换数据源。详情请阅读 [StateObject 与 ObservedObject](https://fatbobman.com/posts/StateObject_and_ObservedObject/) 。

```swift
// 定义一个符合 ObservableObject 协议的数据模型
class DataModel: ObservableObject, Identifiable {
    let id = UUID()
}

struct MyView: View {
    @State private var items = [DataModel(), DataModel()]

    var body: some View {
        VStack {
            // 切换 MySubView 关联的 DataModel 实例
            Button("Replace Model") {
                items.reverse()
            }
            MySubView(model: items.first!)
        }
    }
}

// 子视图
struct MySubView: View {
    // 使用 @ObservedObject 引入外部的 ObservableObject 实例
    @ObservedObject var model: DataModel 

    var body: some View {
        VStack {
            // 显示当前 DataModel 实例的 UUID
            // 当 MyView 中的 'items' 数组改变时，这里显示的 UUID 会更新，展示了 @ObservedObject 的动态切换能力
            Text(model.id.uuidString)
        }
    }
}

```

- 在视图中引入由外部框架或代码来保证存续期的 ObservableObject 实例时使用，例如引入 Core Data 的 NSManagedObject 实例。

### 注意事项
- 在 iOS 13 中，由于没有提供 `@StateObject` ，此时 `@ObservedObject` 是唯一选择，可能会因为无法保证实例的存续期而产生 [意想不到的结果](https://fatbobman.com/posts/stateobject/)，为了避免类似问题，可以在更高层级的视图中（ 稳定性没有问题的地方 ），通过 `@State` 来持有该实例，然后在使用的视图中通过 `@ObservedObject` 来引入。
- 在引入第三方提供的符合 ObservableObject 实例时，应确保 `@ObservedObject` 引用的对象在整个视图的生命周期中都是可用的，否则可能导致运行时错误。

```responser
id:1
```

## @EnvironmentObject

`@EnvironmentObject` 是用于在当前视图中与上层视图经环境传递的 ObservableObject 实例之间创建关联的属性包装器。它提供了一种便捷的方式在不同的视图层级中引入共享数据，而无需显式地通过每个视图的构造器传递。

### 典型应用场景

- 当需要在多个视图间共享同一个数据模型时，如用户设置、主题或应用状态。
- 适用于构建复杂的视图层级，其中多个视图需要访问同一个 ObservableObject 实例。

### 注意事项

- 使用 `@EnvironmentObject` 前，必须确保已在视图层级的上游提供了相应的实例（ 通过 `.environmentObject` 修饰器 ），否则将导致运行时错误。
- 它对视图的更新触发条件与 `@StateObject` 和 `@ObservedObject 一样`。

* 与 `@ObservedObject` 一样， `@EnvriomentObject` 支持动态切换关联的实例。

```swift
struct MyView: View {
    @State private var items = [DataModel(), DataModel()]
    var body: some View {
        VStack {
            Button("Replace Model") {
                // 切换子视图 MySubView 关联的实例
                items.reverse()
            }
            MySubView()
                .environmentObject(items.first!)
        }
    }
}

struct MySubView: View {
    @EnvironmentObject var model: DataModel // 动态切换关联的实例
    var body: some View {
        VStack {
            Text(model.id.uuidString)
        }
    }
}
```

- 只在必要时引入 `@EnvironmentObject`，否则会引发视图不必要的视图更新。通常情况下，会有多个视图从不同层级观察并响应同一个实例，必须合理优化才能避免应用性能劣化。这也是很多开发者不喜欢 `@EnviromentObject` 的原因。
- 在一个视图层次中，同一个类型的环境对象只有一个实例有效。

```swift
@StateObject var a = DataModel()
@StateObject var b = DataModel()

MySubView()
    .environmentObject(a) // 靠近视图的有效
    .environmentObject(b)
```

## @Environment

`@Environment` 是视图用于从环境中读取、响应、调用特定值的属性包装器。它允许视图访问由 SwiftUI 或应用环境提供的数据、实例或方法。

### 典型应用场景

- 当需要访问和响应如界面样式（暗模式/亮模式）、设备方向、字体大小等由系统或上层视图提供的环境值时（ 通常对应值类型）。
- 当需要访问和调用 SwiftData 的 ModelContext 时（对应引用类型）。
- 当需要使用系统提供的一些方法时，比如 `dismiss`、`openURL`（ 通过 struct 的 `callAsFunction` 封装的方法 ）。

### 注意事项

* 相较于由 `@EnvironmentObject` 提供的实例所应对的复杂逻辑，`@Environment` 引入的数据通常的功能更加的专一。
* 开发者可以通过自定义 `EnvironmentKey` 的方式来创建自定义环境值，与系统提供的环境值一样，可以定义各种类型（ 值类型、Binding、引用类型、方法的 ），详情请参阅 [Custom SwiftUI Environment Values Cheatsheet](https://www.fivestars.blog/articles/custom-environment-values-cheatsheet/)。

```swift
public struct ContainerEnvironmentKey: EnvironmentKey {
    // 示例环境键的默认值
    public static var defaultValue = ContainerEnvironment(containerName: "Default")
}

public extension EnvironmentValues {
    var overlayContainer: ContainerEnvironment {
        get { self[ContainerEnvironmentKey.self] }
        set { self[ContainerEnvironmentKey.self] = newValue }
    }
}
```

* 在 SwiftUI 中，与 `EnvironmentKey` 类似的定义方式用途很多，掌握了一种很容易掌握其他的。比如：`PreferenceKey`（ 子视图传递给父视图 ）、`FocusedValueKey`（ 基于焦点传递的值 ）、`LayoutValueKey`（ 子视图传递给布局容器 ）。
* 由于默认值的存在，`@Environment` 不会因缺少值而导致应用崩溃，但由此也容易产生开发者忘记注入值的情况。
* 与 `@EnvironmentObject` 不同，低层级视图不能修改由祖先视图传递下来的 `EnvironmentValue` 的值。
* 可以通过定义不同的 `EnvironmentKey` ，在 `EnvironmentValue` 中创建多个相同类型的不同名称的属性。


## 总结

- `@StateObject`、`@ObservedObject` 和 `@EnvironmentObject` 专用于关联符合 ObservableObject 协议的实例。
- 虽然在某些情形下 `@StateObject` 可以替代 `@ObservedObject` 并提供相似的功能，但它们各自有独特的使用场景。`@StateObject` 通常用于创建和维护实例，而 `@ObservedObject` 用于引入和响应已存在的实例。
- 在 iOS 17+ 的环境中，如果应用主要依赖于 Observation 和 SwiftData 框架，那么这三个属性包装器的使用频率可能会相对较低。
- `@State` 和 `@Environment` 不限于只能存储值类型，但也可用于其他类型。
- `@Environment` 提供了一种相对更安全的方法来引入环境数据，因为它可以通过 `EnvironmentValue` 提供默认值。这减少了因遗漏数据注入而导致的应用崩溃风险。
- 在 Observation 框架的背景下，`@State` 和 `@Environment` 成为了最主要的属性包装器。无论是值类型还是 `@Observable` 实例，都可以通过这两种包装器引入视图。
- 自定义 Binding 提供了强大的灵活性，允许开发者在数据源和依赖于 Binding 的 UI 组件之间以简洁的代码实现复杂逻辑。

每个属性包装器都有其独特的应用场景和优势。选择正确的工具对于构建高效、可维护的 SwiftUI 应用是至关重要的。正如在软件开发中经常提到的，没有一种工具是万能的，但恰当地使用它们可以大大提高我们的开发效率和应用质量。
