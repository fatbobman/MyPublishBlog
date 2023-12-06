---
date: 2023-12-07 08:11
description: iCloud 文档（iCloud Documents）是苹果公司提供的一项云存储和同步服务，旨在使用户能够轻松存储、访问和共享他们的文档和文件，并在不同的苹果设备之间进行同步和共享。我将通过两篇文章详细介绍该功能。在本文中，我们将探讨如何在应用程序中集成该功能、进行文件的读写以及对文件内容变化的响应等内容。
tags: CloudKit
title: iCloud Documents 详解：基础设置与文件操作
image: images/In-Depth-Guide-to-iCloud-Documents.jpg
mediumURL: https://medium.com/p/62cc4d9610de
---
iCloud 文档（iCloud Documents）是苹果公司提供的一项云存储和同步服务，旨在使用户能够轻松存储、访问和共享他们的文档和文件，并在不同的苹果设备之间进行同步和共享。我将通过两篇文章详细介绍该功能。在本文中，我们将探讨如何在应用程序中集成该功能、进行文件的读写以及对文件内容变化的响应等内容。

## 写在前面的话

苹果基于 CloudKit 为开发者提供了三个主要的功能：CloudKit（保存结构化数据）、NSUbiquitousKeyValueStore（保存键值数据）以及 iCloud Documents（文件共享与云存储）。前两项功能我之前都写过与其有关的文章，但迟迟没有找到好的时机来深入探讨 iCloud Documents 服务。不久前，著名漫画阅读器——[可达阅读器](https://apps.apple.com/cn/app/%E5%8F%AF%E8%BE%BE%E9%98%85%E8%AF%BB%E5%99%A8-%E7%A6%BB%E7%BA%BF%E5%9B%BE%E7%89%87%E9%98%85%E8%AF%BB%E5%99%A8/id1545372338) 的作者 [Xiaogd](https://twitter/kedamanga) 将他在开发中碰到的有关 iCloud Documents 的问题以 [贴文](https://discord.com/channels/967978112509935657/1174644655678304357) 的形式发表在我的 Discord 服务器上。经过他本人同意，我在他的帖文基础上，结合我自己的研究和理解，撰写了本文。在此，特向 Xiaogd 表示感谢。

> 本文主要针对非文档类应用所撰写。因为文档类应用 (Document-based apps) 自身已经深度集成了 iCloud Documents, 可以自动实现本文中介绍的大多数功能。如果你正在开发文档类应用，可以直接参考系统提供的模板和范例代码，本文中的许多内容对你可能比较冗余。

```responser
id:1
```

## 如何开启 iCloud Documents 功能

要在你的项目中启用 iCloud Documents 功能，请按照以下步骤操作：

- 在 "Singing & Capabilities" 中，添加 iCloud 功能。

![https://cdn.fatbobman.com/image-20231204112428865.png](https://cdn.fatbobman.com/image-20231204112428865.png)

- 选择 “iCloud Documents” 功能，并创建或选择你想使用的 CloudKit 容器。

![https://cdn.fatbobman.com/image-20231204112526987.png](https://cdn.fatbobman.com/image-20231204112526987.png)

- 在 Info 中，添加如下内容：

![https://cdn.fatbobman.com/image-20231204112619092.png](https://cdn.fatbobman.com/image-20231204112619092.png)

```xml
<dict>
  <key>NSUbiquitousContainers</key>
  <dict>
    <key>iCloud.com.fatbobman.iCloudDocumentsDemoContainer</key>
    <dict>
      <key>NSUbiquitousContainerIsDocumentScopePublic</key>
      <true/>
      <key>NSUbiquitousContainerName</key>
      <string>Doc_Demo</string>
      <key>NSUbiquitousContainerSupportedFolderLevels</key>
      <string>ANY</string>
    </dict>
  </dict>
</dict>
```

[NSUbiquitousContainers](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/uid/TP40009251-SW32): 一个字典，指定了每个容器的 iCloud Drive 设置。该字典的键是你的应用程序的 iCloud 容器的容器标识符。比如在上面的例子中，我们在项目设置中使用了 `iCloud.com.fatbobman.iCloudDocumentsDemoContainer` 这个容器，那么在此就要以该 id 为键创建字典。

[NSUbiquitousContainerIsDocumentScopePublic](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/uid/TP40009251-SW29)：当将此键设置为 `YES` 时，表示该容器中的文档范围是公共的。用户可以在文件应用（iOS）或 Finder（macOS）中看到 iCloud Documents 目录中的文档目录中的内容。**只有保存在 iCloud Documents 的 Documents 目录中的内容才会被操作系统显示出来**。

[NSUbiquitousContainerName](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/uid/TP40009251-SW31)：这是用户在 iCloud Drive 中看到的容器的友好名称。该名称用于在 Finder 或文件应用中显示的 iCloud 文件夹名称。在上述配置中，我们将其设置为`Doc_Demo`，然后我们将在 Finder 的 iCloud 云盘中会看到一个名为`Doc_Demo`的目录。

[NSUbiquitousContainerSupportedFolderLevels](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/uid/TP40009251-SW30)：这个配置决定了应用可以在 iCloud Drive 中创建的文件夹层级。常见的值有 `None`（不允许创建子文件夹）、`One`（允许一个层级的子文件夹）、`Any`（允许任意层级的子文件夹）。

> 在创建或修改 Info 设置后，应该增加当前项目的 build number，以确保修改后的配置生效。

## 如何获取 iCloud Documents 文件夹的 URL

使用以下代码可以获取到 iCloud Documents 文件夹的 URL：

```swift
// CloudKit Container ID
let containerIdentifier = "iCloud.com.fatbobman.iCloudDocumentsDemoContainer"
guard let url = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) else {
    print("Can't get UbiquityContainer url")
    return
}

print(url)
```

以下情况可能导致无法获取 URL：

- Info 设置错误或没有增加 build number。
- 没有登录 iCloud 账户。
- 登录了 iCloud 账户，但在系统的 iCloud 设置中关闭了当前应用的 iCloud 同步功能。

## 为什么无法在文件应用和 Finder 中看到我的文件夹

如果您已经能够获取到 iCloud Documents 文件夹的 URL，但在文件应用或 Finder 中仍无法看到当前项目的 iCloud Documents 目录，可能是以下原因导致的：

- 确保 `NSUbiquitousContainerIsDocumentScopePublic` 为 `YES`
- 尝试增加 builder number 后再次运行
- 在 iCloud Documents 目录的 Documents 子目录中写入一个文件

在项目首次增加 iCloud Documents 功能后，有时需要在 Documents 子目录中创建一个文件后，才能在文件应用或 Finder 中看到该目录。可以尝试使用下面的代码先写入一个文件：

```swift
let containerIdentifier = "iCloud.com.fatbobman.iCloudDocumentsDemoContainer"
guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) else {
    print("Can't get UbiquityContainer url")
    return
}

let fileURL = containerURL.appendingPathComponent("Documents").appendingPathComponent("hello.txt")
try! "hello world".write(to: fileURL, atomically: true, encoding: .utf8)
```

- 确保模拟器的 iCloud 同步状态正常

需要注意的是，在某些情况下，即使您已在 iOS 模拟器上登录了 iCloud 账户，iCloud 文档的同步可能仍然不稳定，特别是在 iOS 17 系统中，这种情况更为常见。当遇到类似情况时，请多次尝试，或切换到新的模拟器环境。

完成上述操作后，您就可以在文件应用或 Finder 中看到当前应用创建的 `Doc_Demo` 目录以及 `hello.txt` 文件了。

![https://cdn.fatbobman.com/image-20231204122111342.png](https://cdn.fatbobman.com/image-20231204122111342.png)

当 iCloud Documents 的 Documents 子目录显示出来后，即使我们将 Documents 目录中的内容全部删除，该目录仍将显示。

## 是否需要将文件都保存在 iCloud Documents 的 Documents 子目录下

视情况而定。

对于想要在文件应用或 Finder 中显示的文件，将其保存在 "Documents" 子目录下。

如果你觉得没有将文件显示给使用者的必要，可以将 `NSUbiquitousContainerIsDocumentScopePublic` 直接设置为 `NO`。该设置不会影响 iCloud Documents 目录在不同设备之间的同步功能。

## 谁可以读写 iCloud Documents 下的内容

- 与使用相同开发者账号和相同 NSUbiquitousContainers 配置的其他应用程序
- 文件应用程序和 Finder（可以读写 Documents 子目录）

## 如何在 iCloud Documents 中进行文件操作

尽管在上文中，我们使用了与写入普通文件一样的方式在 Documents 子目录中创建了一个 `hello.txt` 文件，但这并不表示这是对 iCloud Documents 目录的正确操作模式。

对于 iCloud Document，苹果推荐开发者通过 [NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator) 的方式对其中的文件进行操作。这是因为除了当前的项目外，其他满足条件的应用和系统应用都可以读写 iCloud Document 目录下的内容。NSFileCoordinator 可以确保文件系统的多个访问请求得到适当的协调，以避免出现数据冲突和数据损坏。

因此，绝大部分对 iCloud Document 的文件操作，都应该通过 `NSFileCoordinator` 进行。

为了避免影响主线程，通常这些操作是在后台进行的。

需要注意的是，`NSFileCoordinator` 的协调任务和文件访问任务应该在同一个执行上下文（同一个线程）中完成，以确保文件访问的原子性和一致性。

### 创建文件

安全的文件写入方式是：

```swift
actor CloudDocumentsHandler {
    let coordinator = NSFileCoordinator()

    func write(targetURL: URL, data: Data) throws {
        var coordinationError: NSError?
        var writeError: Error?

        // 使用 coordinationError 变量来捕获 coordinate 方法的错误信息。
        // 如果不提供一个 NSError 指针，协调过程中发生的错误将无法被捕获和处理。
        coordinator.coordinate(writingItemAt: targetURL, options: [.forDeleting], error: &coordinationError) { url in
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                writeError = error
            }
        }

        // 在闭包外部检查是否有错误发生
        if let error = writeError {
            throw error
        }

        // 检查协调过程中是否发生了错误
        if let coordinationError = coordinationError {
            throw coordinationError
        }
    }
}

Task.detached {
    let containerIdentifier = "iCloud.com.fatbobman.iCloudDocumentsDemoContainer"
    guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) else {
        print("Can't get UbiquityContainer url")
        return
    }
    let documentsFolderURL = containerURL.appendingPathComponent("Documents33")
    let fileURL = documentsFolderURL.appending(path: "hello.txt")
    let hander = CloudDocumentsHandler()
    do {
        try await hander.write(targetURL: fileURL, data: "hello world".data(using: .utf8)!)
    } catch {
        print(error)
    }
}
```

在我们调用 `coordinator.coordinate(writingItemAt: targetURL, options: [], error: &coordinationError)` 这个方法时，`NSFileCoordinator` 会在必要时为 targetURL 创建一个临时的 URL（并非总是创建），并会阻止其他使用 `NSFileCoordinator` 的进程或线程在协调块执行期间对相同文件进行写入操作。

当需要额外控制时，可以在 options 中添加需要的选项。这些选项提供了关于操作性质的上下文信息，帮助 `NSFileCoordinator` 更有效地处理并发和冲突问题。

### 读取文件

```swift
actor CloudDocumentsHandler {
    let coordinator = NSFileCoordinator()

    ....

    func read(url: URL) throws -> Data {
        var coordinationError: NSError?
        var readData: Data?
        var readError: Error?

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
            do {
                readData = try Data(contentsOf: url)
            } catch {
                readError = error
            }
        }

        // 检查读取过程中是否发生了错误
        if let error = readError {
            throw error
        }

        // 检查协调过程中是否发生了错误
        if let coordinationError = coordinationError {
            throw coordinationError
        }

        // 确保读取到的数据不为空
        guard let data = readData else {
            throw NSError(domain: "CloudDocumentsHandlerError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data was read from the file."])
        }

        return data
    }
}
```

```responser
id:1
```

## 如何感知文件的变化

在上面的代码中，我们通过 `read(url: URL)` 获取了指定的文件数据。如果该文件被其他的进程或网络上其他的设备修改了，开发者该如何感知它的变化并及时更新呢？

通常情况下，对于单个文件的变化，我们可以使用 `NSFilePresenter` 来感知变化。

`NSFilePresenter` 的功能主要包括以下几点：

- 接收文件更改通知：当文件发生变化（如内容被修改、移动或删除）时，实现了 `NSFilePresenter` 协议的对象将会收到通知。
- 处理文件冲突：如果多个应用或进程尝试同时修改同一文件，`NSFilePresenter` 可以帮助识别和解决冲突。
- 协调文件的保存操作：在文件被保存之前，可以通知 `NSFilePresenter`，从而允许它执行必要的操作，如保存当前状态或释放文件锁。

首先，我们需要创建一个符合 `NSFilePresenter` 协议的类型：

```swift
class FilePresenter: NSObject, NSFilePresenter {
    let fileURL: URL
    var presentedItemOperationQueue: OperationQueue = .main

    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init()
        // 注册，监视指定 URL
        NSFileCoordinator.addFilePresenter(self)
    }

    deinit {
        // 注销监视
        NSFileCoordinator.removeFilePresenter(self)
    }

    var presentedItemURL: URL? {
        return fileURL
    }

    func presentedItemDidChange() {
        // 当文件发生变化时，执行相关操作
        // 例如，重新加载文件或通知其他组件
        print("file changed")
    }
}
```

然后，为 CloudDocumentsHandler 增加开启监视和关闭监视的方法：

```swift
actor CloudDocumentsHandler {
    let coordinator = NSFileCoordinator()
    var filePresenters: [URL: FilePresenter] = [:]

    ....

    func startMonitoringFile(at url: URL) {
        let presenter = FilePresenter(fileURL: url)
        filePresenters[url] = presenter
    }

    func stopMonitoringFile(at url: URL) {
        if let presenter = filePresenters[url] {
            NSFileCoordinator.removeFilePresenter(presenter)
        }
        filePresenters[url] = nil
    }
}
```

这样我们就可以在读取文件后，通过 `startMonitoringFile` 方法来实现对文件变化的感知。

```swift
let data = try await hander.read(url: fileURL)
await hander.startMonitoringFile(at: fileURL)
// close monitor
await hander.stopMonitoringFile(at: fileURL)
```

需要注意的点：

- `presentedItemDidChange` 并不会告知我们文件的具体变化，当需要更精确的处理文件冲突和保存操作的协调时，需要实现 `NSFilePresenter` 协议的其他方法。
- 在不需要对文件进行监视时，务必要及时移除 `NSFilePresenter` 的实例以提高效率并避免内存泄露

`NSFilePresenter` 不仅可以监视单个文件，还可以监视整个目录。然而，由于其提供的信息有限，除非你只需要在目录内容发生变化时得到通知，否则我们通常不会使用它来监控一个目录。

## 如何获取 iCloud Document 目录中的文件列表

那么我们该如何获取 iCloud Document 目录中的文件列表，并在内容发生变化时实现自动更新呢？

苹果给出的建议是使用 [NSMetaDataQuery](https://developer.apple.com/documentation/foundation/nsmetadataquery)。

在使用 iCloud Documents 的项目中，`NSMetadataQuery` 作为一种搜索 Spotlight metadata 的工具，可以用来监控 iCloud 文档目录的文件变化。它允许开发者设置特定的查询条件，监控文件的添加、删除或修改。当检测到文件系统的这些变化时，`NSMetadataQuery` 会发送通知，使开发者能够及时更新应用界面或执行相应的逻辑操作。这一功能在处理文件同步和状态更新时尤其重要。

如果你使用过 Core Data，它的表现有些类似于 NSFetchedResultsController 或 @FetchRequest。

下面的代码将使用 `NSMetadataQuery`，根据给定的 Predicate、Scope 和 SortDescriptor 创建一个 AsyncStream。它会返回指定位置的文件列表，并对其变化做出响应。

```swift
class ItemQuery {
    let query = NSMetadataQuery()
    let queue: OperationQueue

    init(queue: OperationQueue = .main) {
        self.queue = queue
    }

    func searchMetadataItems(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = [],
        scopes: [Any] = [NSMetadataQueryUbiquitousDocumentsScope]
    ) -> AsyncStream<[MetadataItemWrapper]> {
        query.searchScopes = scopes
        query.sortDescriptors = sortDescriptors
        // 获取 iCloud Ubiquity Container URL
        if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
            // 构建指向 Documents 目录的路径
            let documentsPath = containerURL.path

            // 使用动态路径创建谓词
            let defaultPredicate = NSPredicate(format: "%K BEGINSWITH %@", NSMetadataItemPathKey, documentsPath)
            query.predicate = predicate ?? defaultPredicate
        } else {
            // 如果无法获取路径，可以选择一个合适的默认行为
            query.predicate = predicate ?? NSPredicate(value: true)
        }

        return AsyncStream { continuation in
            NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query,
                queue: queue
            ) { _ in
                let result = self.query.results.compactMap { item -> MetadataItemWrapper? in
                    guard let metadataItem = item as? NSMetadataItem else {
                        return nil
                    }
                    return MetadataItemWrapper(metadataItem: metadataItem)
                }
                continuation.yield(result)
            }

            NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidUpdate,
                object: query,
                queue: queue
            ) { _ in
                let result = self.query.results.compactMap { item -> MetadataItemWrapper? in
                    guard let metadataItem = item as? NSMetadataItem else {
                        return nil
                    }
                    return MetadataItemWrapper(metadataItem: metadataItem)
                }
                continuation.yield(result)
            }

            query.start()

            continuation.onTermination = { @Sendable _ in
                self.query.stop()
                NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: self.query)
                NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: self.query)
            }
        }
    }
}

struct MetadataItemWrapper: Sendable {
    let fileName: String?
    let fileSize: Int?
    let contentType: String?
    let isDirectory: Bool
    let url: URL?

    init(metadataItem: NSMetadataItem) {
        fileName = metadataItem.value(forAttribute: NSMetadataItemFSNameKey) as? String
        fileSize = metadataItem.value(forAttribute: NSMetadataItemFSSizeKey) as? Int
        contentType = metadataItem.value(forAttribute: NSMetadataItemContentTypeKey) as? String

        // 检查是否是目录
        if let contentType = metadataItem.value(forAttribute: NSMetadataItemContentTypeKey) as? String {
            isDirectory = (contentType == "public.folder")
        } else {
            isDirectory = false
        }

        url = metadataItem.value(forAttribute: NSMetadataItemURLKey) as? URL
    }
}
```

以下代码展示了如何获取 iCloud Documents 下的 Document 目录中的文件列表，包括所有子目录和子目录中的文件，并自动更新以反映任何变化。

```swift
Task {
    let query = ItemQuery()
    for await items in query.searchMetadataItems().debounce(for: .seconds(1)) {
        items.forEach{
            print($0.fileName ?? "", $0.isDirectory)
        }
    }
}
```

为了避免 `NSMetadataQuery` 的频繁通知，在上面的代码中使用了 [swift-async-algorithms](https://github.com/apple/swift-async-algorithms) 的 `debounce` 方法进行限流。你可以根据自己的需求，用任何熟悉的方式（比如 Combine）来实现上述逻辑。

代码的逻辑比较简单：

- 创建一个 query，设置 Predicate、Scope 和 SortDescriptors。
- 注册 NSMetadataQueryDidFinishGathering 和 NSMetadataQueryDidUpdate 通知。
- 在有通知时，将 NSMetadataItem 转换成 MetadataItemWrapper（转换成 Sendable），并通过 AsyncStream 传递出来。

Scope 是用来设定搜索范围的。在 iCloud Document 的应用中，我们通常会使用：

- NSMetadataQueryUbiquitousDocumentsScope：在 iCloud Documents 的 Documents 子目录中进行搜索。
- NSMetadataQueryUbiquitousDataScope：在 iCloud Documents 目录中进行搜索，不包括 Documents 子目录。

Predicate 除了可以指定某个目录外，还可以实现搜索特定文件的功能。下面的代码将列出所有以字符 `h` 开头的文件和目录，但仅限于 iCloud Documents 根目录下。

```swift
guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) else {
    return
}
let predicateFormat = "((%K BEGINSWITH[cd] 'h') AND (%K BEGINSWITH %@)) AND (%K.pathComponents.@count == %d)"
// 通过 pathComponents 数量来控制目录深度
let predicate = NSPredicate(format: predicateFormat,
                            NSMetadataItemFSNameKey,
                            NSMetadataItemPathKey,
                            containerURL.path,
                            NSMetadataItemPathKey,
                            containerURL.pathComponents.count + 1)
for await items in query.searchMetadataItems(predicate: predicate, scopes: [NSMetadataQueryUbiquitousDataScope]).throttle(for: .seconds(1), latest: true) {
    items.forEach {
        print($0.fileName ?? "", $0.isDirectory)
    }
}
```

你也可以通过 sortDescriptors 来设定返回结果的排序方式，例如：先按文件名正序，再按文件大小倒序来排序。

```swift
let sortDescriptors = [
    NSSortDescriptor(key: NSMetadataItemFSNameKey, ascending: true),
    NSSortDescriptor(key: NSMetadataItemFSSizeKey, ascending: false)
]
```

在使用 `NSMetadataQuery` 时，开发者应该了解以下几点：

- `NSMetadataQuery` 是用于搜索 Spotlight metadata 的工具，而不是直接进行文件操作。
- 在创建谓词时，不应该依赖于传统的文件系统路径和逻辑，而应该使用与元数据匹配的谓词来筛选数据。
- `NSMetadataQuery` 会响应满足谓词的任意元数据的变化，开发者应根据需求提供尽可能精确的谓词。这有助于减少不必要的变化通知，提高效率。
- 如果变化响应过于频繁，应采取适当的限流措施。
- 当不再需要响应变化时，应尽早关闭 `NSMetadataQuery`。这有助于释放资源并提高性能。

## 接下来

在本文中，我们讨论了如何在项目中集成 iCloud 文档功能，包括如何读写文件、获取文件列表以及响应文件或目录内容的变化。在下一篇文章中，我们将更详细地介绍占位文件、下载与空间清理、移动与重命名等技巧。

您可以在 [此处](https://github.com/fatbobman/BlogCodes/tree/main/iCloudDocumentsDemo) 获取本文的源代码。
