---
date: 2023-10-09 08:12
description: 在 SwiftData 的数项改进中，用纯代码声明数据模型无疑给 Core Data 开发者留下了深刻印象。本文将深入探讨 SwiftData 是如何通过代码创建数据模型的，使用了哪些新的语言特性，并展示了如何通过声明代码来创建 PersistentModel 实例。
tags: SwiftData,持久化框架
title: 揭秘 SwiftData 的数据建模原理
image: images/unveiling-the-Data-Modeling-Principles-of-SwiftData.jpg
mediumURL: https://medium.com/p/480c993d2f5c
---
在 SwiftData 的数项改进中，用纯代码声明数据模型无疑给 Core Data 开发者留下了深刻印象。本文将深入探讨 SwiftData 是如何通过代码创建数据模型的，使用了哪些新的语言特性，并展示了如何通过声明代码来创建 PersistentModel 实例。

## 三个事实

了解下述三个事实对于更好地掌握和理解 SwiftData 的建模原理以及为什么 SwiftData 会采用本文介绍的这些方法非常有帮助。

### SwiftData 是建立在 Core Data 之上的框架

尽管苹果极少强调 SwiftData 与 Core Data 之间的关系，但 SwiftData 框架建立在 Core Data 基础之上这一点仍是无可否认的事实。基于 Core Data 为 SwiftData 带来了几点好处：

* 数据库文件格式兼容，现有数据可以直接用新框架操作
* 继承了 Core Data 已有的稳定性验证，大幅减少潜在问题。

尽管 SwiftData 是以 Core Data 为基础的，但这并不意味着，在使用 SwiftData 进行开发时，仍需采用与 Core Data 一样的编程原则。由于 SwiftData 结合了众多 Swift 语言的最新特性，因此，在很多场合下，开发者需要用全新的思维来重新设计数据处理逻辑。

>  在 [SwiftDataKit：让你在 SwiftData 中使用 Core Data 的高级功能](https://www.fatbobman.com/posts/use-Core-Data-features-in-SwiftData-by-SwiftDataKit/) 一文中，我介绍了如何调用 SwiftData 元素背后对应的 Core Data 对象的技巧。

### SwiftData 与 Swift 语言紧密关联，是 Swift 语言的先导者

近年来，苹果推出了多个以 Swift 为前缀的框架，例如 SwiftUI、Swift Charts、SwiftData 等。这种命名方式体现了这些框架与 Swift 语言的紧密结合。为了实现这些框架，苹果还积极推动 Swift 语言的发展，提出新的提案，并在框架中预先应用了尚未完全确定的特性。这些框架广泛采用了 Swift 的新功能，例如结构构造器（Result Builder）、属性包装器（Property Wrapper）、宏（Macro）和初始化访问器（Init Accessors）等，使其成为了新语言特性的先驱和试验场。

遗憾的是，些框架目前尚不存在跨平台和开源的可能。主要是因为它们依赖了苹果生态中的专有 API。这阻碍了利用这些优秀框架在其他平台上推广 Swift 语言的机会。

总的来说，SwiftData 等框架与 Swift 语言关系密切，并在采用新特性方面起到了引领作用。学习这些框架的同时也是在掌握 Swift 语言的新特性。

### 纯代码声明数据模型相对 Core Data 是一项进步但并非革命

尽管 SwiftData 采用的是纯代码声明数据模型的形式，给 Core Data 开发者带来了惊喜，但这在其他框架和语言中早已被应用。相较于 Core Data，它有所进步，但不能算得上是彻底的革新。

然而，SwiftData 在实现这个概念上有其独特的创新之处。这主要得益于与 Swift 语言的紧密结合。通过创建并使用新出现的语言特性，SwiftData 以更简洁高效并符合现代编程思想的方式实现了声明式建模。

```responser
id:1
```

## 模型代码解析

在本节中，我们将对 SwiftData 的模型代码进行剖析，这些代码是以 Xcode 提供的 SwiftData 项目模板中的模型为基础，让我们揭开它神秘的面纱。

```swift
@Model
final class Item {
    var timestamp: Date = Date.now // 添加了默认值
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
```

### 宏（ Macro）的作用

如果不考虑宏标志 @Model，上面的代码与我们定义一个标准的 Swift 类完全一样。而 SwiftData 通过 @Model 宏，根据我们提供的简单表述，将其扩展为一个具备完整描述的数据模型。

在 Xcode 中展开宏，我们将可以看到经过宏扩展后的完整代码（@_PersistedProperty 可以展开两次）。

![swiftData-model-macro-expand-demo_2023-10-01_15.53.39.2023-10-01 15_54_37](https://cdn.fatbobman.com/swiftData-model-macro-expand-demo_2023-10-01_15.53.39.2023-10-01%2015_54_37.gif)

展开后完整的代码如下：

```swift
public final class Item {
    // 用户定义的持久化属性
    public var timestamp: Date = Date.now {
        // 构造器访问器，在构造实例的过程中，为计算属性添加构造能力
        @storageRestrictions(accesses: _$backingData, initializes: _timestamp)
        init(initialValue) {
            _$backingData.setValue(forKey: \.timestamp, to: initialValue)
            _timestamp = _SwiftDataNoType()
        }
        get {
            _$observationRegistrar.access(self, keyPath: \.timestamp)
            return self.getValue(forKey: \.timestamp)
        }
        set {
            _$observationRegistrar.withMutation(of: self, keyPath: \.timestamp) {
                self.setValue(forKey: \.timestamp, to: newValue)
            }
        }
    }

    // timestamp 对应的下划线版本，暂时未发现有实际用途
    @Transient
    private var _timestamp: _SwiftDataNoType = .init()

    // 用户自定义的构造器
    public init(timestamp: Date) {
        self.timestamp = timestamp
    }

    // 一个用来包装对应的托管对象（ NSManagedObject ）实例的类型，无需持久化（ @Transient ）
    @Transient
    private var _$backingData: any SwiftData.BackingData<Item> = Item.createBackingData()

    public var persistentBackingData: any BackingData<Item> {
        get {
            self._$backingData
        }
        set {
            self._$backingData = newValue
        }
    }

    // 为创建 Scheme 提供模型的元数据
    public static var schemaMetadata: [Schema.PropertyMetadata] {
        return [
            SwiftData.Schema.PropertyMetadata(name: "timestamp", keypath: \Item.timestamp, defaultValue: Date.now, metadata: nil),
        ]
    }

    // 从 backingData 构造 PersistentModel
    public init(backingData: any BackingData<Item>) {
        _timestamp = _SwiftDataNoType()
        self.persistentBackingData = backingData
    }

    // Observation 协议要求的观察注册器
    @Transient
    private let _$observationRegistrar: ObservationRegistrar = Observation.ObservationRegistrar()

    // 空类型，用于下划线版本的属性
    struct _SwiftDataNoType {}
}
// 遵守 PersistentModel 协议
extension Item: SwiftData.PersistentModel {}
// 遵守 Observable 协议
extension Item: Observation.Observable {}
```

下文将详细描述生成的代码的细节。

### 模型元数据

在 Core Data 中，开发者可以通过 Xcode 提供的数据模型编辑器生成 XML 格式的 .xcdatamodeld 文件。这个文件保存了用于创建数据模型（NSManagedObjectModel）的描述信息。

> 阅读 [CoreData 探秘 - 从数据模型构建到托管对象实例](https://www.fatbobman.com/posts/from-Data-Model-Construction-to-Managed-Object-Instances-in-Core-Data/) 一文，了解更多信息。

SwiftData 则通过 `Model` 宏，直接将上述描述信息集成在了声明代码的内部。

```swift
public static var schemaMetadata: [Schema.PropertyMetadata] {
    return [
        SwiftData.Schema.PropertyMetadata(name: "timestamp", keypath: \Item.timestamp, defaultValue: Date.now, metadata: nil),
    ]
}
```

每个符合 PersistentModel 协议的类都必须提供一个名为 schemaMetadata 的类属性。该属性详细记录了通过解析当前类型的持久化属性定义而生成的用于创建数据模型的元数据。

其中，`name` 对应数据模型的 Attribute Name，`keypath` 为当前类型对应属性的 KeyPath，`defaultValue` 对应属性在声明中设置的默认值（没有默认值，为 nil ），而 `metadata` 则包含了其他的信息，例如：关系描述、删除规则、原始名称等内容。

```swift
@Attribute(.unique, originalName: "old_timestamp")
var timestamp: Date = Date.now

static var schemaMetadata: [SwiftData.Schema.PropertyMetadata] {
  return [
    SwiftData.Schema.PropertyMetadata(name: "timestamp", keypath: \Item.timestamp, defaultValue: Date.now, metadata: SwiftData.Schema.Attribute(.unique, originalName: "old_timestamp"))
  ]
}
```

> defaultValue 与开发者在 Xcode 模型编辑器中为 Attribute 创建的默认值功能一致。由于 SwiftData 允许数据模型的属性声明为更为复杂的类型（枚举，符合 Encoded 协议的结构体等），因此，SwiftData 在构建模型时将通过给定的 KeyPath 来映射对应的存储类型，而且每个 PropertyMetadata 并非一定对应 SQLite 中的一个字段（可能会根据类型创建多个字段）。

SwiftData 将直接读取类属性 `schemaMetadata` 来完成 Schema 乃至 ModelContainer 的创建。

```swift
let schema = Schema([Item.self])
```

开发者可以使用 Core Data 的新 API `NSManagedObjectModel.makeManagedObjectModel`，通过为 SwiftData 声明的模型代码来生成对应的 NSManagedObjectModel：

```swift
let model = NSManagedObjectModel.makeManagedObjectModel(for: [Item.self])
```

### BackingData

每个 PersistentModel 实例的底层都对应了一个托管对象实例（ NSManagedObject ），它被包装在 `_DefaultBackingData` 类型中（ 符合 BackingData 协议 ）。

```swift
@Transient
private var _$backingData: any SwiftData.BackingData<Item> = Item.createBackingData()

public var persistentBackingData: any BackingData<Item> {
    get {
        self._$backingData
    }
    set {
        self._$backingData = newValue
    }
}
```

`createBackingData` 是 PersistentModel 协议提供的一个类方法，它通过获取**已经加载的数据模型**信息，创建一个符合 BackingData 协议的实例，比如：`_DefaultBackingData<Item>`

> 在调用 createBackingData 时，SwiftData 不能仅依赖当前类提供的 schemaMetadata 创建实例。换句话说，只有在创建了 ModelContainer 实例后，createBackingData 才能正确地构建 PersistentModel 实例。这一点与 Core Data 不同，Core Data 可以仅通过 NSEntityDescription 信息（无需加载 NSManagedObjectModel）创建实例。

下面是 [SwiftDataKit](https://github.com/fatbobman/SwiftDataKit) 中用于从 BackingData 中获取对应 NSManagedObject 实例的代码：

```swift
public extension BackingData {
    // Computed property to access the NSManagedObject
    var managedObject: NSManagedObject? {
        guard let object = getMirrorChildValue(of: self, childName: "_managedObject") as? NSManagedObject else {
            return nil
        }
        return object
    }
}

func getMirrorChildValue(of object: Any, childName: String) -> Any? {
    guard let child = Mirror(reflecting: object).children.first(where: { $0.label == childName }) else {
        return nil
    }

    return child.value
}
```

通过下面的代码，可以看到：

```swift
private var _$backingData: any SwiftData.BackingData<Item> = Item.createBackingData()
```

SwiftData 调用 `createBackingData` 来创建 `backingData` 的实例时，不需要 ModelContext（ NSMangedObjectContext ）的存在。其内部应该使用了如下的构建托管对象的方式：
```swift
let item = Item(entity: Item.entity(), insertInto: nil)
```

这点也解释了，为什么在 SwiftData 中，我们创建一个 PersistentModel 实例后，必须显式的将其注册（ insert ）到某个 ModelContext 上面。

```swift
let item = Item(timestamp:Date.now)
modelContext.insert(item) // must insert into some modelContext
```

由于 backingData（ `_DafaultBackingData` ）没有公开的构造方法，我们无法通过托管对象实例来构建该数据。PersistentModel 中的另一个构造方法是为 SwiftData 内部将托管对象转换为 PersistentModel 提供的。

```swift
public init(backingData: any BackingData<Item>) {
    _timestamp = _SwiftDataNoType()
    self.persistentBackingData = backingData
}
```

```responser
id:1
```

### Init Accessors

通过观察完整的展开代码，timestamp 被宏代码转换成了一个具备构造器的计算属性。

```swift
public var timestamp: Date = Date.now {
    @storageRestrictions(accesses: _$backingData, initializes: _timestamp)
    init(initialValue) {
        _$backingData.setValue(forKey: \.timestamp, to: initialValue)
        _timestamp = _SwiftDataNoType()
    }
    get {
        _$observationRegistrar.access(self, keyPath: \.timestamp)
        return self.getValue(forKey: \.timestamp)
    }
    set {
        _$observationRegistrar.withMutation(of: self, keyPath: \.timestamp) {
            self.setValue(forKey: \.timestamp, to: newValue)
        }
    }
}
```

那么，SwiftData 在构建 PersistentModel 实例时，是如何为其构建当前值的呢？先看一下下面的代码：

```swift
public init(timestamp: Date) {
    self.timestamp = timestamp
}

let item = Item(timestamp: Date.distantPast)
```

在 SwiftData 使用 `createBackingData` 创建 Item 实例时，首先会创建一个 timestamp 默认值为 `Date.now` 的 NSManagedObject 实例（通过 schemaMetadata 传递给 Schema，并包装在 backingData 中）。然后，通过初始化访问器（Init Accessors）为 timestamp 设置新的值（来自构造方法参数，`Date.distantPast`）。

[初始化访问器 (Init Accessors)](https://github.com/apple/swift-evolution/blob/main/proposals/0400-init-accessors.md#init-accessors) 是 Swift 5.9 中新增加的功能。它将计算属性纳入初始化分析（definite initialization analysis）。这样，在初始化方法中可以直接对计算属性赋值，它会转化成对应的存储属性的初始化值。

这段代码的含义是：

```swift
@storageRestrictions(accesses: _$backingData, initializes: _timestamp)
init(initialValue) {
    _$backingData.setValue(forKey: \.timestamp, to: initialValue)
    _timestamp = _SwiftDataNoType()
}
```

* `accesses: _$backingData` 表示在 `init` 中会访问 `_$backingData` 这个存储属性。这意味着在调用本 `init` 访问器初始化 `timestamp` 之前，必须先初始化 `_$backingData`。
* `initializes: _timestamp` 表示这个 `init` 访问器会初始化 `_timestamp` 这个存储属性。
* initialValue：对应传入构造方法参数的初始化值，本例中为 `Date.distantPast`

Init Accessors 作为 Swift 语言的新功能，相较属性包装器（ Property Wrapper ），提供了更统一、精细、明确和灵活的初始化模型。SwiftData 利用这一功能，在构造阶段对持久化属性进行显式赋值，减轻了开发者的工作量，也让模型代码的声明更符合 Swift 语言的逻辑。

### 与 Observation 框架融合

与 NSManagedObject 利用 Combine 框架提供的 Publisher 与 SwiftUI 的视图绑定不同，SwiftData 的 PersistentModel 采用了新的 Observation 框架。

> 请阅读 [深度解读 Observation —— SwiftUI 性能提升的新途径](https://www.fatbobman.com/posts/mastering-Observation/) ，了解更多有关 Observation 框架的信息。

为了满足 Observation 框架的需求，SwiftData 为模型代码添加了以下内容：
```swift
extension Item: Observation.Observable {}

public final class Item {
    // 用户定义的持久化属性
    public var timestamp: Date = .now {
        ....
        get {
            _$observationRegistrar.access(self, keyPath: \.timestamp)
            return self.getValue(forKey: \.timestamp)
        }
        set {
            _$observationRegistrar.withMutation(of: self, keyPath: \.timestamp) {
                self.setValue(forKey: \.timestamp, to: newValue)
            }
        }
    }
  
    ....
  
    // Observation 协议要求的观察注册器
    @Transient
    private let _$observationRegistrar: ObservationRegistrar = Observation.ObservationRegistrar()
}
```

通过在持久化属性的 get 和 set 方法中使用 `_$observationRegistrar` 来注册和通知观察者，实现了以属性为粒度的观察机制。这样做可以大幅减少因为无关属性变动而导致的视图无效更新。

从上面的注册方法中可以得知，开发者**必须显式调用持久化属性的 set 方法**，才能让观察者获取到数据变化的通知（调用 withObservationTracking 的 onChange 闭包）。

### Get 和 Set 方法

PersistentModel 协议定义了一些 get 和 set 方法，并提供了默认实现。例如：

```swift
public func getValue<Value, OtherModel>(forKey: KeyPath<Self, Value>) -> Value where Value : Decodable, Value : RelationshipCollection, OtherModel == Value.PersistentElement

public func getTransformableValue<Value>(forKey: KeyPath<Self, Value>) -> Value

public func setValue<Value>(forKey: KeyPath<Self, Value>, to newValue: Value) where Value : Encodable

public func setValue<Value>(forKey: KeyPath<Self, Value>, to newValue: Value) where Value : PersistentModel
```

通过这些方法，开发者可以读取或写入某个持久化属性。请注意，使用上述的 set 方法（例如：setValue）给属性设置新的值将会绕过 Observation 框架，属性订阅者将无法得到属性发生变化的通知（视图不会自动刷新）。同样，如果用 SwiftDataKit 直接改写 PersistentModel 底层对应的 NSManagedObject 实例的持久化属性，也不会产生通知。

```swift
item.setValue(forKey: \.timestamp, to: date) // 不通知 timestamp 的订阅者
item.timestamp = date // 通知 timestamp 的订阅者
```

>  BackingData 协议还提供了 get 和 set 方法的定义和默认实现。BackingData 提供的 setValue 方法只能修改 PersistentModel 对应的底层 NSManagedObject 属性，与通过 SwiftDataKit 修改托管对象实例的效果类似。直接使用该方法将导致底层 NSManagedObject 的数据与表层 PersistentModel 数据不一致。

除了提供与 NSManagedObject 的 get 和 set 方法类似的功能外，PersistentModel 协议提供的 get 和 set 方法还要执行其他操作，例如将 PersistentModel 的一个属性对应到 NSManagedObject 的多个属性（当属性为复杂类型时），以及线程调度（确保线程安全）等任务。

### 其他

除了上述的内容外，PersistentModel 协议还声明了其他几个属性：

* hasChanges：表示是否发生了改变，与 NSManagedObject 的同名属性功能类似。
* isDeleted：表示是否已添加到 ModelContext 的删除列表，与 NSManagedObject 的同名属性功能类似。
* modelContext：当前 PersistentModel 所注册的 ModelContext，在未通过 `insert` 进行注册前，该值为 nil

与 NSManagedObject 相比，SwiftData 目前仅暴露了有限的 API。随着 SwiftData 的不断发展，可能会提供更多功能供开发者使用。

## 总结

本文通过详细剖析一段 SwiftData 简单模型的代码，深入解析了其实现原理，包括模型构建、PersistentModel 实例生成以及属性观察通知机制等。剖析的过程也是熟练运用一个框架的重要途径。

在代码解析的过程中，我们不仅加深了对 SwiftData 框架的认识，也对许多 Swift 语言的新特性有了更直观的了解，可谓一举两得。

欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周最新文章。**