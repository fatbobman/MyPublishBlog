---
date: 2023-03-08 08:20
description: 尽管 SwiftUI 的惰性容器以及 Core Data 都有各自的内存占用优化机制，但随着应用视图内容的复杂（ 图文混排 ），越来越多的开发者遇到了内存占用巨大甚至由此导致 App 崩溃的情况。本文将通过对一个演示 App 进行逐步内存优化的方式（ 由原先显示 100 条数据要占用 1.6 GB 内存，优化至显示数百条数据仅需 200 多 MB 内存 ），让读者对 SwiftUI 视图的存续期、惰性视图中子视图的生命周期、托管对象的惰值特性以及持久化存储协调器的行缓存等内容有更多的了解。
tags: Core Data,SwiftUI
title: SwiftUI + Core Data App 的内存占用优化之旅
image: images/memory-usage-optimization.png
---
尽管 SwiftUI 的惰性容器以及 Core Data 都有各自的内存占用优化机制，但随着应用视图内容的复杂（ 图文混排 ），越来越多的开发者遇到了内存占用巨大甚至由此导致 App 崩溃的情况。本文将通过对一个演示 App 进行逐步内存优化的方式（ 由原先显示 100 条数据要占用 1.6 GB 内存，优化至显示数百条数据仅需 200 多 MB 内存 ），让读者对 SwiftUI 视图的存续期、惰性视图中子视图的生命周期、托管对象的惰值特性以及持久化存储协调器的行缓存等内容有更多的了解。

> 可在 [此处](https://github.com/fatbobman/BlogCodes/tree/main/Memory_Optimization) 下载本文所需的代码

## 一个内存占用量巨大的 App

本节中，我们将创建一个在 List 中对 Core Data 数据进行浏览的演示 App。

本例中，Core Data 的数据模型非常简单，只有两个 Entity ：Item 和 Picture。Item 与 Picture 之间是一对一的关系。为了尽量不影响 SQLite 数据库的操作性能，我们为 Picture 的 data 属性启用了 `Allows External Storage` 选项。

![Item_Entity](https://cdn.fatbobman.com/image-20230307132541444.png)

![Picture_Entity](https://cdn.fatbobman.com/image-20230307132631527.png)

> 开启 `Allows External Storage` 后，SQLite 会自动将尺寸大于一定要求（ 100KB ）的 Binary 数据以文件的形式保存在与数据库文件同级目录的隐藏子目录中。数据库字段中仅保存与该文件对应的文件 ID （ 50 个字节 ）。通常为了保证数据库的性能，开发者会为尺寸较大的 Binary 属性开启这一选项。

```responser
id:1
```

列表视图相当简单：

```swift
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(items) { item in
                        ItemCell(item: item)
                    }
                }
            }
        }
    }
}
```

单元格视图也是采用了常见的形式：

```swift
struct ItemCell: View {
    @ObservedObject var item: Item
    let imageSize: CGSize = .init(width: 120, height: 160)
    var body: some View {
        HStack {
            Text(self.item.timestamp?.timeIntervalSince1970 ?? 0, format: .number)
            if let data = item.picture?.data, let uiImage = UIImage(data: data), let image = Image(uiImage: uiImage) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: self.imageSize.width, height: self.imageSize.height)
            }
        }
        .frame(minWidth: .zero, maxWidth: .infinity)
    }
}

```

生成数据后，运行后显示的状态如下：

![image-20230307133812557](https://cdn.fatbobman.com/image-20230307133812557.png)

> **Add 100** 按钮将创建 100 条记录， **记录数** 为当前的数据条数，**内存占用** 为当前 App 的内存占用情况。具体实现可查看本文演示代码。

在我们创建完 100 条数据后，重启应用（ 重启可以更精准地测量内存占用情况 ）并滚动列表至底部。此时该应用的内存占用为 **1.6 GB** 左右。此时请不要惊讶，你可以尝试点击添加数据按钮继续增加数据，再次滚动到底部，你将看到更加令人震惊的内存占用数值，不过有极大的可能会看不到（ 应用已经崩溃了 ）。

![无优化滚动至底截屏](https://cdn.fatbobman.com/image-20230307114637079.png)

从 Instruments 的分析来看，随着列表的滚动，内存占用持续增加中。

![无优化效果](https://cdn.fatbobman.com/image-20230307103505927.png)

相信任何开发者都无法容忍这种内存占用的情况出现。下文中，我们将对这段代码进行逐步优化，以达到最终可用的程度。

## 第一轮优化：对视图 body 值进行优化

在第一轮优化中，我们会首先尝试从 SwiftUI 的角度入手。

SwiftUI 的惰性视图容器拥有对符合 DynamicViewContent 协议的内容（ 通过 ForEach 生成的内容 ）进行优化的能力。在正常的情况下（ 惰性容器中仅包含一个 ForEach ，且子视图没有使用 id 添加显式标识 ），惰性容器仅会创建当前可见范围内的子视图实例，并对其 body 进行求值（ 渲染 ）。

当子视图进入惰性容器的可视区域时，SwiftUI 会调用它的 onAppear 闭包，子视图退出可视区域时，会调用 onDisappear 闭包。开发者通常会利用这两个调用时机来实现数据准备和善后工作。

尽管从表面上来看，惰性容器仅会在视图进入可视区域时才会对其进行操作，**但一旦该视图被显示过（ body 被求过值 ），即使该视图离开可视区域，SwiftUI 仍会保存视图的 body 值**。这意味着，**在惰性容器中，视图一经创建，其存续期将与该容器一致**（ 容器不销毁，则视图将始终存续 ）。

在本例中，子视图的 body 值中一定会包含用于显示的图片数据，因此，即使该视图已经被显示过（ 滚动出显示区域 ），该视图的 body 值仍将占用不小的内存。

我们可以通过在 onAppear 以及 onDisappear 中对图片的显示与否（ 变量 show ）进行控制（ 迫使 SwiftUI 对视图的 body 重新求值 ），从而减少因上述原因所增加的内存占用。

对 Cell 视图代码（ `ItemCell.swift` ）进行如下调整：

```swift
struct ItemCell: View {
    @ObservedObject var item: Item
    @Environment(\.managedObjectContext) var viewContext
    let imageSize: CGSize = .init(width: 120, height: 160)
    @State var show = true
    var body: some View {
        HStack {
            if show { // 仅当处于惰性容器可视区域时采显示内容
                Text(self.item.timestamp?.timeIntervalSince1970 ?? 0, format: .number)
                if let data = item.picture?.data, let uiImage = UIImage(data: data), let image = Image(uiImage: uiImage) {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: self.imageSize.width, height: self.imageSize.height)
                }
            }
        }
        .frame(minWidth: .zero, maxWidth: .infinity)
        .onAppear {
            show = true // 进入可视区域时显示
        }
        .onDisappear {
            show = false // 退出可视区域时不显示
        }
    }
}
```

通过上面简单的改动，当前 App 的内存占用情况便有了显著的改善。滚动到底部后（ 100 条数据 ），内存的占用将在 500 MB 左右。

![binary-store-in-external- iPhone 14 Pro - 2023-03-07 at 11.33.27.2023-03-07 11_35_01](https://cdn.fatbobman.com/binary-store-in-external-%20iPhone%2014%20Pro%20-%202023-03-07%20at%2011.33.27.2023-03-07%2011_35_01.gif)

> Instruments 会导致优化后的结果显示不准确，内存占用数据将以 App 中的显示以及 Xcode Navigator 的 Debug 栏内容为准。如果滚动过快，可能会导致内存占用增大。估计与系统无暇进行清理操作有关。

![Navigator-Debug](https://cdn.fatbobman.com/image-20230307141701153.png)

尽管上述优化技巧可能会对滚动的流畅度产生一定的影响（ 视觉上不明显 ），不过考虑到它所带来的巨大收益，在本例中应该是一个相当不错的选择。

> 同未优化过的代码一样，随着数据量的增大，内存的占用也将随之提高。在 400 条记录的情况下，滚动到底部，内存占用值差不多是 1.75 GB。尽管我们节省了差不多 70% 的内存占用，但仍无法完全满足需求。

## 第二轮优化：让托管对象回归惰性状态

在第二轮优化中，我们将尝试从 Core Data 中找寻解决之道。

首先，我们需要对托管对象的惰值特性以及协调器的“行缓存”概念有所了解。

### 存储协调器的行缓存（ Row cache in coordinator ）

在 Core Data Stack 的多层结构中，存储协调器（ NSPersistentStoreCoordinator ）正好处于持久化存储与托管上下文之间。其向托管上下文以及持久化存储提供了单个的统一接口，一个协调器便可以应对多个上下文以及多个持久化存储。

![coreDataStack](https://cdn.fatbobman.com/coreDataStack.svg)

在协调器具备的众多功能中，“行缓存”是其中很有特点的一个。所谓行缓存，便是指当 Core Data 从 SQLite 中获取数据时，首先将数据以接近原始存储格式的形式保存在行缓存（ 内存 ）中。并根据上下文的需要，用对应的数据向特定的托管对象进行填充（ 实例化 ）。行缓存的真正意义在于，在有多个托管上下文（ NSMangedObjectContext ）与协调器关联时，对于同一条记录（ NSManagedObjectID 一致 ）的内容，无需进行多次 IO 操作，可以直接从行缓存中获取（ 如果可以命中的话 ）。

从当今移动开发的角度来说，行缓存好像存在的意义不大，但考虑到 Core Data 的前身主要用来处理金融类数据业务，在此种场景中，行缓存可以带来相当可观的收益。

由于行缓存机制的存在，当我们通过 Core Data 从数据库中获取某个数据时（ 例如图片 ），行缓存中会有一份副本。

### 托管对象的惰值特性

托管对象（ NSManagedObject ）除了只能在创建其的托管上下文中进行操作外，按需填充也是托管对象的重要特性之一。

在开发者通过创建一个 Request （ NSFetchRequest ）从数据库中获取查询结果时，除非特别将 Request 的 returnsObjectsAsFaults 属性设置为 false ，否则托管上下文并不会给托管对象的托管属性（ @NSManaged ）返回真正的数据。只有在访问这些托管属性时，Core Data 才会为托管对象进行数据填充（ 如果行缓存中有，从缓存中取；如果没有则将数据从数据库中搬运到行缓存后再从缓存中取 ）。

惰值特性是 Core Data 的重要特性之一。它保证了，只在真正对数据有需求时，才对数据进行获取（ 实例化 ）。在提高了性能的同时，也尽量减少了对内存的占用。

在本例中，只有视图首次出现在 List 的可视区域时，Item 才会被填充数据。

在托管对象从惰值状态（ Fault ）脱离后，只有在几种特定的条件下，才会重新转换为惰值。例如通过调用 refresh 或 refreshAllObjects 方法。

除非特别设置 relationshipKeyPathsForPrefetching 属性，否则除了实体（ Entity ）自身的属性（ Attribute ）外，Core Data 对与 Entity 有关联的关系（ Relationship ）也采用了默认的惰性填充规则（ 即使 returnsObjectsAsFaults 为 false ）。

### 数据的多份拷贝

当图片数据从 SQLite 经 Core Data 最终通过 SwiftUI 显示时，实际上在内存中至少保存了三份拷贝：

* 行缓存
* 托管对象上下文（ 托管对象被填充后 ）
* 显示该图片的 SwiftUI 视图（ body 的值中 ）

在第一轮优化中，我们通过显示控制，修改了离开可视区域的视图 body 值（ 删除了一份 Copy ）。如果我们能够在视图离开可视区域时，能让托管对象重新进入惰值状态，或许又能节省一部分内存。

> 由于一个协调器可以对应多个上下文，如果在另一个上下文中，指向同一个图片的另一个托管对象也进行了填充，那么就又会多出一个 Copy

### 不成功的优化

在首轮优化后的代码基础上，做如下添加：

```swift
       .onDisappear {
            show = false
            // 在视图离开可视区域时，尝试让 Item 以及对应的 Picture 对象返回惰值状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewContext.refresh(item, mergeChanges: false)
                if let picture = item.picture {
                    viewContext.refresh(picture, mergeChanges: false)
                }
            }
        }
```

修改后运行程序，我们会惊异地发现 —— **几乎没有变化**！

**原因何在**？？？

通过代码检查托管对象会发现，尽管托管对象已经转为惰性状态，但实际上并没有节省多少内存。这是因为，我们在定义 Picture 的 data 属性时，设置了 `Allows External Storage` 选项。这意味着，在托管对象上下文中，data 属性即使在填充后也仅有 50 个字节（ 文件 ID ）。

> 目前无法找到 Core Data 在行缓存以及上下文中处理这些外置二进制数据的任何资料。不过通过实验中分析，这些数据肯定是被缓存的，且在被加载后，并不会因为返回惰值而自动从内存中清除

因此，即使我们将托管对象返回成惰值状态，也仅能节省极少的内存占用（ 在本例中几乎可以忽略不计 ）。

### 效果有限但潜力不小的优化

为了能对图片数据在上下文中的表现有更加精准的控制，我修改了 data 属性的设置，取消了 `Allows External Storage` 选项。

> 为了保证程序顺利运行，需要从模拟器（ 或真机 ）上首先删除 App，然后再重新安装

相较于第一轮的优化，本次优化后内存占用有了一定的改善（ 幅度不到 100 MB ）。

![binary-store-in-Sqlite- iPhone 14 Pro - 2023-03-07 at 11.23.52.2023-03-07 11_26_42](https://cdn.fatbobman.com/binary-store-in-Sqlite-%20iPhone%2014%20Pro%20-%202023-03-07%20at%2011.23.52.2023-03-07%2011_26_42.gif)

尽管本轮优化的效果一般（ 且数据增加后，内存占用仍呈线性增长 ），但至少表明是有机会从 Core Data 中找到可优化的角度。

```responser
id:1
```

## 终极优化：私有上下文 + 不持有托管对象

### 思路

在第二轮优化中，尽管通过将托管对象转换为惰值解决了一部分内存占用问题，但存在于行缓存中的数据始终还是无法得到有效清除。是否有可能将上下文以及行缓存中数据所占空间一并优化掉？

为了减少内存占用，Core Data 对于不需要的数据空间采用积极的释放策略。如果一个托管对象失去了强引用，那么 Core Data 将很快便释放掉它所占用的上下文中的内存空间。如果一条记录（ 数据库中的数据 ），无论哪个上下文中都没有与其对应的托管对象，那么也将快速地清理其所占用的行缓存空间。

也就是说，**如果我们能让数据仅在视图出现在惰性容器可见范围内，才创建一个指向该数据的托管对象，并且在视图离开可视区域时，删除该对象（ 放弃引用 ），那么就可以通过 Core Data 自身的内存释放机制来完成本轮优化**。

根据上述原理，我们将尝试如下过程：

* 在 onAppear 的闭包中，通过私有上下文创建一个 Picture 对象
* 将 data 属性的数据转换成 Image，并保存在视图中的一个 Source of truth 中
* 在视图显示该 Image
* onAppear 闭包运行结束时，Picture 对象将自动被释放
* 在 onDisapper 中清除 Source of truth 中的内容（ 设置为 nil ）

按照预想，由于该 Picture 托管对象仅存活于视图的 onAppear block 中，闭包执行完毕后，Core Data 会自动释放上下文以及行缓存中对应的数据。

代码如下：

```swift
struct ItemCell: View {
    @ObservedObject var item: Item
    @State var image: Image?
    @Environment(\.managedObjectContext) var viewContext
    let imageSize: CGSize = .init(width: 120, height: 160)
    @State var show = true
    var body: some View {
        HStack {
            if show {
                Text(self.item.timestamp?.timeIntervalSince1970 ?? 0, format: .number)
                if let image = image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: self.imageSize.width, height: self.imageSize.height)
                } else {
                    Rectangle()
                        .frame(width: self.imageSize.width, height: self.imageSize.height)
                }
            }
        }
        .frame(minWidth: .zero, maxWidth: .infinity)
        .onAppear {
            show = true
            Task {
                if let objectID = item.picture?.objectID { // 获取 ObjectID 并不会触发惰性填充
                    let imageData: Data? = await PersistenceController.shared.container.performBackgroundTask { context in
                        if let picture = try? context.existingObject(with: objectID) as? Picture, let data = picture.data {
                            return data
                        } else { return nil }
                    }
                    if let imageData {
                        image = Image(uiImage: UIImage(data: imageData)!)
                    }
                }
            }
        }
        .onDisappear {
            show = false
            image = nil
        }
    }
}
```

**理想很丰满，现实很骨感**，执行上述代码后，内存并不会有很大的改善。问题又出现在什么地方呢？

### 释放不积极的 @State

上面代码的问题，是因为我们使用了声明为 @State 的变量来暂存 Image。在惰性容器中，与积极释放 body 所占内存容量的策略不同，@State 对应值的释放并不积极。即使我们在 onDisappear 中将该变量设置为 nil，但 SwiftUI 并没有释放之前它所占用的空间。

以下面的代码举例：

```swift
struct MemeoryReleaseDemoByState: View {
    @State var data: Data?
    @State var memory: Float = 0
    var body: some View {
        VStack {
            Text("memory :\(memory)")
            Button("Generate Data") {
                data = Data(repeating: 0, count: 10000000)
                memory = reportMemory()
            }
            Button("Release Memory") {
                data = nil
                memory = reportMemory()
            }
        }
        .onAppear{
            memory = reportMemory() // reportMemory 将报告当前 app 的内存占用，实现请查看本文范例代码
        }
    }
}
```

> 首先点击 “Generate Data”，然后点击 “Release Memory”，你会发现尽管 data 设置为 nil，但 app 所占据的内存空间并没有减少

在这种情况下，我们可以通过引用类型来创建一个 Holder，通过该持有器，解决释放不积极的问题。

```swift
struct MemeoryReleaseDemoByStateObject: View {
    @StateObject var holder = Holder()
    @State var memory: Float = 0
    var body: some View {
        VStack {
            Text("memory :\(memory)")
            Button("Generate Data") {
                holder.data = Data(repeating: 0, count: 10000000)
                memory = reportMemory()
            }
            Button("ReleaseMemory") {
                holder.data = nil
                memory = reportMemory()
            }
        }
        .onAppear{
            memory = reportMemory()
        }
    }
    
    class Holder:ObservableObject {
        @Published var data:Data?
    }
}
```

> SwiftUI 只会持有 @StateObject 所对应实例的引用，实例中属性数据的释放仍遵循标准的 Swift 语言逻辑。因此，通过 Holder，我们可以按照自己的想法释放不需要的内存

修改后的代码：

```swift
struct ItemCell: View {
    @ObservedObject var item: Item
    @StateObject var imageHolder = ImageHolder()
    @Environment(\.managedObjectContext) var viewContext
    let imageSize: CGSize = .init(width: 120, height: 160)
    @State var show = true
    var body: some View {
        HStack {
            if show {
                Text(self.item.timestamp?.timeIntervalSince1970 ?? 0, format: .number)
                if let image = imageHolder.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: self.imageSize.width, height: self.imageSize.height)
                } else {
                    Rectangle()
                        .frame(width: self.imageSize.width, height: self.imageSize.height)
                }
            }
        }
        .frame(minWidth: .zero, maxWidth: .infinity)
        .onAppear {
            show = true
            Task {
                if let objectID = item.picture?.objectID {
                    let imageData: Data? = await PersistenceController.shared.container.performBackgroundTask { context in
                        if let picture = try? context.existingObject(with: objectID) as? Picture, let data = picture.data {
                            return data
                        } else { return nil }
                    }
                    if let imageData {
                        imageHolder.image = Image(uiImage: UIImage(data: imageData)!)
                    }
                }
            }
        }
        .onDisappear {
            show = false
            self.imageHolder.image = nil
        }
    }
}

class ImageHolder: ObservableObject {
    @Published var image: Image?
}
```

在最终的代码中，我们对图片数据在内存中的三个备份实现了有效的控制。在同一时间（ 理想情况下 ），只有出现在可视区域的图片数据才会保存在内存中。

![privateContext- iPhone 14 Pro - 2023-03-07 at 11.39.00.2023-03-07 11_40_09](https://cdn.fatbobman.com/privateContext-%20iPhone%2014%20Pro%20-%202023-03-07%20at%2011.39.00.2023-03-07%2011_40_09.gif)

可以加大检测力度，即使在生成了 400 条记录的情况下，内存占用也仍然被控制在一个相当理想的状态（ 下图为 400 条数据滚动到底部的内存占用情况 ）。

![私有上下文滚动至底截屏](https://cdn.fatbobman.com/image-20230307114909422.png)

至此，我们终于完成了对该段代码的优化，无需再担心其可能因占用内存过大而导致的崩溃。

## 总结

SwiftUI 的惰性容器使用起来很方便，并且通过 @FetchRequest 与 Core Data 配合也很方便，这在一定程度上导致开发者有了轻视的心理，认为 SwiftUI + Core Data 会为我们处理一切。但在有些情况下，我们仍然需要通过自己对两者的深入理解对代码进行高度优化才能取得预期的效果。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**
