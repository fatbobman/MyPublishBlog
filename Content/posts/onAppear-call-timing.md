---
date: 2023-03-29 08:12
description: onAppear（ task ）是 SwiftUI 开发者经常使用的一个修饰符，但一直没有权威的文档明确它的闭包被调用的时机。本文将通过 SwiftUI 4 提供的新 API ，证明 onAppear 的调用时机是在布局之后、渲染之前。
tags: SwiftUI
title: onAppear 的调用时机
image: images/onAppear-call-timing.png
mediumURL: https://medium.com/p/40c406ae783e
---
onAppear（ task ）是 SwiftUI 开发者经常使用的一个修饰符，但一直没有权威的文档明确它的闭包被调用的时机。本文将通过 SwiftUI 4 提供的新 API ，证明 onAppear 的调用时机是在布局之后、渲染之前。

## 问题

同之前多篇博客类似，我们还是从 [聊天室](https://discord.gg/ApqXmy5pQJ) 的一个 [问题](https://discord.com/channels/967978112509935657/967978112509935663/1085178054625734776) 开始。

![image-20230328163706115](https://cdn.fatbobman.com/image-20230328163706115.png)

请忽略例子中的写法是否合理和值得推荐，仅考虑为什么在第一段代码中，出现了数组越界的情况；以及第二段代码可以正确运行。

```responser
id:1
```

## 创建实例、求值、布局、渲染

在 SwiftUI 中，一个视图在它的生命周期中通常会经历四个阶段：

### 创建实例

视图树中，处于可显示分支的视图基本上都会经历的一个阶段。在一个视图的生存期中，SwiftUI 可能会多次创建视图实例。

> 由于惰性视图的优化机制，对于尚未处于可见区域的子视图，SwiftUI 不会创建其实例

### 求值

一个被显示的视图至少会经历一次的过程。由于 SwiftUI 的视图实际上是一个函数，SwiftUI 需要对视图进行求值（ 调用 body 属性 ）并保留计算结果。当视图的依赖（ Source of truth ）发生变化后，SwiftUI 会重新计算视图结果值，并与旧值进行比较。如发生变化，则用新值替换旧值。

### 布局

在计算好当前需要显示的视图所有的视图值后，SwiftUI 将进入到布局阶段。通过父视图向子视图提供建议尺寸，子视图返回需求尺寸这一过程，最终计算出完整的布局结果。

> 有关布局的流程请阅读 [SwiftUI 布局 —— 尺寸](https://fatbobman.com/posts/layout-dimensions-1/) 

### 渲染

SwiftUI 通过调用更加底层的 API，将视图在屏幕上呈现的过程。此过程严格意义上已经不属于 SwiftUI 的管理范畴了。

## Appear 是相对于谁的？

在不少的词典中，appear 都被解释为例如 `to come into sight; become visible` 这样的意思。这会让开发者误以为 onAppear 是在视图渲染后（ 使用者看到后 ）才被调用的。但在 SwiftUI 中，onAppear 实际上是在渲染前被调用的。

假设排除了苹果起名出现了错误这个原因，此时的 appear 更像是针对 SwiftUI 系统来说的。视图在完成了创建实例、求值、布局后（ 完成了属于 SwiftUI 架构的管理流程 ），就算是 appear 于 SwiftUI 的“眼前”。

## 求证

口说无凭，本节我们将用证据来证明上述推断。

> 在写 [SwiftUI 视图的生命周期研究](https://fatbobman.com/posts/swiftUILifeCycle/) 一文时，我们只能通过现象来推断 onAppear 的调用时机，随着版本的不断提高，SwiftUI 4 中为我们提供了足够的工具让我们可以获得更加确实的证据。

### 判断视图正在求值

在视图中添加类似如下的代码，是我们判断 SwiftUI 是否正在对视图进行求值的常用手段：

```swift 
VStack {
  let _ = print("evaluate")
}
```

### 判断视图正处于布局阶段

在 4.0 中版本中，SwiftUI 提供了 Layout 协议，允许我们创建自定义布局容器，通过创建符合该协议的实例，我们便可以判断当前视图是否正处于布局阶段。

```swift
struct MyLayout: Layout {
    let name: String
    func sizeThatFits(proposal _: ProposedViewSize, subviews _: Subviews, cache _: inout ()) -> CGSize {
        print("\(name) layout")
        return .init(width: 100, height: 100)
    }

    func placeSubviews(in _: CGRect, proposal _: ProposedViewSize, subviews _: Subviews, cache _: inout ()) {}
}
```

上面的代码创建了一个固定返回 100 * 100 需求尺寸的布局容器，在父视图询问其需求尺寸时将通过控制台报告给我们。

### 判断视图正准备渲染

尽管 SwiftUI 视图并没有提供可以展示该过程的 API，不过我们可以利用 UIViewControllerRepresentable 协议来包装一个 UIViewController ，并通过它的生命周期回调方法来确定当前的状态。

```swift
struct ViewHelper: UIViewControllerRepresentable {
    func makeUIViewController(context _: Context) -> HelperController {
        return HelperController()
    }

    func updateUIViewController(_: HelperController, context _: Context) {
    }
    
    // SwiftUI 4 新增方法
    func sizeThatFits(_: ProposedViewSize, uiViewController _: HelperController, context _: Context) -> CGSize? {
        print("helper layout")
        return .init(width: 50, height: 50)
    }
}

final class HelperController: UIViewController {
    override func viewWillAppear(_: Bool) {
        print("will appear(render)")
    }
}
```

在上面的代码中，sizeThatFits 与 Layout 协议的 sizeThatFits 调用时机一致，都是在布局过程中，父视图向子视图询问需求尺寸时访问。viewWillAppear 则是在 UIViewController 被呈现前（ 可以理解为渲染前 ），会由 UIKit 调用。

> 通过 UIViewControllerRepresentable 封装的“视图”并非真正的视图，对于 SwiftUI 来说，它就是一块给出了需求尺寸的黑洞，因此并不存在求值一说。

### 整合

有了上面的工具，通过下面的代码，我们便可以完整地了解一个 SwiftUI 视图的处理过程，以及 onAppear 的调用时机。

```swift
struct LayoutTest: View {
    var body: some View {
        MyLayout(name: "outer") {
            let _ = print("outer evaluate")
            MyLayout(name: "inner") {
                let _ = print("inner evaluate")
                ViewHelper()
                    .onAppear {
                        print("helper onAppear")
                    }
            }
            .onAppear {
                print("inner onAppear")
            }
        }
        .onAppear {
            print("outer onAppear")
        }
    }
}
```

输出如下：

```bash
outer evaluate
inner evaluate
outer layout
inner layout
helper layout
outer onAppear
helper onAppear
inner onAppear
will appear(render)
```

### 分析

通过上面的输出，可以清楚地了解视图处理的全过程：

* SwiftUI 首先对视图进行求值（ 由外向内 ）
* 在全部求值结束后开始进行布局（ 由父视图到子视图 ）
* 在布局结束后，调用视图对应的 onAppear 闭包（ 顺序不明，不要假定 onAppear 之间的执行顺序 ）
* 渲染视图

由此可以证明，onAppear 确实是在布局之后，渲染之前被调用的。

```responser
id:1
```

## 解答

回到本文最初的问题。

### 第一段代码

* 对 VStack 进行求值
* 计算到 Text ，创建 Text 实例
* 创建实例时，需要调用 getWord 来获取参数
* 此时由于 newWords 数组为空，因此出现数组越界的错误

也就是说，在第一段代码报错时，该视图甚至还没有进入到布局阶段，就更不用提调用 onAppear 了。

在不考虑使用绝对索引值是否正确的情况下，通过下面的代码，便可以避免问题的出现：

```swift
if !newWords.isEmpty {
    Text(getWord(at:0))
}
```

### 第二段代码

* 对 List 进行求值
* 由于 ForEach 会根据 newWords 的数量进行子视图的处理，因此尽管此时 newWords 为空，但也不会有问题
* 完成布局
* 调用 onAppear 闭包，给 newWords 赋值
* 由于 newWords 是该视图的 Source of truth ，发生改变后，导致视图重新刷新
* 重复上面的过程，此时 newWords 已经有值了，ForEach 将正常处理所有的子视图

## 总结

在本文中，我们通过 SwiftUI 4 提供的新工具明确了 onAppear 的调用时机，或许这是新 API 开发时未曾想到的功能应用。

