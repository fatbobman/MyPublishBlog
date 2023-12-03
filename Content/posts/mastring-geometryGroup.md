---
date: 2023-11-30 08:12
description: 在 WWDC 2023 中，苹果为 SwiftUI 添加了一个新的修饰器：geometryGroup()。它可以解决一些之前无法处理或处理起来比较困难的动画异常。本文将介绍 geometryGroup() 的概念、用法，以及在低版本 SwiftUI 中，在不使用 geometryGroup() 的情况下如何处理异常。
tags: SwiftUI
title: SwiftUI geometryGroup() 指南：从原理到实践
image: images/mastring-geometryGroup.jpg
mediumURL: https://medium.com/p/1a7f4b04c4ec
---
在 WWDC 2023 中，苹果为 SwiftUI 添加了一个新的修饰器：geometryGroup()。它可以解决一些之前无法处理或处理起来比较困难的动画异常。本文将介绍 geometryGroup() 的概念、用法，以及在低版本 SwiftUI 中，在不使用 geometryGroup() 的情况下如何处理异常。

## geometryGroup() 的官方定义

对于 geometryGroup()，苹果提供了一份详细但不易理解的 [文档](https://developer.apple.com/documentation/swiftui/view/geometrygroup%28%29) 解释：

> **geometryGroup()** : 
> 
> Isolates the geometry (e.g. position and size) of the view from its parent view.
> 
> By default SwiftUI views push position and size changes down through the view hierarchy, so that only views that draw something (known as leaf views) apply the current animation to their frame rectangle. However in some cases this coalescing behavior can give undesirable results; inserting a geometry group can correct that. A group acts as a barrier between the parent view and its subviews, forcing the position and size values to be resolved and animated by the parent, before being passed down to each subview.



> **geometryGroup()** : 
> 
> 将视图的几何属性（例如位置和大小）与其父视图隔离开来。
> 
> 默认情况下，SwiftUI 视图会将位置和大小的变化沿视图层级向下传递，以至于只有绘制内容的视图（称为叶子视图）将当前动画应用到它们的框架矩形上。然而在某些情况下，这种聚合行为可能会导致不希望的结果；插入一个几何组可以纠正这种情况。几何组充当父视图与其子视图之间的屏障，迫使位置和大小的值由父视图解析和动画化，然后再传递给每个子视图。
> 

```swift
VStack {
    ForEach(items) { item in
        ItemView(item: item)
            .geometryGroup()
    }
}
```

不知道你怎么看这个文档和附带的代码片段，至少在我初次接触时，很难通过它来理解 geometryGroup() 的真正用途。因为文档遗漏了最主要的部分：”然而在某些情况下，这种聚合行为可能会导致不希望的结果（ However in some cases this coalescing behavior can give undesirable results ）”。

那么，具体在哪些情况下会发生这种情况呢？

```responser
id:1
```

## In Some Cases

为了更好地理解 geometryGroup() 的实际作用，我们需要创建一个因父视图的几何属性发生变化而导致的非预期的子视图呈现，以便弄清楚文档中的“在某些情况下”到底指的是什么情况。

```swift
struct ContentView: View {
    @State var toggle = false
    var size: CGSize {
        toggle ? .init(width: 300, height: 300) : .init(width: 200, height: 200)
    }

    var body: some View {
        VStack {
            Button("Toggle") {
                toggle.toggle()
            }
            TopLeadingTest1(show: toggle)
                .frame(width: size.width, height: size.height)
                .animation(.smooth(duration: 1), value: toggle)
        }
    }
}

struct TopLeadingTest1: View {
    let show: Bool
    var body: some View {
        Color.red
            .overlay(alignment: .topLeading) {
                if show {
                    Circle()
                        .fill(.yellow)
                        .frame(width: 20, height: 20)
                }
            }
    }
}
```

这是一段非常简单的代码，当 `toggle` 的状态改变时，`TopLeadingTest1` 的尺寸会发生变化。同时（`toggle` 状态改变时），我们还在 `TopLeadingTest1`（ 红色矩形）的 topLeading 位置，创建了一个黄色的圆形。

运行后，我们将获得如下的效果：

![https://cdn.fatbobman.com/geometryGroup-demo1_2023-11-27_08.17.48.2023-11-27%2008_18_55.gif](https://cdn.fatbobman.com/geometryGroup-demo1_2023-11-27_08.17.48.2023-11-27%2008_18_55.gif)

结果似乎是对的，又不完全正确。当 `toggle` 状态发生改变时，红色矩形按照预期以动画方式进行了缩放。黄色圆形最终也出现在红色矩形放大后的左上角位置。然而，这是否符合我们的预期效果呢？

我认为，对于许多开发者来说，他们更希望黄色的圆形能够像红色矩形一样，通过动画的方式从原始的 topLeading 位置移动到放大后的 topLeading 位置。

那么，geometryGroup() 能够帮助实现这个效果吗？

```swift
var body: some View {
    VStack {
        Button("Toggle") {
            toggle.toggle()
        }
        TopLeadingTest1(show: toggle)
            .geometryGroup()  // add geometryGroup between TopLeadingTest and frame
            .frame(width: size.width, height: size.height)
            .animation(.smooth(duration: 1), value: toggle)
    }
}
```

![https://cdn.fatbobman.com/geometryGroup-demo2_2023-11-27_08.25.22.2023-11-27%2008_29_25.gif](https://cdn.fatbobman.com/geometryGroup-demo2_2023-11-27_08.25.22.2023-11-27%2008_29_25.gif)

问题解决了。那么是什么导致了出现了非预期的结果，geometryGroup() 又是如何纠正了这一问题呢？

## 出现异常的原因

我们可以通过分析 `toggle` 状态发生改变后，每个视图的行为来查找原因。

- `toggle` 状态发生变化，由 false 变为 true。
- `.animation(.smooth(duration: 1), value: toggle)` 这行代码创建了一个包含本次状态变化对应动画信息（`.smooth(duration: 1)`）的 transaction，并将其沿着视图分支向下传播。
- `frame` 的设置进行了调整，尺寸从 200 x 200 变为 300 x 300。由于 transaction 包含了动画信息，因此这次改变是有动画效果的。
- `TopLeadingTest1` 根据从父视图 `frame` 接收到的建议尺寸变化，根据其默认布局形态（充满全部可用空间）改变了自身的大小。
- Shape（红色矩形）符合 Animatable 协议，在调整尺寸时，查看当前 transaction 并获取对应的动画信息（动画曲线函数），因此这次改变也是有动画效果的。
- 在 `overlay` 中，由于 `show` 的变化，将创建一个新的视图（`if show`）即黄色圆形。
- 当 SwiftUI 在 `overlay` 中布局黄色圆形时（`topLeading`），此时红色矩形的尺寸（尽管仍在以动画的形式逐渐扩大）已经是调整后的 300 x 300。
- SwiftUI 将黄色圆形放置在放大后的红色矩形的 `topLeading` 位置。
- 黄色圆形的默认过渡效果是 `opacity`，在创建黄色圆形时，SwiftUI 检查当前 transaction 并获取当前的动画信息。
- 黄色圆形以渐变的方式出现在 300 x 300 的 `topLeading` 位置。

上述每个过程的执行都严格且完美地遵循了 SwiftUI 的布局和动画规则。唯一让我们不满意的是，在创建黄色圆形时（布局它的位置时），它被放置在放大后的红色矩形的 `topLeading` 位置上。

这是因为在 SwiftUI 中，每个可动画视图根据 transaction 中的信息自行决定自身的动画行为。在创建黄色圆形时，它无法获得状态改变前的 `topLeading` 位置信息，因此无法满足我们的要求。

> 本节涉及到 transaction 以及 SwiftUI 动画的一些内部运行机制。您可以阅读 [掌握 Transaction，实现 SwiftUI 动画的精准控制](https://fatbobman.com/posts/mastering-transaction/) 和 [SwiftUI 的动画机制了解更多的内容](https://fatbobman.com/posts/the_animation_mechanism_of_swiftUI/)。
> 

## geometryGroup() 的作用

那么为什么添加了 geometryGroup() 后，问题就解决了呢？根据文档的描述：迫使位置和大小的值由父视图解析和动画化，然后再传递给每个子视图（ forcing the position and size values to be resolved and animated by the parent, before being passed down to each subview）。

以上面的示例来说，在添加了 geometryGroup() 后，父视图（ `frame` ）并不是一次性的将自身几何属性的改变状态传递给了子视图，而是将这些变化动画化了后，持续传递给子视图的。

当创建黄色圆形时，即使 `show` 状态已改变，父视图（`frame`）仍会持续传递其当前的几何信息（ 动画中）。这让黄色圆形能够获得正确的布局位置。因此，最终产生的结果就是，黄色圆形从我们预期的 200 x 200 的 `topLeading` 处，以动画的形式移动到了 300 x 300 的 `topLeading` 位置。

由此可见，geometryGroup() 中 Group 的含义为父视图统一处理并动画化其几何属性变化后，再传递给子视图。子视图不再各自独立处理上述信息。

## 出现 “Some Cases” 的条件

至此，我们就可以将官方文档中 “In some cases” 的条件补充完整：

- 父视图的几何属性发生改变，且改变是动画化的
- 在父视图改变的同时（ 几何属性的变化 ），子视图因此变化（ 几何信息或导致几何信息变化的状态变化）而创建了新的视图

换句话说，当子视图在父视图的几何属性发生变化时，如果子视图在自身中创建了新的视图，由于新视图无法获取到变化之前的几何信息，因此会导致布局出现意料之外的情况。

geometryGroup() 确保子视图在统一的几何信息环境中，以实现预期的布局效果。它为子视图提供了一个连续的几何信息更新过程。

总结上述条件后，我们就很容易创建出其它会导致意外行为的代码。

例如：

```swift
struct DynamicGridTest1: View {
    var body: some View {
        GeometryReader { proxy in
            let count = Int(proxy.size.width / 50)
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(0 ..< count, id: \.self) { _ in
                    GridRow {
                        ForEach(0 ..< count, id: \.self) { _ in
                            Rectangle()
                                .fill(.blue)
                                .border(.yellow, width: 2)
                                .frame(width: 50, height: 50)
                        }
                    }
                }
            }
        }
        .clipped()
    }
}

struct ContentView: View {
    @State var toggle = false
    var size: CGSize {
        toggle ? .init(width: 300, height: 300) : .init(width: 200, height: 200)
    }

    var body: some View {
        VStack {
            Button("Toggle") {
                toggle.toggle()
            }
            ZStack(alignment: .bottomTrailing) {
                Color.green.frame(width: 300, height: 300)
                DynamicGridTest1()
                    .frame(width: size.width, height: size.height)
                    .animation(.smooth(duration: 1), value: toggle)
            }
        }
    }
}
```

![https://cdn.fatbobman.com/geometryGroup-demo3_2023-11-27_09.48.31.2023-11-27%2009_49_04.gif](https://cdn.fatbobman.com/geometryGroup-demo3_2023-11-27_09.48.31.2023-11-27%2009_49_04.gif)

当 `frame` （父视图）的尺寸发生变化后，GeometryReader 所获得的尺寸也会相应地改变。新创建的 Grid 单元格会直接放置在尺寸变化后的位置。因此会导致出现非预期的结果。

在添加了 geometryGroup() 后。

```swift
DynamicGridTest1()
    .geometryGroup()
    .frame(width: size.width, height: size.height)
```

![https://cdn.fatbobman.com/geometryGroup-demo4_2023-11-27_09.52.07.2023-11-27%2009_53_12.gif](https://cdn.fatbobman.com/geometryGroup-demo4_2023-11-27_09.52.07.2023-11-27%2009_53_12.gif)

新创建的单元格将根据父视图持续传递进来的几何信息，获得正确的布局位置。

```responser
id:1
```

## 老版本 SwiftUI 该怎么办

只要我们能破坏 "Some Cases" 的构成条件，就能避免类似的非预期行为。

- 在父视图几何信息发生变化时，不要同时在子视图中创建新的内容
- 如果一定要在变化时为子视图增加新元素（ 比如上面基于 GeometryReader 的示例，可以将所需元素在父视图变化前便让其存在，通过透明度来调整其可见性 ）

例如，在较低版本的 SwiftUI 中，我们可以修改上面的示例一的代码，以避免出现非预期的行为：

```swift

struct TopLeadingTest2: View {
    let show: Bool
    var body: some View {
        Color.red
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(.yellow)
                    .frame(width: 20, height: 20)
                    .opacity(show ? 1 : 0)  // change visibilty by opacity
            }
    }
}
```

示例二修改起来稍微麻烦一些，但原理也是一样的：

```swift
struct DynamicGridTest2: View {
    private let max = 20
    var body: some View {
        Color.clear
            .overlay(alignment: .topLeading) {
                GeometryReader { proxy in
                    let count = Int(proxy.size.width / 50)
                    Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                        ForEach(0 ..< max, id: \.self) { r in
                            GridRow {
                                ForEach(0 ..< max, id: \.self) { c in
                                    Rectangle()
                                        .fill(.blue)
                                        .border(.yellow, width: 2)
                                        .frame(width: 50, height: 50)
                                        .opacity((r >= count || c >= count) ? 0 : 1)
                                }
                            }
                        }
                    }
                }
            }
            .clipped()
    }
}
```

### Update：transformEffect(.identity)

在 Reddit 上，[Ne1nLives 给我提供了一个新的解决方案](https://www.reddit.com/r/SwiftUI/comments/1870wct/comment/kbsn6x7/?utm_source=share&utm_medium=web2x&context=3)：在低版本的 SwiftUI 中，可以使用 `transformEffect(.identity)` 来实现与 `geometryGroup` 类似的效果。

```swift
DynamicGridTest1()
    .transformEffect(.identity) // keep the original geometry information
    .frame(width: size.width, height: size.height)
```

`transformEffect(.identity)` 实际上是对视图施加了一个“无变换”的变换。这样做不会改变视图的视觉表现，但可能会影响其在视图层级中的行为。

举个例子，在本文提供的示例代码中，当应用 `.transformEffect(.identity)` 时，其作用是让子视图的布局和位置在状态变化的第一时间保持不变。这相当于为新创建的视图（ 在状态变化时创建 ）提供了父视图的原始几何信息。由于子视图仍然会根据 transaction 中的信息进行动画，因此，我们会看到其呈现的效果与 `geometryGroup` 几乎一致。

虽然 `.transformEffect(.identity)` 可以在一些特定场景下模拟 `geometryGroup()` 的某些效果，但它不是一个全面的替代方案。

`geometryGroup` 的一个关键功能是创建一个边界，这个边界在父视图和子视图之间隔离了视图的几何属性，如位置和大小。这意味着，通过 `geometryGroup()`，子视图的布局和动画可以独立于父视图进行处理。

因此，`geometryGroup()` 适用于处理更复杂和特定的布局隔离和动画协调场景，而 `.transformEffect(.identity)` 更多是在特定情况下保持子视图布局稳定性的一种策略。

## 小插曲

在写这篇文章时，我创建了一个更加简单的代码，结果也出现了非预期的呈现。

```swift
struct TextTest1: View {
    let toggle: Bool
    var body: some View {
        Text(toggle ? "Hello" : "World")
    }
}

struct ContentView: View {
    @State var toggle = false
    var size: CGSize {
        toggle ? .init(width: 300, height: 300) : .init(width: 200, height: 200)
    }

    var body: some View {
        VStack {
            Button("Toggle") {
                toggle.toggle()
            }
            TextTest1(toggle: toggle)
                .frame(width: size.width, height: size.height)
                .animation(.smooth(duration: 1), value: toggle)
        }
    }
}
```

![https://cdn.fatbobman.com/geometryGroup-demo5_2023-11-27_10.10.26.2023-11-27%2010_11_10.gif](https://cdn.fatbobman.com/geometryGroup-demo5_2023-11-27_10.10.26.2023-11-27%2010_11_10.gif)

这个问题是从 iOS 16 开始出现的，而在更低版本中，文字的位置是正常的。从代码来看，`Text(toggle ? "Hello" : "World")` 应该能够保持一个视图标识的稳定（也就是不应该创建新的 Text）。然而，根据实际效果分析，很可能与 iOS 16 引入的 `contentTransition` 修饰器有关。在 SwiftUI 内部，将上述的三元运算符调整为类似以下代码的形式：

```swift
if toggle {
    Text("Hello")
} else {
    Text("World")
}
```

在 iOS 17 中，我们可以通过 geometryGroup() 来避免上述问题。对于 iOS 16，在文字变化较多且较大的情况下，应尽量避免在父视图几何信息调整时切换文字内容。

## 总结

在本文中，我们深入探讨了 SwiftUI 中 geometryGroup() 的重要性和实用性。通过实际的示例，我们看到了 geometryGroup() 在处理复杂的视图层级和同步动画时的强大功能。它不仅提供了对动画和布局的精细控制，而且确保了视图之间的一致性和流畅性。在实际开发中，尤其是面对复杂动画和布局的场景时，理解并正确使用 geometryGroup() 是至关重要的。

geometryGroup() 为我们提供了一个避免在个别情况下出现布局异常的能力。这是 SwiftUI 开发团队在完成了基本的布局功能后，腾出精力，进一步改善细节的一个表现。同时，我们也希望苹果能够在官方文档中能够提供更加清晰示例，以提高开发者学习新 API 的效率。
