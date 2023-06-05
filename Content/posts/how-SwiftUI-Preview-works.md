---
date: 2023-05-23 08:12
description: 作为 SwiftUI 最引人注目的功能之一，预览功能吸引了不少开发者初次接触 SwiftUI。然而，随着项目规模的增长，越来越多的开发者发现预览功能并不如最初想象的那么易用。由于预览崩溃的次数和场景的增加，一些开发者已经视预览为 SwiftUI 的缺点之一，并对其产生了排斥感。预览功能真的如此不堪吗？我们当前使用预览的方式真的妥当吗？我将通过两篇文章来分享我对预览功能的认知和理解，并探讨如何构建稳定的预览。本文将首先剖析预览功能的实现机制，让开发者了解哪些情况是预览必然无法处理的。
tags: SwiftUI
title: 构建稳定的预览视图 —— SwiftUI 预览的工作原理
image: images/how-SwiftUI-Preview-works.jpg
---
作为 SwiftUI 最引人注目的功能之一，预览功能吸引了不少开发者初次接触 SwiftUI。然而，随着项目规模的增长，越来越多的开发者发现预览功能并不如最初想象的那么易用。由于预览崩溃的次数和场景的增加，一些开发者已经视预览为 SwiftUI 的缺点之一，并对其产生了排斥感。 

预览功能真的如此不堪吗？我们当前使用预览的方式真的妥当吗？我将通过两篇文章来分享我对预览功能的认知和理解，并探讨如何构建稳定的预览。本文将首先剖析预览功能的实现机制，让开发者了解哪些情况是预览必然无法处理的。

## 让预览崩溃的一段视图代码

不久前，Toomas Vahter 写了一篇博客 [Bizarre error in SwiftUI preview](https://augmentedcode.io/2023/04/17/bizarre-error-in-swiftui-preview/)，其中提到了一个有趣的现象。下面这段代码可以在真机和模拟器上运行，但会导致预览崩溃。

```swift
import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = ViewModel()
    var body: some View {
        VStack {
            ForEach(viewModel.items) { item in
                Text(verbatim: item.name)
            }
        }
        .padding()
    }
}

extension ContentView {
    final class ViewModel: ObservableObject {
        let items: [Item] = [
            Item(name: "first"),
            Item(name: "second"),
        ]
        func select(_: Item) {
            // implement
        }
    }

    struct Item: Identifiable {
        let name: String
        var id: String { name }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
```

解决的方法，便是将：

```swift
func select(_: Item) {
            // implement
}
```

修改为：

```swift
func select(_: ContentView.Item) {
            // implement
}
```

修改后，预览功能可以正常工作了。可惜的是，Toomas Vahter在文章中没有告诉读者崩溃原因。我借用这段代码来与大家一起探究预览功能是如何工作的。

> 感谢 Dennis Nehrenheim 在 Medium 上的告知，这个问题已经在 Xcode 14.3.1 下被解决了。不过，即便如此，并不影响本文对预览原理的解释。

```responser
id:1
```

## 探寻预览崩溃的原因

首先，创建一个名为 StablePreview 的新 iOS 项目。将上述代码复制到其中（ **注意：此时不要启动视图预览** ），然后编译项目。 

![image-20230522105513088](https://cdn.fatbobman.com/image-20230522105513088.png)

找到该项目对应的 Derived Data 目录。

![image-20230522105916884](https://cdn.fatbobman.com/image-20230522105916884.png)

在项目对应的 Derived Data 目录中，查找尾缀为 `.preview-thunk.swift` 的文件：

![image-20230522110506987](https://cdn.fatbobman.com/image-20230522110506987.png)

此时 Derived Data 目录中应该没有满足条件的文件。

点击预览的启用按钮，启动预览。

![image-20230522110636690](https://cdn.fatbobman.com/image-20230522110636690.png)

你会发现预览无法正常使用，错误提示为：

![image-20230522110719469](https://cdn.fatbobman.com/image-20230522110719469.png)

我们再次查找当前项目 Derived Data 目录下尾缀为 `.preview-thunk.swift` 的文件。

![image-20230522110813828](https://cdn.fatbobman.com/image-20230522110813828.png)

这时候，你会看到 Xcode 帮助我们生成了一个名为 `ContentView.1.preview-thunk.swift` 的文件。该文件是 Xcode 为预览功能生成的衍生代码，让我们打看这个文件，看看究竟生成了什么内容。

```swift
@_private(sourceFile: "ContentView.swift") import StablePreview
import SwiftUI
import SwiftUI

extension ContentView_Previews {
    @_dynamicReplacement(for: previews) private static var __preview__previews: some View {
        #sourceLocation(file: "/Users/yangxu/Documents/博客相关/BlogCodes/StablePreview/StablePreview/ContentView.swift", line: 34)
        ContentView()
    
#sourceLocation()
    }
}

extension ContentView.Item {
typealias Item = ContentView.Item

    @_dynamicReplacement(for: id) private var __preview__id: String {
        #sourceLocation(file: "/Users/yangxu/Documents/博客相关/BlogCodes/StablePreview/StablePreview/ContentView.swift", line: 28)
 name 

#sourceLocation()
    }
}

extension ContentView.ViewModel {
typealias ViewModel = ContentView.ViewModel

    @_dynamicReplacement(for: select(_:)) private func __preview__select(_: Item) {
        #sourceLocation(file: "/Users/yangxu/Documents/博客相关/BlogCodes/StablePreview/StablePreview/ContentView.swift", line: 22)

#sourceLocation()
            // implement
    }
}

extension ContentView {
    @_dynamicReplacement(for: body) private var __preview__body: some View {
        #sourceLocation(file: "/Users/yangxu/Documents/博客相关/BlogCodes/StablePreview/StablePreview/ContentView.swift", line: 6)
        VStack {
            ForEach(viewModel.items) { item in
                Text(verbatim: item.name)
            }
        }
        .padding()
    
#sourceLocation()
    }
}

import struct StablePreview.ContentView
import struct StablePreview.ContentView_Previews
```

其中有这么几个语言特性需要注意：

* `@_private(sourceFile: )`

让当前代码可以访问原本外部无法访问的变量和函数，这样我们就无需在项目代码中提高访问权限。

* `#sourceLocation(file: ,line: )`

负责将衍生代码中发生的崩溃等调试信息反映在我们写的代码上，帮助开发者找到对应的源代码位置。

* `@_dynamicReplacement(for: )`

`@_dynamicReplacement` 是实现预览功能的关键机制。它用于指定某个方法作为另一个方法的动态替代方法。在衍生代码中，Xcode 使用 @_dynamicReplacement 为多个函数提供了替代方法。在预览时，以替代后的 `__preview__previews` 方法作为预览入口。请参阅 [Swift Native method swizzling](https://www.guardsquare.com/blog/swift-native-method-swizzling) 以了解 @_dynamicReplacement 的更多信息。

* `import struct StablePreview.ContentView`

在衍生代码中，未使用 `import StablePreview`，而是使用了 `import struct StablePreview.ContentView`。这意味着编译器在编译这段代码时，可以依赖的信息很少，只能在很小的范围内进行类型推断，以提高效率。这也是本段代码无法在预览中正常运行的主要原因。

编译器在编译下面的代码时，无法找到 Item 对应的定义，因此导致预览失败。

```swift
extension ContentView.ViewModel { // 无法进行正确的类型推断
typealias ViewModel = ContentView.ViewModel

    @_dynamicReplacement(for: select(_:)) private func __preview__select(_: Item) {
        #sourceLocation(file: "/Users/yangxu/Documents/博客相关/BlogCodes/StablePreview/StablePreview/ContentView.swift", line: 22)

#sourceLocation()
            // implement
    }
}
```

按照原博客的做法，将 `func select(_: Item)` 特征为 `func select(_: ContentView.Item)` 后，衍生代码将改变为：

```swift
extension ContentView.ViewModel {
typealias ViewModel = ContentView.ViewModel

    @_dynamicReplacement(for: select(_:)) private func __preview__select(_: ContentView.Item) { // 具备了详细的信息，可以获取到 Item 的定义
        #sourceLocation(file: "/Users/yangxu/Documents/博客相关/BlogCodes/StablePreview/StablePreview/ContentView.swift", line: 22)

#sourceLocation()
            // implement
    }
}
```

因此在编译的时候，也就能够正确的获取 Item 的定义信息了。

这就解释了这段代码为什么在模拟器和真机中可以运行，但会导致预览崩溃。因为预览是以衍生代码作为入口，只依赖有限的导入信息对衍生代码进行编译，因此可能会出现因信息不完整而无法编译的情况。而在模拟器和真机运行时，并不需要编译为预览准备的衍生代码，只需要编译项目文件即可。编译器能够从完整的代码中正确推断出 ContentView 中的 Item 对应 `func select(_: Item)` 中的 Item。

了解了问题所在，我们还可以使用其他两种方式来解决之前的代码无法在预览中使用的问题。

* 方法一

将 Item 从 ContentView 中移出来，放置到与 ContentView 同级的代码位置。这样，在预览的衍生代码中，将会出现 `import struct StablePreview.Item` 这行代码。编译器也就能够正确处理 `func select(_: Item)` 了。

* 方法二

在与 ContentView 同级的代码位置添加 `typealias Item = ContentView.Item`。在预览的衍生代码中，将会出现 `typealias Item = StablePreview.Item` 。经过两次别名指引，编译器也能找到正确的 Item 定义。

接下来，让我们继续查看 Xcode 是如何加载预览视图的。。

在项目的 Derived Data 目录中查找尾缀为 `.preview-thunk.dylib` 的文件。

![image-20230522131911942](https://cdn.fatbobman.com/image-20230522131911942.png)

该文件是预览状态下衍生代码编译后生成的动态库。在该文件所在位置执行以下命令： `nm ./ContentView.1.preview-thunk.dylib | grep ' T '` 

![image-20230522132730344](https://cdn.fatbobman.com/image-20230522132730344.png)

可以看出，Xcode 在编译了预览的衍生文件后，在动态库中只生成了一个 `_main 方法`。在该方法中，大概率进行了定义预览相关的环境设置、设置预览初始状态等操作。最后，再创建了几个专门用于预览的进程。通过 XPC 在预览进程与 Xcode 之间进行通信，最终实现了在 Xcode 中预览特定视图的目的。

![image-20230522134401399](https://cdn.fatbobman.com/image-20230522134401399.png)

> 阅读 Damian Malarczyk 所写的 [Behind SwiftUI Previews](https://www.guardsquare.com/blog/behind-swiftui-previews) 一文，了解更多实现细节。

```responser
id:1
```

## 预览的工作流程

我们对上面的探索过程进行一个梳理，大致上可以得到如下的工作流程：

* Xcode 生成预览衍生代码文件
* Xcode 编译整个项目，解析文件、获取预览视图实现、准备依赖的其他资源
* Xcode 编译预览衍生代码文件，创建动态库
* Xcode 启动预览进程，在其中加载 _XCPreviewKit 框架和预览衍生文件生成的 dylib
* XCPreviewKit 框架在预览进程中创建预览窗口
* Xcode 通过 XPC 发送消息指令， _XCPreviewKit 框架更新预览窗口，并在两个进程建进行交互与同步
* 用户在 Xcode 界面中看到预览效果

## 从预览的实现中可以得到的部分结论

* 如果项目无法编译，预览也无法正常运行
* 预览并没有启动完整的模拟器，因此某些代码无法在预览中实现预期的行为，例如（ 预览不存在应用程序的生命周期事件 ）：

```swift
struct ContentView: View {

    var body: some View {
        VStack {
            Text("Hello world")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("App will resign active")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
```

* 为了提高效率，生成的预览衍生文件会尽可能减少不必要的导入。但是，这也可能导致无法正常编译的情况发生（例如本文中的例子）
* 预览是以预览衍生文件作为入口的，开发者必须在预览代码中为预览视图提供足够的上下文信息（ 例如注入所需的环境对象 ）

总的来说，Xcode 预览功能虽然在视图开发流程中极为方便，但它仍处在一个功能受限的环境中。开发者使用预览时需要清醒地认识到其局限性，并避免在预览中实现超出其能力范围的功能。

## 接下来

在本文中，我们探讨了 Xcode 预览功能的实现原理，并指出其存在一定局限性。在下一篇文章中，我们将从开发者的角度审视预览功能：它的设计目的、最适宜的使用场景以及如何构建稳定高效的预览。

欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周最新文章。**