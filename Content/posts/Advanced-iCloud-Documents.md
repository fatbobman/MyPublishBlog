---
date: 2023-12-14 08:11
description: 在前文《iCloud Documents 详解：基础设置与文件操作》中，我们探索了 iCloud Documents 的基本概念、设置步骤和基础的文件操作。本文我们将讨论 iCloud Documents 文件夹的独特性质，占位文件的重要性和应用，之外，我们还将探讨与文件操作和调试有关的技巧。
tags: CloudKit
title: iCloud Documents 进阶：理解占位文件、空间优化与操作技巧
image: images/Advanced-iCloud-Documents.jpg
mediumURL: https://medium.com/p/759b29c17e10
---
欢迎回到我们关于 iCloud Documents 的深入探讨。在前文 [iCloud Documents 详解：基础设置与文件操作](https://fatbobman.com/posts/In-Depth-Guide-to-iCloud-Documents/) 中，我们探索了 iCloud Documents 的基本概念、设置步骤和基础的文件操作。本文将在上文基础上继续探讨，因此，如果你还未阅读前文，建议你先熟悉基础知识，以便更好地理解本文的内容。

本文我们将讨论 iCloud Documents 文件夹的独特性质，占位文件的重要性和应用，之外，我们还将探讨与文件操作和调试有关的技巧。

## iCloud Documents 文件夹

尽管同为应用可以访问到的文件夹，iCloud Documents 文件夹相较于应用沙盒内的文件夹（ Documents、Application Support 等）仍有几个明显的不同点：

* iCloud Documents 文件夹不属于应用的沙盒范围，它在文件系统的特殊位置，与应用沙盒隔离。
* iCloud Documents 中的部分文件对其他应用也可能是可见或者可共享的，而应用内部的数据默认是私有的。
* iCloud Documents 中的文件默认就是与 iCloud 云端持续同步的，以支持在 Apple 设备之间的文档共享。而应用沙盒内的文件是否同步到 iCloud 取决于应用的设置（ 是否开启云备份 ）、文件的位置（ Documents 默认同步 ）、文件的配置（ Application Support 目录中的文件，可以通过 NSURLIsExcludedFromBackupKey 来设置是否同步 ）。
* 在满足 iCloud 备份条件（ 网络、电量、当前时间 ）时，应用沙盒内可备份的数据会同步到 iCloud 作为备份，该备份仅在下次安装应用时才会起作用。但是 iCloud Documents 中 的文档变更可以近似实时上传并同步给其他设备。
* 当应用被删除后，该应用的沙盒将被系统清空，而 iCloud Documents 中的文件会依然保留在 iCloud 和用户设备中。
* iCloud Documents 中的文件可以按需下载或释放空间（ 文件仍保存在云端 ），沙盒内的文档没有此能力
* iCloud Documents 提供了版本控制和冲突解决机制，有助于在多设备间同步时维护文件的一致性。

因此，开发者乃至使用者，要根据 iCloud Documents 文件夹的特点来决定使用的策略：

* 因为 iCloud Documents 文件夹内的数据都会被同步，因此只应该在 iCloud Documents 文件夹中放置真正需要即时备份、分享的文档数据。
* 考虑到其数据会在本地和云端占用双份空间，开发者应该提供空间释放空间的能力或提醒使用者通过系统应用来释放暂时不需要的资源。
* 尽管 iCloud Documents 的同步效率还可以，但它并不适合保存零散数据或增量数据。如有需要，开发者可以考虑使用 CloudKit 提供的其他服务。
* 考虑到用户的云端空间容量可能有限，开发者不应默认所有的数据都会成功上传到云端并同步到其他设备中。
* 为了减少用户云端容量的压力，开发者应该提供将数据转移至非自动同步目录的能力。

## 什么是占位文件

在云同步服务中，占位文件扮演者重要的角色。比如我在设备 A 上的 iCloud Documents 目录中创建了文件 `lesson1.pdf`，设备 B 在收到同步消息后，多数情况下并不会自动下载该文件（ 在 macOS 上，如果关闭优化存储空间，系统会自动下载；在 iOS 中，如果文件很小且应用正在运行，有时系统会自动下载 ），设备 B 会在 iCloud Documents 目录相同位置创建一个对应的占位文件。设备 B 上的应用或使用者可以在需要的时候自主选择从云端下载完整的文件数据。

占位文件提供了一种平衡本地存储限制和即时云端文件访问的方式。通过它，用户可以有效管理他们的存储空间，同时保持对重要文件的即时访问。

以设备 B 和文件 `file1.txt` 举例，设备 B 在收到同步通知后，会在与设备 A 的 `lesson1.pdf` 相同的文件位置创建一个名为 `.lesson1.pdf.icloud` 文件。该文件将作为 `lesson1.pdf` 在设备 B 上的占位文件。

占位文件以 Property List 的形式保存了一些与原始文件有关的信息（ 文件名、文件容量、文件类型 ），经过解析后，大致的信息如下：

```swift
[
  "NSURLNameKey": lesson1.pdf, 
  "NSURLFileSizeKey": 206739, 
  "NSURLFileResourceTypeKey": NSURLFileResourceTypeRegular
]
```

当文件应用或 Finder 发现文件是占位文件时，它仍会以正常的文件名、文件容量显示给用户，但是，会通过图标的方式提醒使用者，这个文件尚未下载到本地，使用者可以点击下载从云端下载完整版本。同样，对于已经下载到本地的完整文件，使用者也可以通过点击移除下载项来删除本地的完整文件，系统会自动创建一个新的占位文件。

由于占位文件机制的存在，因此对于开发者来说，在对文件进行某些操作前要先应判断文件的占位状态，然后再作出相应的操作。

同样，由于占位文件使用了特殊的名称标记方式，为此，获取文件列表最好的方式，仍是通过前一篇文章介绍的 [NSMetaDataQuery](https://developer.apple.com/documentation/foundation/nsmetadataquery)。因为，即使开发者不顾虑多进程文件竞争，使用 `fileManager.contentsOfDirectory` 获取到的文件名会包含占位标识符（ 对于占位文件 ），开发者还需要做特别的处理。

## 如何判断文件是否为占位文件

在处理 iCloud Documents 时，正确地识别占位文件是一个关键步骤。虽然我们可以通过检查文件名中是否包含特定的占位标识符来进行判断，但这并不是最准确或最可靠的方法。更科学的做法是利用我们通过 `NSMetadataQuery` 获得的文件列表，并查看每个文件的元数据属性来确定其是否为占位文件。

这种方法的优势在于，它基于文件的实际元数据状态，而不仅仅是文件名。为此，我们在之前定义的 `MetadataItemWrapper` 结构体中添加了一个 `isPlaceholder` 属性，用于存储每个文件的占位状态。

以下是相应的 Swift 代码实现：

```swift
struct MetadataItemWrapper: Sendable {
    ....
    let isPlaceholder:Bool
    
    init(metadataItem: NSMetadataItem) {
        ....
        
        if let downloadingStatus = metadataItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
            if downloadingStatus == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded {
                // 文件是占位文件
                isPlaceholder = true
            } else if downloadingStatus == NSMetadataUbiquitousItemDownloadingStatusDownloaded || downloadingStatus == NSMetadataUbiquitousItemDownloadingStatusCurrent {
                // 文件已下载或是最新的
                isPlaceholder = false
            } else {
                isPlaceholder = false
            }
        } else {
            // 默认值，假设文件不是占位文件
            isPlaceholder = false
        }
    }
}
```

```responser
id:1
```

## 如何下载文件

所谓的下载文件，是指让系统将占位文件的原始文件从云端下载下来对占位文件进行替换的过程。通过调用 `FileManager.default.startDownloadingUbiquitousItem(at: )` ，即可触发对特定占位文件的下载操作。为了安全起见，最好还是通过 NSFileCoordinator 来进行该操作。

以下是一个下载文件的示例方法，它使用了前文创建的 `CloudDocumentsHandler` 来确保文件下载的安全性和协调性：

```swift
extension CloudDocumentsHandler {
    func download(url: URL) throws {
        var coordinationError: NSError?
        var downloadError: Error?

        coordinator.coordinate(writingItemAt: url, options: [.forDownloading], error: &coordinationError) { newURL in
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: newURL)
            } catch {
                downloadError = error
            }
        }

        // 检查下载过程中是否发生了错误
        if let error = downloadError {
            throw error
        }

        // 检查协调过程中是否发生了错误
        if let coordinationError = coordinationError {
            throw coordinationError
        }
    }
}
```

在下载的过程中，系统并不会将尚未完成的文件保存在占位文件当前的目录中，只有等到文件完全下载后，系统才会用完整的文件替换掉占位文件。

对与已经下载完成的文件，再次调用 `startDownloadingUbiquitousItem` 不会有任何效果。

> 尽管官方文档描述该方法可以接收目录 URL 作为参数，但在测试中发现 `startDownloadingUbiquitousItem` 只能用于下载单个文件。

## 如何获得下载进度、下载状态、上传状态

下载进度：从文件的元数据 `NSMetadataUbiquitousItemPercentDownloadedKey` 中可以获取下载进度。这个值（ Double ）表示文件已经下载的百分比，可以用来追踪下载进度。

下载状态：结合占位状态和下载进度可以判断当前的下载状态。如果文件是占位文件且下载进度大于 0 且小于 100，则可以认为文件正在下载。

上传状态：从文件的元数据  `NSMetadataUbiquitousItemPercentUploadedKey` 中可以获取上传进度。这个值只有两个状态，0 表示未上传，100 表示已上传完成。

```swift
struct MetadataItemWrapper: Sendable {
    ....
    let isDownloading: Bool
    let downloadProgress: Double
    let uploaded: Bool

    init(metadataItem: NSMetadataItem) {
        ....
        // 获取下载进度
        downloadProgress = metadataItem.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double ?? 0.0

        // 如果是占位文件且下载进度大于 0 且小于 100，则认为文件正在下载
        isDownloading = isPlaceholder && downloadProgress > 0.0 && downloadProgress < 100.0
        // 是否已经上传完毕（只有 0 和 100 两个状态）
        uploaded = (metadataItem.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? Double ?? 0.0) == 100
    }
}
```

通过这些属性，我们可以较精准的掌握文件状态，以便更好地管理和监控文件的同步过程并给予用户提示。

## 如何释放将已下载的文件所占用的空间

当你需要释放已下载的文件占用的空间将文件变回占位模式时，可以使用 `evictUbiquitousItem` 方法。这个方法非常类似于触发下载的操作，但它的作用是将已下载的文件变成占位模式，从而释放空间。`evictUbiquitousItem` 方法可以用于文件和文件夹，当对文件夹执行此操作时，iCloud 会递归地移除文件夹中子项目的副本。

需要特别注意的是，**[不要使用协调器](https://developer.apple.com/documentation/foundation/filemanager/1409696-evictubiquitousitem#discussion)（`NSFileCoordinator`）执行此操作**，因为这样做可能会导致死锁。你可以简单地调用 `evictUbiquitousItem` 方法来释放已下载文件的空间，而无需额外的协调。

```swift
extension CloudDocumentsHandler {
    func evict(url: URL) throws {
        do {
            try FileManager.default.evictUbiquitousItem(at: url)
        } catch {
            throw error
        }
    }
}
```

## 如何移动 iCloud Documents 目录中的文件而不必下载它们

你可以通过使用 `FileManager.default.moveItem(at:to:)` 方法在 iCloud Documents 目录中移动文件，而不必关系它的占位状态。即使文件是占位文件，只要目标地址也在 iCloud Documents 的目录中，移动后文件仍会保持占位状态。

以下是一个示例代码，演示如何在 iCloud Documents 目录中移动文件：

```swift
extension CloudDocumentsHandler {
    func moveFile(at sourceURL: URL, to destinationURL: URL) throws {
        var coordinationError: NSError?
        var moveError: Error?

        coordinator.coordinate(writingItemAt: sourceURL, options: .forMoving, writingItemAt: destinationURL, options: .forReplacing, error: &coordinationError) { (newSourceURL, newDestinationURL) in
            do {
                try FileManager.default.moveItem(at: newSourceURL, to: newDestinationURL)
            } catch {
                moveError = error
            }
        }

        // 检查移动过程中是否发生了错误
        if let error = moveError {
            throw error
        }

        // 检查协调过程中是否发生了错误
        if let coordinationError = coordinationError {
            throw coordinationError
        }
    }
}
```

请注意，对于特定的操作，如移动文件，应确保设置正确的选项（options），以便在移动过程中保持文件的正确状态。

## 如何在不下载文件的情况下重命名文件

只需使用上面用于移动的代码，更改目标名称即可。即使是占位文件，更名后仍会保持占位状态。

```responser
id:1
```

## 如何解除文件的同步状态

你可以通过将文件从 iCloud Documents 目录中移动到其他位置（ 非 iCloud Documents 目录 ）来解除文件的同步状态。即使文件当前处于占位模式，系统也会在移动前自动开始下载文件，并在下载完成后将再将文件移动到新的位置。这个过程可能会有一定的延迟，特别是对于较大的文件。

## 调试技巧

在开发和调试涉及网络同步的功能时，我们通常面临一个挑战：快速且稳定的网络环境。这种环境虽然理想，但却不利于测试网络同步的边缘情况，例如慢速连接或不稳定网络。此外，在高速网络环境下，某些关键的传输细节和中间状态可能会被快速跳过，从而无法捕捉到。

为了解决这一问题，开发者可以利用苹果公司提供的一个工具：Network Link Conditioner。这个工具允许我们模拟各种网络条件，如不同的网速、延迟和丢包率，从而创建出更接近现实生活中的网络环境。

以本文的撰写过程为例，我在尝试捕捉 iCloud Documents 的下载进度中间状态时遇到了困难。原因是网络速度过快，使得下载过程在瞬间完成。然而，通过使用 Network Link Conditioner 人为限制网络速度，成功模拟了较慢的下载环境，使得可以清晰地观察和记录下载的每个阶段。

获取 Network Link Conditioner 的方法：

* 在苹果开发者网站上，下载：Additional Tools for Xcode。

![image-20231205102918859](https://cdn.fatbobman.com/image-20231205102918859.png)

![image-20231205102856422](https://cdn.fatbobman.com/image-20231205102856422.png)

* 打开下载后的 `.dmg` 文件，找到 `Hardware/Network Link Conditioner.prefPane` ，将其复制到本地，双击安装即可。

![image-20231205103008115](https://cdn.fatbobman.com/image-20231205103008115.png)

![image-20231205103020359](https://cdn.fatbobman.com/image-20231205103020359.png)

* 在系统设置中，选择或创建一个 Profile ，开启该功能后，便可实现对当前开发环境的网络控制。

![image-20231205103112525](https://cdn.fatbobman.com/image-20231205103112525.png)

## 总结

通过前后两篇文章的探讨，我们可以发现，虽然涉及诸多细节，但只要我们细心地处理每一个步骤，并仔细调试，将 iCloud Documents 集成到我们的项目中并不困难。尽管这一过程需要我们投入一定的时间和精力，但最终为应用带来的增值和便利是显而易见的。

苹果公司提供的 CloudKit 服务，可以说是对开发者的一大福音。它使得开发者能够以极低的成本，为应用提供强大而灵活的网络数据同步功能。利用这些功能，将为应用赋予更强的竞争力和用户吸引力，也为用户带来更好的体验。
