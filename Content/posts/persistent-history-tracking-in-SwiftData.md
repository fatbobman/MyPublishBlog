---
date: 2023-11-02 08:12
description: 在数据库发生变化时 Persistent History Tracking（ 持久化历史跟踪 ）会向订阅者发送提醒，开发者可以借此机会对同一数据库进行的修改做出响应，包括其他应用、组件（同一个 App Group）和批处理任务。由于 SwiftData 集成了对持久化历史跟踪功能的支持，无需编写额外的代码，订阅通知、合并事务等工作都会由 SwiftData 自动完成。然而，在某些情况下，开发者可能希望自行响应持久化历史跟踪的事务，以获得更多的灵活性。本文将介绍如何在 SwiftData 中通过持久化历史跟踪观察特定数据变化的方法。
tags: SwiftData,持久化框架
title: 如何通过 Persistent History Tracking 观察 SwiftData 的数据变化
image: images/persistent-history-tracking-in-SwiftData.jpg
mediumURL: https://medium.com/p/77ceff2cb689
---
在数据库发生变化时 Persistent History Tracking（ 持久化历史跟踪 ）会向订阅者发送提醒，开发者可以借此机会对同一数据库进行的修改做出响应，包括其他应用、组件（同一个 App Group）和批处理任务。由于 SwiftData 集成了对持久化历史跟踪功能的支持，无需编写额外的代码，订阅通知、合并事务等工作都会由 SwiftData 自动完成。

然而，在某些情况下，开发者可能希望自行响应持久化历史跟踪的事务，以获得更多的灵活性。本文将介绍如何在 SwiftData 中通过持久化历史跟踪观察特定数据变化的方法。

## 为什么要自行响应持久化历史跟踪事务

SwiftData 中集成了对持久化历史跟踪的支持，使视图能够及时正确地响应数据变化，这对于来自网络、其他应用或小组件对数据的修改很有帮助。但是，在某些情况下，开发者需要自行响应持久化历史跟踪事务，而不仅仅停留在视图层面。

自行响应持久化历史跟踪事务的原因如下：

1. 处理与其他功能的集成：SwiftData 可能无法与某些功能或框架完全集成，例如 [NSCoreDataCoreSpotlightDelegate](https://fatbobman.com/posts/spotlight/)，这时需要自行处理事务来调整 Spotlight 中的展示。
2. 对特定数据变化执行操作：当数据变化时，开发者可能需要执行额外逻辑或操作，自行响应可以仅针对变化的数据执行，从而降低操作成本。
3. 扩展功能：自行响应可以给开发者更大的灵活性和扩展性，根据需要实现 SwiftData 现在无法完成的功能。

总之，自行响应持久化历史跟踪事务可以为开发者提供更多操作空间，来处理集成问题、特定数据变化、以及扩展功能。这能让开发者更好地利用持久化历史跟踪，以满足各种需求。

```responser
id:1
```

## Persistent History Tracking 在 Core Data 中的处理逻辑

在 Core Data 中处理持久化历史跟踪涉及以下步骤：

1. 为不同的数据操作者（应用、小组件）设置不同的事务作者：可以使用`transactionAuthor` 属性为每个数据操作者（应用、小组件）分配唯一的名称。这样可以区分不同的数据操作者，使每个操作者的事务可以被正确地标识。

2. 在共享容器中保存每个数据操作者的最后获取事务的时间戳：可以使用`UserDefaults`将每个数据操作者的最后获取事务的时间戳保存在 App Group 的共享容器中的某个位置。这样可以在后续的处理中，根据时间戳来获取从上次合并后新产生的所有持久化历史跟踪事务。

3. 开启持久化历史跟踪功能并响应通知：在 Core Data Stack 中，需要启用持久化历史跟踪功能，并注册对持久化历史跟踪通知的观察者。

4. 获取新产生的持久化历史跟踪事务：在接收到持久化历史跟踪通知后，可以根据上一次获取事务的时间戳，从持久化历史跟踪存储中获取新产生的事务。通常，只需要获取非当前数据操作者（应用、小组件）产生的事务。

5. 处理事务：对获取的持久化历史跟踪事务进行处理，例如将变化合并到当前的视图上下文中。

6. 更新最后获取时间戳：在处理完事务后，将本次获取的最新事务的时间戳设置为最后获取时间戳，以便下次获取时只获取新的事务。

7. 清除已合并的事务：在确保所有数据操作者都已处理完事务后，可以根据需要清除已合并的事务。

NSPersistentCloudContainer 会自动合并来自网络的同步事务，开发者无需自行处理。

> 阅读 [在 CoreData 中使用持久化历史跟踪](https://fatbobman.com/posts/persistentHistoryTracking/) 一文，了解完整的实现细节。

## Persistent History Tracking 在 SwiftData 中的特别之处

在 SwiftData 中使用持久化历史跟踪与 Core Data 类似，但也有一些特别之处：

1. 视图层面的数据合并：SwiftData 能够自动处理视图层面的数据合并，因此开发者无需手动处理事务的合并操作。

2. 事务清除：为了保证在同一个 App Group 中的其他使用 SwiftData 的成员都能正确获取到事务，不对已经处理过的事务进行清除。

3. 时间戳的保存：每个使用 SwiftData 的 App Group 成员只需自行保存其最后获取的时间戳，无需统一保存在共享容器中。

4. 事务处理逻辑：由于 SwiftData 采用了完全不同的并发编程方式，事务处理逻辑会放置在一个`ModelActor`中。该实例负责处理持久化历史跟踪事务的获取和处理。

5. `NSPersistentHistoryChangeRequest` 中 的`fetchRequest` 为 `nil`：在 SwiftData 中，通过 `fetchHistory` 创建的 `NSPersistentHistoryChangeRequest` 中的 `fetchRequest` 为 `nil`，因此无法通过谓词的方式对事务进行筛选。筛选过程将在内存中进行。

6. 数据信息转换：持久化历史跟踪事务中包含的数据信息为 `NSManagedObjectID`，需要使用 [SwiftDataKit](https://fatbobman.com/posts/use-Core-Data-features-in-SwiftData-by-SwiftDataKit/) 将其转换为`PersistentIdentifier`，以便在 SwiftData 中进行进一步处理。

在下面的具体实现中会对部分注意事项进行更详细的说明。

## 具体实现

> 你可以在 [此处](https://github.com/fatbobman/BlogCodes/tree/main/SwiftDataChangeMonitor) 获得完整的演示代码。

### 声明 DataProvider

首先我们将先声明一个 DataProvider，其中包含了 ModelContainer 以及用来处理持久化历史跟踪的 ModelActor：

```swift
import Foundation
import SwiftData
import SwiftDataKit

public final class DataProvider: @unchecked Sendable {
    public var container: ModelContainer
    // a model actor to handle persistent history tracking transaction
    private var monitor: DBMonitor?

    public static let share = DataProvider(inMemory: false, enableMonitor: true)
    public static let preview = DataProvider(inMemory: true, enableMonitor: false)

    init(inMemory: Bool = false, enableMonitor: Bool = false) {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration: ModelConfiguration
        modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.container = container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
```

由于 DataProvider 中仅有的两个存储属性的类型都符合 `Sendable` 协议，因此我将 DataProvider 也声明为 `Sendable`。

### 为 ModelContext 的 transactionAuthor 命名

在演示中，为了只处理不由当前应用的 `mainContext` 所产生的事务，我们需要为 ModelContext 的 transactionAuthor 命名。

```swift
extension DataProvider {
    @MainActor
    private func setAuthor(container: ModelContainer, authorName: String) {
        container.mainContext.managedObjectContext?.transactionAuthor = authorName
    }
}

// in init
do {
    let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
    self.container = container
    // 设置 mainContext 的 transactionAuthor 为 mainApp
    Task {
        await setAuthor(container: container, authorName: "mainApp")
    }
} catch {
    fatalError("Could not create ModelContainer: \(error)")
}

```

```responser
id:1
```

### 声明处理持久历史跟踪的 ModelActor

SwiftData 采用了更加安全、优雅的并发编程方式，我们将所有与持久化历史跟踪有关的代码放置到一个 ModelActor 中。

> 阅读 [SwiftData 中的并发编程](https://fatbobman.com/posts/concurret-programming-in-SwiftData/) 一文，掌握并发编程的新方法。

```swift
import Foundation
import SwiftData
import SwiftDataKit
import Combine
import CoreData

@ModelActor
public actor DBMonitor {
    private var cancellable: AnyCancellable?
    // 最后历史事务时间戳
    private var lastHistoryTransactionTimestamp: Date {
        get {
            UserDefaults.standard.object(forKey: "lastHistoryTransactionTimestamp") as? Date ?? Date.distantPast
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: "lastHistoryTransactionTimestamp")
        }
    }
}

extension DBMonitor {
    // 响应持久历史跟踪通知
    public func register(excludeAuthors: [String] = []) {
        guard let coordinator = modelContext.coordinator else { return }
        cancellable = NotificationCenter.default.publisher(
            for: .NSPersistentStoreRemoteChange,
            object: coordinator
        )
        .map { _ in () }
        .prepend(())
        .sink { _ in
            self.processor(excludeAuthors: excludeAuthors)
        }
    }

    // 收到通知后，处理交易
    private func processor(excludeAuthors: [String]) {
        // 获取自上次时间戳后的所有事务
        let transactions = fetchTransaction()
        // 保存最新的时间戳
        lastHistoryTransactionTimestamp = transactions.max { $1.timestamp > $0.timestamp }?.timestamp ?? .now
        // 筛选事务，排除所有由 excludeAuthors 产生的事务
        for transaction in transactions where !excludeAuthors.contains([transaction.author ?? ""]) {
            for change in transaction.changes ?? [] {
                // 将事务的 change 发送给处理单元
                changeHandler(change)
            }
        }
    }

    // 获取自上次处理以来所有新生成的事务
    private func fetchTransaction() -> [NSPersistentHistoryTransaction] {
        let timestamp = lastHistoryTransactionTimestamp
        let fetchRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: timestamp)
        // 在 SwiftData 中，fetchHistory 创建的 fetchRequest.fetchRequest 为 nil，无法设置 predicate
        guard let historyResult = try? modelContext.managedObjectContext?.execute(fetchRequest) as? NSPersistentHistoryResult,
              let transactions = historyResult.result as? [NSPersistentHistoryTransaction]
        else {
            return []
        }
        return transactions
    }

    // Process filtered transactions
    private func changeHandler(_ change: NSPersistentHistoryChange) {
        // 通过 SwiftDataKit ，将 NSManagedObjectID 转换为 PersistentIdentifier
        if let id = change.changedObjectID.persistentIdentifier {
            let author = change.transaction?.author ?? "unknown"
            let changeType = change.changeType
            print("author:\(author)  changeType:\(changeType)")
            print(id)
        }
    }
}
```

在 DBMonitor 中，我们只处理不是由 excludeAuthors 列表中成员所产生的事务。你可以根据需要设置 excludeAuthors，比如将当前 App 的所有 modelContext 的 transactionAuthor 都添加进去。

在 DataProvider 启用 DBMonitor：

```swift
// DataProvider init
do {
    let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
    self.container = container
    Task {
        await setAuthor(container: container, authorName: "mainApp")
    }
    // 创建 DBMonitor，处理持久化历史跟踪事务
    if enableMonitor {
        Task.detached {
            self.monitor = DBMonitor(modelContainer: container)
            await self.monitor?.register(excludeAuthors: ["mainApp"])
        }
    }
} catch {
    fatalError("Could not create ModelContainer: \(error)")
}
```

在 Xcode 的 `Strict Concurrency Checking` 设置为 Complete 的情况下（ 为 Swift 6 做准备，对并发代码做严格审查），如果 DataProvider 不符合 Sendable ，会获得如下的警告信息：

```swift
Capture of 'self' with non-sendable type 'DataProvider' in a `@Sendable` closure
```

### 测试

至此，我们已经完成了在 SwiftData 中对持久化历史跟踪的响应工作。为了验证成果，我们将创建一个新的 ModelActor，通过它来创建新的数据（ 不使用 mainContext ）。

```swift
@ModelActor
actor PrivateDataHandler {
    func setAuthorName(name: String) {
        modelContext.managedObjectContext?.transactionAuthor = name
    }

    func newItem() {
        let item = Item(timestamp: .now)
        modelContext.insert(item)
        try? modelContext.save()
    }
}
```

在 ContentView 中，添加通过 PrivateDataHandler 创建数据的按钮：

```swift
ToolbarItem(placement: .topBarLeading) {
    Button {
        let container = modelContext.container
        Task.detached {
            let handler = PrivateDataHandler(modelContainer: container)
            // 将 PrivateDataHandler 的 modelContext 的 transactionAuthor 设置为 Private，也可以不设置
            await handler.setAuthorName(name: "Private")
            await handler.newItem()
        }
    } label: {
        Text("New Item")
    }
}
```

运行应用后，点击右上角的 `+` 按钮，由于新数据是通过 mainContext 创建的（ mainApp 在 excludeAuthors 名单中 ），因此，对应的事务并不会发送给 `changeHandler`。而通过左上角 "New Item" 按钮创建的数据，其对应的 modelContext 并不在 excludeAuthors 名单中，`changeHandler` 会打印对应的信息。

![swiftData-persistent-history-tracking-demo_2023-10-27_21.50.55.2023-10-27 21_52_22](https://cdn.fatbobman.com/swiftData-persistent-history-tracking-demo_2023-10-27_21.50.55.2023-10-27%2021_52_22.gif)

## 总结

自行处理持久化历史跟踪事务，可以让我们在 SwiftData 正在积极发展的今天实现更多高级功能，这也许能帮助那些想使用 SwiftData 但又对功能受限仍有顾虑的开发者。
