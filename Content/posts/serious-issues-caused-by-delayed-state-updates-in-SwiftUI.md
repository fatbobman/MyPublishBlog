---
date: 2023-08-30 08:12
description: 本文将解析 SwiftUI 中两个由于未能贯彻响应式编程原则而导致的严重错误，并提供相应的解决方案。这两个错误包括：通过手势取消 Sheet 后，快速右滑导航容器导致应用锁死；以及在滚动中返回上层视图时导致应用崩溃。
tags: SwiftUI
title: 解析 SwiftUI 中两处由状态更新滞后引发的严重 Bug
mediumURL: https://medium.com/p/76ffd8431c5a
image: images/two-serious-bugs-caused-by-delayed-state-updates-in-SwiftUI.jpg
---
众所周知，SwiftUI 是一个响应式框架，这意味着，当数据源发生变化时，框架会自动更新视图。同样，当我们想调整视图显示时，应直接对状态进行修改。但是，SwiftUI 中的一些系统控件并没有完全遵循响应式的设计原则，由此在某些情况下会出现严重的错误，影响用户体验，并使开发者无所适从。

本文将解析 SwiftUI 中两个由于未能贯彻响应式编程原则而导致的严重错误，并提供相应的解决方案。这两个错误包括：通过手势取消 Sheet 后，快速右滑导航容器导致应用锁死；以及在滚动中返回上层视图时导致应用崩溃。

```responser
id:1
```

## 视图变化在前、状态变化在后

在 SwiftUI 中，某些可编程控件在执行一定的操作时，会先更新视图，待视图变化完成后再修改与其对应的状态。这些控件基本上都是对 UIkit（AppKit）的二次包装。

### Sheet

执行下面的代码，你可以清楚地看到，在通过手势取消 Sheet 时，与其关联的状态是在 Sheet 完成取消动画后才发生了改变。而通过调用环境值或直接修改绑定状态，SwiftUI 则遵循了响应式编程原则，进行了的先调整状态，后更新视图的操作。

```swift
struct SheetDemo: View {
    @StateObject var store = SheetStore()
    var body: some View {
        Button("Show") {
            store.show.toggle()
        }
        .sheet(isPresented: $store.show) {
            SheetView()
                .environmentObject(store)
        }
    }
}

struct SheetView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: SheetStore
    var body: some View {
        VStack {
            Button("Dismiss by ENV") {
                print("Dismiss by ENV")
                dismiss()
            }
            Button("Dismiss by Store") {
                print("Dismiss by Store")
                store.show = false
            }
        }
    }
}

class SheetStore: ObservableObject {
    @Published var show = false {
        didSet {
            print("show \(show ? "T" : "F")")
        }
    }
}
```

> 请注意观察，在操作后命令行界面的输出情况。

![sheet-dismiss-demo_2023-08-29_15.37.17.2023-08-29 15_40_10](https://cdn.fatbobman.com/sheet-dismiss-demo_2023-08-29_15.37.17.2023-08-29%2015_40_10.gif)

### NavigationStack

NavigationStack 同样也存在类似的情况。运行下面的代码，点击左上方的返回按钮，与 NavigationStack 绑定的 path，直到视图返回上一层后，才会发生改变。通过环境值返回上层视图也同样需要等待视图返回后，才会修改状态。只有直接修改 path，SwiftUI 才能表现的像一个真正的响应式编程框架。

```swift
struct NavigationStackDemo: View {
    @StateObject var store = StackStore()
    var body: some View {
        NavigationStack(path: $store.path) {
            List(0 ..< 20) { i in
                NavigationLink(value: i) { Text("\(i)") }
            }
            .navigationDestination(for: Int.self) { n in
                Row(n: n)
                    .environmentObject(store)
            }
        }
    }
}

struct Row: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: StackStore
    let n: Int
    var body: some View {
        List {
            Button("Dismiss By ENV") {
                print("Dismiss By Env")
                dismiss()
            }
            Button("Dismiss By Store") {
                print("Dismiss by Store")
                store.path.removeLast()
            }
        }
        .navigationTitle("\(n)")
    }
}

class StackStore: ObservableObject {
    @Published var path = [Int]() {
        didSet {
            print("set path \(path)")
        }
    }
}
```

![stack-back-demo_2023-08-29_15.55.31.2023-08-29 15_56_48](https://cdn.fatbobman.com/stack-back-demo_2023-08-29_15.55.31.2023-08-29%2015_56_48.gif)

### 这有什么问题吗？

如果仅从上述两个例子考虑，无论状态调整是否及时，都不会出现什么错误的结果。但是，当应用程序处于某些特殊状态或用户进行某些特定操作时，状态更新的滞后会导致不可接受的后果。

## 通过手势取消 Sheet 后，快速右滑导航容器会导致应用锁死

这是一个在 SwiftUI 所有版本中存在的错误，你可以在众多的论坛或聊天室里看到不少的开发者都在寻找解决方法。它的复现条件非常简单：

- 在真机上测试（ 模拟器上不容易复现 ）
- 点击 “GO” 按钮进入下一层视图
- 点击 “Show Sheet” 按钮弹出 Sheet
- 通过下滑手势取消 Sheet
- 在 Sheet 取消后（动画结束时），**立即**在屏幕上由左至右滑动，返回上一层视图
- 在滑动返回到上一层视图后，应用会锁死。

```swift
struct SheetDismissDemo: View {
    @State var showSheet = false
    var body: some View {
        NavigationStack {
            VStack {
                NavigationLink("GO") {
                    VStack {
                        Button("Show Sheet") {
                            showSheet.toggle()
                        }
                        .sheet(isPresented: $showSheet) {
                            SheetDetailView()
                        }
                    }
                }
            }
        }
    }
}

struct SheetDetailView: View {
    var body: some View {
        Text("Sheet")
    }
}
```

> 注意观察，在尝试使用手势返回上层视图后，左上角的 Back 按钮将消失，但视图并没有返回根视图

![sheet-dismiss-demo2_Final1693298235.2023-08-29 16_39_51](https://cdn.fatbobman.com/sheet-dismiss-demo2_Final1693298235.2023-08-29%2016_39_51.gif)

如果我告诉你，上述情况正是由前文提到的状态更新滞后所导致，那么你该如何避免这个问题呢？

我们首先做一个测试：

```swift
struct SheetDetailView: View {
    @Binding var isPresented: Bool
    var body: some View {
        Button("Dismiss") {
            isPresented = false
        }
    }
}
```

在修改了 SheetDetailView 的代码后，我们不再使用手势来取消 Sheet，而是通过点击 “Dismiss” 按钮来实现这一操作。再次执行上述过程，您会发现在返回上层视图后，应用并不会锁死，一切都恢复了正常。

然而，明显地，强迫用户点击 “Dismiss” 按钮并不是一个好的选择，特别是在没有屏蔽手势取消 Sheet 的情况下。

通过下面的代码，我们可以让用户使用下滑手势来取消 Sheet，同时又不会导致应用锁死。

```swift
struct SheetDismissDemo: View {
    @State var showSheet = false
    var body: some View {
        NavigationStack {
            VStack {
                NavigationLink("GO") {
                    VStack {
                        Button("Show Sheet") {
                            showSheet.toggle()
                        }
                        .sheet(isPresented: $showSheet) {
                            SheetDetailView()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            Group {
                // disable NavigationStack gesture when showSheet is true
                if showSheet {
                    Color.white.opacity(0.01)
                        .highPriorityGesture(DragGesture(minimumDistance: 0))
                }
            }
        )
    }
}

struct SheetDetailView: View {
    var body: some View {
        Text("Sheet")
    }
}
```

原理如下：当 showSheet 为真时，为 NavigationStack 添加一个屏蔽手势的前景视图，以确保用户只能在 showSheet 为否时通过滑动返回到上一层视图。

```responser
id:1
```

## 当视图正在滚动时返回上一层视图会导致应用崩溃

这是一个由 xiaogd 在我的 Discord 论坛中提出的 [问题](https://discord.com/channels/967978112509935657/1101097701975801887)。它的复现条件如下：

- iOS 16 系统，在真机或模拟器上测试
- 点击视图列表中的按钮，可以进入下一级视图。请至少进入第三级视图
- 滚动当前视图
- 当视图处于滚动状态时，点击 NavigationStack 左上角的 “Back” 按钮。
- 在返回上层视图后，继续点击 “Back” 按钮
- 应用大概率会出现崩溃情况

```swift
struct NavigationStackBackDemo: View {
    @StateObject var pathHolder = PathHolder()
    var body: some View {
        NavigationStack(path: $pathHolder.path) {
            DetailView()
                .navigationDestination(for: Int.self) { _ in
                    DetailView()
                }
        }
        .environmentObject(pathHolder)
    }
}

struct DetailView: View {
    @EnvironmentObject var holder: PathHolder
    var body: some View {
        ScrollView {
            ForEach(0 ..< 100) { i in
                NavigationLink(value: i) {
                    Text("\(i)")
                        .font(.title)
                        .foregroundStyle(.yellow)
                        .frame(maxWidth: .infinity)
                        .frame(height:150).padding(.vertical,5)
                        .background(.blue)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(!holder.path.isEmpty ? "\(holder.path.count)" : "Root")
    }
}

class PathHolder: ObservableObject {
    @Published var path = [Int](){
        didSet{
            print("set path \(path)")
        }
    }
}
```

![navigationStack-back-demo2_2023-08-29_18.10.50.2023-08-29 18_12_07](https://cdn.fatbobman.com/navigationStack-back-demo2_2023-08-29_18.10.50.2023-08-29%2018_12_07.gif)

根据前文所述，我们知道直接点击 NavigationStack 提供的 Back 按钮，状态只会在视图已经返回到上一层时才会更新。如果我们认为问题出在这里，就需要使用编程式导航的方式来调整代码。

为了不影响用户的使用习惯，我们禁用了 NavigationStack 自带的 Back 按钮。通过自定义返回按钮以及扩展 UINavigationController 的方式，实现了在禁用 Back 按钮后仍支持手势返回，并先修改状态后再进行视图响应。

```swift
ScrollView {
  ....
}
// start
.navigationBarBackButtonHidden(true)
.toolbar {
    if !holder.path.isEmpty {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                holder.path.removeLast()
            } label: {
                Image(systemName: "chevron.backward")
            }
        }
    }
}
// end
.navigationBarTitleDisplayMode(.inline)
```

扩展 UINavigationController：

```swift
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    // Allows swipe back gesture after hiding standard navigation bar with .navigationBarHidden(true).
    public func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }

    // Allows interactivePopGestureRecognizer to work simultaneously with other gestures.
    public func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }

    // Blocks other gestures when interactivePopGestureRecognizer begins (my TabView scrolled together with screen swiping back)
    public func gestureRecognizer(_: UIGestureRecognizer, shouldBeRequiredToFailBy _: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
```

![navigationStack-back-demo3_2023-08-29_18.20.16.2023-08-29 18_21_23](https://cdn.fatbobman.com/navigationStack-back-demo3_2023-08-29_18.20.16.2023-08-29%2018_21_23.gif)

> 这个问题已经在 iOS 17 中得以修复，不知道是否和我们在 Discord 中讨论后给苹果提交的 Feedback 有关。

## 为什么状态更新滞后会导致严重错误

由于 SwiftUI 的 不透明性，想要分析这些问题的成因并不容易。幸运的是，我从 [@KyleSwifter](https://twitter.com/KyleSwifter) 的 [解密 SwiftUI 背后的 AttributeGraph](https://kyleye.top/posts/demystify-attributegraph-1/) 一文中找到了线索。

AttributeGraph 是 SwiftUI 用于维护众多数据源与视图之间依赖关系的工具。为了改善 AttributeGraph 的效率并减少其占用空间，SwiftUI 会在一些特定情况下对其进行清理和维护（例如通过 `CFRunLoopObserverCreate` 监听 Runtime 的空闲时机）。

在我们遇到问题的两个场景中，应用程序都恰好使用了导航容器，并且通过特定的操作，使 RunLoop 处于了适合 AG 打包更新的状态。由于在返回上层视图时，状态尚未更新，因此在清理 AG 时（返回动画运行中），会破坏应用程序的 AttributeGraph 完整性，从而导致应用程序死锁或崩溃。

因此，当我们首先更新状态，然后 SwiftUI 再响应该状态的变化（返回上层视图），即使此时对 AG 进行清理，仍将可以保证 AttributeGraph 的完整性，应用自然不会出现问题。

> 状态更新滞后不仅存在于本文介绍的两个案例中，当开发者遇到类似情况时，可以尝试采用状态更新优先的开发策略进行修改。

## 总结

今年 SwiftUI 已经进入了第五个年头。随着版本的提高，SwiftUI 的功能也确实得到了相当程度的增加。不过，即使在最新的版本中，在一些对 UIKit（AppKit）进行二次包装的控件中，仍有不少细节处理不到位的问题。希望 SwiftUI 开发组能尽早重视这些问题。

欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周最新文章。**
