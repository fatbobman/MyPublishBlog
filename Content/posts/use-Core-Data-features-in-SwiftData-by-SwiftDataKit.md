---
date: 2023-09-07 08:12
description: 作为 Core Data 的继任者，全新的 SwiftData 框架在 WWDC 2023 上正式发布。SwiftData 预计会在未来很长一段时间内成为苹果生态系统的主要对象图管理和数据持久化解决方案，为开发者提供服务与支持。本文将讨论，在不使用 Core Data 数据栈的情况下，开发者如何在 SwiftData 中调用 Core Data 提供的高级功能，以扩展 SwiftData 目前的能力。
tags: SwiftData,Core Data,持久化框架
title: SwiftDataKit：让你在 SwiftData 中使用 Core Data 的高级功能
image: images/use-Core-Data-features-in-SwiftData-by-SwiftDataKit.jpg
mediumURL: https://medium.com/p/3fcd5f443c99
---
作为 Core Data 的继任者，全新的 SwiftData 框架在 WWDC 2023 上正式发布。SwiftData 预计会在未来很长一段时间内成为苹果生态系统的主要对象图管理和数据持久化解决方案，为开发者提供服务与支持。本文将讨论，在不使用 Core Data 数据栈的情况下，开发者如何在 SwiftData 中调用 Core Data 提供的高级功能，以扩展 SwiftData 目前的能力。

## SwiftData 当前的困境

与 Core Data 相比，SwiftData 在数据模型声明、类型安全、线程安全、以及与 SwiftUI 整合等多个方面进行了全面提升。其中，它基于 Swift 宏功能的数据模型创建机制、类型安全的谓词系统、依靠 Actor 实现的线程安全以及与 [Observation](https://www.fatbobman.com/posts/mastering-Observation/) 框架的紧密结合，使得 SwiftData 更符合现代编程的需求。

然而，可能是由于准备时间不足，当前版本的 SwiftData 还无法实现 Core Data 中的一些高级功能。这就给想尝试 SwiftData 的开发者带来了一定的困扰。即使，开发者可以接受将项目的最小部署环境设置为最新的系统版本（ iOS 17、macOS 14 等），也难免需要在项目中同步创建一套基于 Core Data 的数据模型和数据栈，以实现 SwiftData 所缺少的功能。

如此一来，SwiftData 在数据模型声明上的优势便当然无存，不仅增加了工作量，开发者还需要面对如何处理两个数据框架、模型版本之间的协作问题。仅为实现一些高级功能，就在 SwiftData 的项目中创建一套并行的 Core Data 代码，无疑是十分不经济的。

正是由于上述困难，我一直难以下定决心在新项目中使用 SwiftData。

## 解决 SwiftData 困境的思路

虽然 SwiftData 在表现上与 Core Data 存在很大差异，但是它的核心基础仍然是 Core Data，苹果使用了 Swift 语言的新功能，用符合当代编程风格的设计思想，对 Core Data 进行了二次构建。这不仅使 SwiftData 继承了 Core Data 在数据持久化领域的稳定特质，也意味着 SwiftData 的部分关键组件背后对应着特定的 Core Data 对象。如果我们能够提取出这些对象，在安全的环境中进行有限度的使用，就可以在 SwiftData 中使用 Core Data 的高级功能。

通过 Swift 语言提供的反射 ( Mirror ) 功能，我们可以从 SwiftData 的某些组件中提取出需要的 Core Data 对象，例如从 PersistentModel 中提取出 NSManagedObject，从 ModelContext 中提取出 NSManagedContext。另外，SwiftData 的 PersistentIdentifier 符合 Codable 协议，这使我们可以在它与 NSManagedObjectID 之间进行转换。

```responser
id:1
```

## SwiftDataKit

根据前文的思路，我开发了 [SwiftDataKit](https://github.com/fatbobman/SwiftDataKit) 库，它允许开发者使用 SwiftData 组件背后的 Core Data 对象，以实现当前版本无法完成的功能。

例如，下面是从 ModelContext 中提取 NSManagedObjectContext 的代码示例：

```swift
public extension ModelContext {
    // Computed property to access the underlying NSManagedObjectContext
    var managedObjectContext: NSManagedObjectContext? {
        guard let managedObjectContext = getMirrorChildValue(of: self, childName: "_nsContext") as? NSManagedObjectContext else {
            return nil
        }
        return managedObjectContext
    }

    // Computed property to access the NSPersistentStoreCoordinator
    var coordinator: NSPersistentStoreCoordinator? {
        managedObjectContext?.persistentStoreCoordinator
    }
}

func getMirrorChildValue(of object: Any, childName: String) -> Any? {
    guard let child = Mirror(reflecting: object).children.first(where: { $0.label == childName }) else {
        return nil
    }

    return child.value
}
```

接下来，我将通过几个具体案例，简要介绍 SwiftDataKit 的使用方法和注意事项。

>SwiftDataKit 是一个实验性质的库。由于 SwiftData API 仍在快速演化中，我建议只有了解其实现原理且明确风险的有经验开发者，在特定场景下谨慎使用。

## 利用 NSManagedObjectContext 实现分组计数

在某些场景下，我们需要对数据进行分组后计数，比如统计不同出生年份的学生人数。

```swift
@Model
class Student {
    var name: String
    var birthOfYear: Int

    init(name: String, birthOfYear: Int) {
        self.name = name
        self.birthOfYear = birthOfYear
    }
}
```

SwiftData 的新谓词系统目前尚不支持分组统计，使用原生方法如下所示：

```swift
func birthYearCountByQuery() -> [Int: Int] {
    let description = FetchDescriptor<Student>(sortBy: [.init(\Student.birthOfYear, order: .forward)])
    let students = (try? modelContext.fetch(description)) ?? []
    let result: [Int: Int] = students.reduce(into: [:]) { result, student in
        let count = result[student.birthOfYear, default: 0]
        result[student.birthOfYear] = count + 1
    }
    return result
}
```

开发者需获取全部数据在内存中进行分组统计。数据量大时，这种方法对性能和内存占用的影响极大。

有了 SwiftDataKit，我们可以**直接使用 ModelContext 底层的 NSManagedObjectContext**，通过创建 NSExpressionDescription，在 SQLite 数据库端完成该操作。

```swift
func birthYearCountByKit() -> [Int: Int] {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Student")
    fetchRequest.propertiesToGroupBy = ["birthOfYear"]
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "birthOfYear", ascending: true)]
    fetchRequest.resultType = .dictionaryResultType
    let expressDescription = NSExpressionDescription()
    expressDescription.resultType = .integer64
    expressDescription.name = "count"
    let year = NSExpression(forKeyPath: "birthOfYear")
    let express = NSExpression(forFunction: "count:", arguments: [year])
    expressDescription.expression = express
    fetchRequest.propertiesToFetch = ["birthOfYear", expressDescription]
    // modelContext.managedObjectContext, use NSManagedObjectContext directly
    let fetchResult = (try? modelContext.managedObjectContext?.fetch(fetchRequest) as? [[String: Any]]) ?? []
    let result: [Int: Int] = fetchResult.reduce(into: [:]) { result, element in
        result[element["birthOfYear"] as! Int] = (element["count"] as! Int?) ?? 0
    }
    return result
}
```

在 10000 条数据的测试中，基于 SwiftDataKit 的实现方法，效率是原生方法的 4 至 5 倍，内存占用也少了许多。

使用 SwiftDataKit 时有几点需要注意：

* 尽管未声明 Core Data 版本的数据模型类型，但可以用字符串方式访问 Entity 和属性。默认情况下，SwiftData 中的模型类型名对应 Entity 名，变量名对应属性名。
* 不推荐使用 `setPrimitiveValue(value:, forKey:)`、`value(forKey:)` 等方式读写 NSManagedObject 属性数据，缺乏编译检查。
* SwiftData 使用 [Actor](https://twitter.com/fatbobman/status/1694162814406123680) 保证数据操作在 ModelContext 所在线程中进行，所以在 Actor 方法内不需采用 `context.perform` 避免线程问题。

```swift
@ModelActor
actor StudentHandler {
    func birthYearCountByKit() -> [Int: Int] {
        ...
        // No need to use modelContext.managedObjectContext.perform { ... }
    }

    func birthYearCountByQuery() -> [Int: Int] {
        ...
    }
}
```

* 与 Core Data 可以明确创建私有上下文（ 运行于非主线程）不同，通过 @ModelActor 创建的 actor 实例所绑定的线程与创建时的上下文有关（ _inheritActorContext ）。

## 将 PersistentModel 转换为 NSManagedObject，实现子查询

在 Core Data 中，开发者可以通过创建子查询（SubQuery）谓词，直接在 SQLite 端实现嵌套查询，这对某些场景是必不可缺的功能。

比如我们有以下数据模型定义：

```swift
@Model
class ArticleCollection {
    var name: String
    @Relationship(deleteRule: .nullify)
    var articles: [Article]
    init(name: String, articles: [Article] = []) {
        self.name = name
        self.articles = articles
    }
}

@Model
class Article {
    var name: String
    @Relationship(deleteRule: .nullify)
    var category: Category?
    @Relationship(deleteRule: .nullify)
    var collection: ArticleCollection?
    init(name: String, category: Category? = nil, collection: ArticleCollection? = nil) {
        self.name = name
        self.category = category
        self.collection = collection
    }
}

@Model
class Category {
    var name: String
    @Relationship(deleteRule: .nullify)
    var articles: [Article]
    init(name: String, articles: [Article] = []) {
        self.name = name
        self.articles = articles
    }

    enum Name: String, CaseIterable {
        case tech, health, travel
    }
}
```

在这种模型关系（ `ArticleCollection <-->> Article <<--> Category` ）下，我们想查询有多少个 ArticleCollection 中的任意 Article 属于特定的 Category。

当前，使用 SwiftData 的原生方法如下所示：

```swift
func getCollectCountByCategoryByQuery(categoryName: String) -> Int {
    guard let category = getCategory(by: categoryName) else {
        fatalError("Can't get tag by name:\(categoryName)")
    }
    let description = FetchDescriptor<ArticleCollection>()
    let collections = (try? modelContext.fetch(description)) ?? []
    let count = collections.filter { collection in
        !(collection.articles).filter { article in
            article.category == category
        }.isEmpty
    }.count
    return count
}
```

与上文的方式类似，需要获取全部数据在内存中进行过滤统计。

通过将 PersistentModel 转换成 NSManagedObject，我们可以用包含子查询的谓词提高效率：

```swift
func getCollectCountByCategoryByKit(categoryName: String) -> Int {
    guard let category = getCategory(by: categoryName) else {
        fatalError("Can't get tag by name:\(categoryName)")
    }
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ArticleCollection")
    // get NSManagedObject by category.managedObject
    guard let categoryObject = category.managedObject else {
        fatalError("can't get managedObject from \(category)")
    }
    // use NSManagedObject in Predicate
    let predicate = NSPredicate(format: "SUBQUERY(articles,$article,$article.category == %@).@count > 0", categoryObject)
    fetchRequest.predicate = predicate
    return (try? modelContext.managedObjectContext?.count(for: fetchRequest)) ?? 0
}

// fetch category by name
func getCategory(by name: String) -> Category? {
    let predicate = #Predicate<Category> {
        $0.name == name
    }
    let categoryDescription = FetchDescriptor<Category>(predicate: predicate)
    return try? modelContext.fetch(categoryDescription).first
}
```

在示例中，是通过 Category 的 name 来创建谓词并获取数据。通常我们也会用 PersistentIdentifier 在不同 ModelContext 间进行安全传递。这时可以：

```swift
func getCategory(by categoryID:PersistentIdentifier) -> Category? {
    let predicate = #Predicate<Category> {
        $0.id == categoryID
    }
    let categoryDescription = FetchDescriptor<Category>(predicate: predicate)
    return try? modelContext.fetch(categoryDescription).first
}
```

> SwiftData 在多线程开发方面与 Core Data 类似，只是形式不同。阅读 [关于 Core Data 并发编程的几点提示](https://www.fatbobman.com/posts/concurrencyOfCoreData/) 一文，了解 Core Data 在这方面的更多注意事项。

```responser
id:1
```

## 将 NSManagedObject 转换为 PersistentModel

有人可能会问，我们只能用 SwiftDataKit 返回统计数据吗？是否可以将 NSFetchRequest 获取的 NSManagedObject 转换为 PersistentModel 在 SwiftData 中使用？

与前面需求类似，这里我们想获取有哪些 ArticleCollection 的任意 Article 属于特定 Category。

利用 PersistentIdentifier 的 decode 构造方法，SwiftDataKit 支持将 NSManagedObjectID 转换为 PersistentIdentifier，用下面的代码，我们将获得所有符合条件的 ActicleCategory 的 PersistentIdentifier。

```swift
func getCollectPersistentIdentifiersByTagByKit(categoryName: String) -> [PersistentIdentifier] {
    guard let category = getCategory(by: categoryName) else {
        fatalError("Can't get tag by name:\(categoryName)")
    }
    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ArticleCollection")
    guard let categoryObject = category.managedObject else {
        fatalError("can't get managedObject from \(category)")
    }
    let predicate = NSPredicate(format: "SUBQUERY(articles,$article,$article.category == %@).@count > 0", categoryObject)
    fetchRequest.predicate = predicate
    fetchRequest.sortDescriptors = [.init(key: "name", ascending: true)]
    let collections = (try? modelContext.managedObjectContext?.fetch(fetchRequest)) ?? []
    // convert NSManageObjectID to PersistentIdentifier by SwiftDataKit
    return collections.compactMap(\.objectID.persistentIdentifier)
}
```

然后根据 PersistentIdentifier 获取对应的 PersistentModel 实例：

```swift
func convertIdentifierToModel<T: PersistentModel>(ids: [PersistentIdentifier], type: T.Type) -> [T] {
    ids.compactMap { self[$0, as: type] }
}
```

> 在 SwiftData 中，提供了两种不使用谓词，通过 PersistentIdentifier 获取 PersistentModel 的方法，用法和区别我在这篇 [推文](https://twitter.com/fatbobman/status/1699028201287356733) 中进行了说明。

![image-20230906200531775](https://cdn.fatbobman.com/image-20230906200531775.png)

通过这些示例，开发者基本可以在不创建 Core Data 数据模型和数据栈的情况下，在 SwiftData 中使用 Core Data 各种高级功能。

## 与 Core Data Stack 进行数据交换

如果直接操作 SwiftData 底层对象仍无法满足需求，则需要创建并行的 Core Data 数据模型和数据栈，并在 SwiftData 和 Core Data 代码间进行数据交换。

由于 NSManagedObjectID 在不同 NSPersistentStoreCoordinator 间无法保持一致，可以使用 SwiftDataKit 提供的如下功能：

- 将 PersistentIdentifier 转换为 uriRepresentation
- 将 uriRepresentation 转为 PersistentIdentifier

```swift
// convert persistentIdentifier to uriRepresentation
category.id.uriRepresentation

// convert uriRepresentation to persistentIdentifier
uriRepresentation.persistentIdentifier
```

这样就可以在 SwiftData 栈与 Core Data 栈之间安全地传递数据。

## 总结

通过本文的讨论和示例，我们可以看到，虽然当前 SwiftData 还无法实现 Core Data 的所有高级功能，但通过 SwiftDataKit 提供的接口与工具，开发者可以相对轻松地在 SwiftData 中继续使用 Core Data 的优秀特性。这将大大降低新项目全面采用 SwiftData 的门槛，无需同步维护一套 Core Data 的数据模型与数据栈。

当然，SwiftDataKit 仅是一个过渡时期的解决方案。随着 SwiftData 不断地完善，它会加入越来越多的新功能。我们期待在不久的将来，SwiftData 能成为一个功能完备、简单易用的下一代 Core Data。

PS：SwiftDataKit 目前提供的功能还很有限，欢迎更多的开发者可以参与该项目，让大家能够尽早享受到使用 SwiftData 开发所能带来的爽快感。

欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周最新文章。**
