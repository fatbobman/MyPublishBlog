---
date: 2023-09-19 08:20
description: 对每一个使用 Core Data 的开发者来说，用 Xcode 的 Core Data 模型编辑器构建数据模型、创建容器、加载数据模型并通过托管对象上下文最终创建托管对象实例，这都是十分普通的过程。但你是否好奇过这一切的内部运行机制，Core Data 是如何在幕后辅助我们完成这一切的？本文将深入探究 Core Data 是如何通过数据模型构建出托管对象实例的内部运行机制，读完本文可以让你对 Core Data 的工作流程有更深入的理解，在开发中可以更得心应手。
tags: Core Data,持久化框架
title: CoreData 探秘 - 从数据模型构建到托管对象实例
image: images/from-Data-Model-Construction-to-Managed-Object-Instances-in-Core-Data.jpg
mediumURL: https://medium.com/p/3bc796b27b41
---
对每一个使用 Core Data 的开发者来说，用 Xcode 的 Core Data 模型编辑器构建数据模型、创建容器、加载数据模型并通过托管对象上下文最终创建托管对象实例，这都是十分普通的过程。但你是否好奇过这一切的内部运行机制，Core Data 是如何在幕后辅助我们完成这一切的？本文将深入探究 Core Data 是如何通过数据模型构建出托管对象实例的内部运行机制，读完本文可以让你对 Core Data 的工作流程有更深入的理解，在开发中可以更得心应手。

## 写在前面的话

最近我正在撰写有关 SwiftData 并发的文章。原计划在第一部分中探讨 SwiftData 如何根据模型声明来创建 PersistentModel 实例。本打算用几段文字阐明，但在写作时发现无法简单表述，必须将该部分独立成文。当我着手编写这篇文章时，又发现需要另一篇文章来具体说明 Core Data 版本的实现过程。由此偶然间诞生了这篇文章。

在本文中，我们不会深入讨论从构建数据模型到创建托管对象实例的每个细节。我们主要将探讨两个环节：Core Data 如何将模型文件转换为 ManagedObjectModel，以及它如何从中提取信息来创建托管对象实例。

> 本文将以 Xcode 创建的 Core Data 项目模版提供的数据模型文件作为讨论基础

```responser
id:1
```

## 用模型编辑器构建 Core Data 数据模型文件

Xcode 的模型编辑器为我们提供了一个可视化的界面来定义 Core Data 应用程序的数据模型，包括实体、属性等信息。使用模型编辑器可以更直观地构建数据模型。

当新建项目选择包含 Core Data 时，Xcode 会在项目中自动创建一个名为 `ProjectName.xcdatamodeld` 的数据模型文件（ Core Data Model Bundle ）。我们也可以自行在项目中创建 Core Data 数据模型文件，其文件扩展名为 `.xcdatamodeld`。

![image-20230918092422868](https://cdn.fatbobman.com/image-20230918092422868.png)

![image-20230918092749973](https://cdn.fatbobman.com/image-20230918092749973.png)

Xcode 将开发者在模型编辑器中创建的一切信息都保存在 xcdatamodeld 中。

确切来说，xcdatamodeld 是一个目录，通常被称为 "Core Data Model Bundle"。它是一个特殊的 Bundle，用于存储和管理 Core Data 的数据模型信息。它包含了一个或多个数据模型文件（`.xcdatamodel`）以及其他与数据模型相关的信息。Xcode 会在 xcdatamodeld 中为每个模型版本分别创建一个 `VersionName.xcdatamodel` 的 Bundle。

现在，用文本编辑器打开 `xcdatamodel` 中的 `content` 文件，可以看到，当前版本的所有模型信息，都是以 XML 的格式保存在其中。

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<model type="com.apple.IDECoreDataModeler.DataModel" documentVersion="1.0" lastSavedToolsVersion="1" systemVersion="11A491" minimumToolsVersion="Automatic" sourceLanguage="Swift" usedWithCloudKit="false" userDefinedModelVersionIdentifier="">
    <entity name="Item" representedClassName="Item" syncable="YES" codeGenerationType="class">
        <attribute name="timestamp" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
    </entity>
    <elements>
        <element name="Item" positionX="-63" positionY="-18" width="128" height="44"/>
    </elements>
</model>
```

其中，每个 entity 元素对应一个 Entity，包含了实体名称、对应的子类名称、属性、关系、自定义索引等众多信息。如果我们在模型编辑器中创建了新的 Configuration 或 Fetch Request ，也能在 XML 文件中找到对应的信息。在 Xcode 14 中，可视化的关系视图被取消了。这个关系视图在模型编辑器中起到了重要的作用，可以直观地显示实体之间的关系。由于取消了可视化的关系视图，`elements` 元素中的信息基本上失去了作用。

Xcode 在编译项目时，会将 `.xcdatamodel` 目录以 `momd` 为尾椎添加到应用的资源中，其中的 `xcdatamode`  Bundle 会编译成尾缀为 `mom` 的二进制文件，一方面减少空间占用，另一方面也可以提高加载速度。这也是当我们用代码加载模型文件时，尾缀需要设置为 `momd` 的原因。

开发者应该了解的是，我们通过 Xcode 的模型编辑器创建的模型文件只是一种对模型的结构化表达，并非程序化表达。

## 生成实体对应的 NSManagedObject 子类声明

在绝大多树情况下，开发者都会为 Entity 创建对应的 NSManageObject 子类声明。当 Codegen 设置为 Class Definition 或 Category/Extension 时，Xcode 会隐式的帮我们完成这项工作。

![image-20230918143644990](https://cdn.fatbobman.com/image-20230918143644990.png)

当 Codegen 设置为 Class Definition 时，Xcode 会生成一个独立的 NSManagedObject 子类，其中包含了实体属性和方法的定义。例如：

```swift
@objc(Item)
public class Item: NSManagedObject {}

extension Item {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Item> {
        return NSFetchRequest<Item>(entityName: "Item")
    }

    @NSManaged public var timestamp: Date?
}

extension Item : Identifiable {}
```

当 Codegen 设置为 Category/Extension 时，Xcode 会生成一个扩展，将实体属性和方法添加到 NSManagedObject 的默认实现中。这样可以避免修改自动生成的代码，保持代码的可维护性。

> `@NSManaged` 是一个属性修饰符，用于标记一个被 Core Data 管理的属性。它告诉编译器这个属性将由 Core Data 自动生成相关的存取方法，并且在运行时会动态地与托管对象上的属性进行关联。

开发者也可以选择手动创建这些代码，或使用 Xcode 显式生成。手动创建代码可以更准确地表达属性类型，并且灵活性更高。使用 Xcode 生成代码可以省去手动编写的工作量，特别是在属性较多或模型结构复杂的情况下。无论选择哪种方式，生成一个符合 NSManagedObject 的子类声明，可以让开发者更加安全、方便地访问托管对象的托管属性，并且通过重写子类的某些方法（例如：willSave），可以将某些操作特定到具体的实体上。

```swift
extension Item {
    public override func willSave() {
        super.willSave()
        // do something
    }
}
```

尽管可以获得上述优势，**但为实体声明一个对应的 NSManagedObject 的子类并非是必须的**。这是因为 Core Data 也提供了一种轻量级的方式来访问和操作托管对象，即使用 `NSManagedObject` 对象本身来进行属性访问和操作。

```swift
// item:Item
let timestamp = item.timestamp
// object is a NSManagedObject instance create by Item Entity description
let timestamp = object.value(forKey: "timestamp") // trigger KVO
let timestamp = object..primitiveValue(forKey: "timestamp") // not trigger KVO
```

在上面的示例中，`item.timestamp` 是通过为实体 `Item` 声明一个对应的 NSManagedObject 的子类（ `Item`）来实现的，而 `object.value(forKey:)` 和 `object.primitiveValue(forKey:)` 是通过 `NSManagedObject` 对象本身来访问属性的方法。需要注意的是，`value(forKey:)` 方法会触发 Key-Value Observing (KVO)，而 `primitiveValue(forKey:)` 方法则不会触发 KVO。

> 在某种程度上，我们可以将 `@NSManaged` 视作与 Swift 的计算属性类似的机制。通过 `value(forKey:)` 和 `setValue(_:forKey:)` 方法，我们可以读取和设置托管对象的底层值。这使得我们可以在需要的时候对属性进行自定义的逻辑操作，例如数据格式转换、数据校验等。

## 加载数据模型，创建 Container

自从 Core Data 提供了 NSPersistentContainer 后，除非特别情况，开发者几乎都不会在代码中显式地读取数据模型文件并创建数据模型了（ NSManageObjectModel ）。

```swift
let container = NSPersistentContainer(name: "ModelEditorDemo")
```

然而，了解 Core Data 在创建 container 的背后所做的工作，对于之后理解托管对象实例的创建过程仍然非常有帮助。

```swift
// Load the data model file and create NSManagedObjectModel
guard let url = Bundle.main.url(forResource: "ModelEditorDemo", withExtension: "momd"),
      let dataModel = NSManagedObjectModel(contentsOf: url) else {
     fatalError("Failed to load the data model file")
}

// Create the persistent store coordinator
let coordinator = NSPersistentStoreCoordinator(managedObjectModel: dataModel)

// Get the configuration from the data model
let configuration = dataModel.configurations.first!

// Create the URL for the persistent store
let storeURL = URL.applicationDirectory.appending(path: "store.sqlite")

// Create or load the persistent store with the specified configuration
guard let store = try? coordinator.addPersistentStore(type: .sqlite, configuration: configuration,at: storeURL,options: nil) else {
    fatalError("Failed to create persistent store: \(error)")
}

// Create a main queue NSMangedObjectContext
let viewContext = NSManagedObjectContext(.mainQueue)
// Link context to coordinator
viewContext.persistentStoreCoordinator = coordinator
```

大致的流程如下：

1. 获取数据模型文件（momd）的 URL。

2. 使用该 URL 创建一个 NSManagedObjectModel 实例。

3. 使用 NSManagedObjectModel 实例创建一个 NSPersistentStoreCoordinator 实例。

4. 在 NSPersistentStoreCoordinator 实例上添加一个持久化存储。

5. 创建一个主线程的托管对象上下文。

6. 将上下文与 NSPersistentStoreCoordinator 实例关联。

其中，在使用数据模型文件 URL 来创建 NSManagedObjectModel 实例的时候，Core Data 会将模型文件中的描述率先转换成对实体的程序式表达，然后再通过这些程序式表达创建 NSManagedObjectModel 实例。这种转换过程使得我们能够以编程方式来创建和操作数据模型，而不仅限于使用可视化编辑器。

```responser
id:1
```

## 以编程的方式来描述实体，创建数据模型实例

除了使用数据模型编辑器进行可视化操作外，Core Data 提供了以编程的方式来表述实体并创建数据模型的方式。

下面的代码，展示了编程化的方式来描述 Item 实体并创建数据模型的过程。

```swift
func createModel() -> NSManagedObjectModel {
    let itemEntityDescription = NSEntityDescription()
    // Entity Name
    itemEntityDescription.name = "Item"
    // NSManagedObject SubClass Name
    itemEntityDescription.managedObjectClassName = "Item"
    // Descriptor timestamp attribute
    let timestampAttribute = NSAttributeDescription()
    // Attribute Name
    timestampAttribute.name = "timestamp"
    // Is Optional
    timestampAttribute.isOptional = true
    // Attribute Type
    if #available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *) {
        timestampAttribute.type = .date
    } else {
        timestampAttribute.attributeType = .dateAttributeType
    }
    // Add timestamp to Item
    itemEntityDescription.properties.append(timestampAttribute)
    // Create a empty NSManagedObject
    let model = NSManagedObjectModel()
    // Add Item Entity into model
    model.entities = [itemEntityDescription]
    return model
}
```

上面的代码几乎与我们在模型编辑器中所做的操作一一对应。然而，当属性数量众多或关系复杂时，可视化操作更加高效和便利。通过可视化操作，我们可以直观地在图形界面中添加、编辑和删除实体、属性和关系，而不需要手动编写大量的代码。这使得数据模型的创建和维护变得更加容易和快速。

现在我们就可以用这段代码，替换掉之前通过数据模型文件创建 NSManagedObjectModel 的操作。

```swift
// Create data model by programming way
let dataModel = createModel()
        
// Create persistent store coordinator by dataModel
let coordinator = NSPersistentStoreCoordinator(managedObjectModel: dataModel)
```

尽管可视化编辑更加高效，不过编程式表述为开发者提供更广阔的数据模型描述的空间，可以将自定义的描述方式映射为 Core Data 可以接受的程序化表达。这种灵活性使得开发者能够更好地满足特定的业务需求，另外，编程方式还可以提供更多的类型安全和编译时检查，减少了在运行时出现错误的可能性。

## 创建托管对象实例

Core Data 是一个对象图管理框架，我们构建数据模型的目的是为了以面向对象的方式操作持久化数据。具体的数据操作通常会在托管对象实例上进行。

最常见的获取托管对象实例的途径有两种：

* 设置谓词，通过 NSFetchRequest ，Core Data 将符合条件数据以托管对象的形式返回给开发者
* 通过直接调用与 Entity 对应的 NSManagedObject 子类的构造方法创建托管对象实例

开发者惯常使用下面这种方式创建托管对象实例：

```swift
let item = Item(context: viewContext)
item.timestamp = .now
try? viewContext.save()
```

然而 `init(context:)` 要求我们必须首先创建托管对象上下文（ NSManagedObjectContext ），其实，在 Core Data 中，我们完全可以在没有上下文的情况下来创建托管对象实例。

```swift
let item = Item(entity: Item.entity(), insertInto: nil)
item.timestamp = .now
viewContext.insert(item)
try? viewContext.save()
```

事实上，`init(entity:, insertInto:)` 构造方法是 NSManagedObject 的指定初始化器（designated initializer），而 `init(context:)` 是其便捷初始化器（convenience initializer）。创建托管对象实例的关键并不在于是否有托管对象上下文，而在于告诉 NSManagedObject，该实例对应的是哪个 EntityDescription。

需要注意的是，当我们使用 `Item.entity()` 来获取 Item 对应的 EntityDescription 时，需确保 NSManagedObjectModel 已经被 NSPersistentStoreCoordinator 加载。

```swift
let coordinator = NSPersistentStoreCoordinator(managedObjectModel: dataModel)
```

在 Core Data 中，当 NSPersistentStoreCoordinator 被创建后，数据模型会被保存在一个可供内部元素访问的位置，以便获取。`Item.entity()` 方法会从中获取 Item 对应的 EntityDescription。如果我们在创建 NSPersistentStoreCoordinator 时没有使用包含 Item 的数据模型，或根本没有创建 NSPersistentStoreCoordinator，调用 `Item.entity()` 后，Core Data 会抛出如下错误：

```she
CoreData: error: No NSEntityDescriptions in any model claim the NSManagedObject subclass 'Item' so +entity is confused.  Have you loaded your NSManagedObjectModel yet ?
```

这并不意味着我们没有其他方法可以绕过 NSPersistentStoreCoordinator 的限制。

```swift
guard let url = Bundle.main.url(forResource: "ModelEditorDemo", withExtension: "momd"),
      let dataModel = NSManagedObjectModel(contentsOf: url) else {
     fatalError("Failed to load the data model file")
}

let entityDescription = dataModel.entitiesByName["Item"]!
let item = Item(entity: entityDescription, insertInto: nil)
```

通过直接从 NSManagedObjectModel 获取对应的 EntityDescription，开发者可以在仅拥有 NSManagedObjectModel 实例的情况下，就具备了创建托管对象实例的条件。这对于某些特定情况下，只需要操作数据模型而无需操作托管对象上下文的场景非常有用。

> 阅读 [如何在 Xcode 下预览含有 Core Data 元素的 SwiftUI 视图](https://fatbobman.com/posts/coreDataInPreview/) 一文，查看此种方法在 SwiftUI 预览中的应用。

正如前文所提到的，开发者并不一定要创建托管对象子类的实例。通过使用正确的 EntityDescription，我们可以创建 NSManagedObject 实例，在许多场景下可以达到同样的效果。

```swift
let item = NSManagedObject(entity: Item.entity(), insertInto: nil)
item.setValue(Date.now, forKey: "timestamp")
viewContext.insert(item)
try? viewContext.save()
```

## 最后

在本文中，我们探讨了几种不同的在 Core Data 中构建数据模型和创建托管对象实例的方法，其中一些方法可能并不常见。有些读者可能会对这些方法感到困惑，但即使不了解这些方法，也不会影响我们熟练使用 Core Data。然而，本文创作的目的正是向读者介绍这些非常见的方法，因为在接下来的文章中，我们将探讨 “SwiftData 如何根据模型声明来创建 PersistentModel 实例”。届时，我们将看到 SwiftData 开发团队是如何利用本文介绍的内容和 Swift 的新特性，构建出符合新时代的持久化框架的。

