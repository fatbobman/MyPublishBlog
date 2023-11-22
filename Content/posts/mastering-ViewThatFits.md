---
date: 2023-11-16 08:12
description: 在 iOS 16 中，SwiftUI 增加了一个新的自适应布局容器 ViewThatFits。正如其名称所示，它的作用是在给定的多个视图中找出最合适的视图并使用。对于大多数人来说，这是一个简单易用的容器。不过，本文打算对其进行彻底的剖析，包括规则细节、理想尺寸的含义、使用示例等。最后，我们将创建一个复刻版本的 ViewThatFits，以加深对其的认识和理解。
tags: SwiftUI
title: 掌握 ViewThatFits
image: images/mastering-viewThatFits.jpg
mediumURL: https://medium.com/p/3294d74cb17b
---
在 iOS 16 中，SwiftUI 增加了一个新的自适应布局容器 ViewThatFits。正如其名称所示，它的作用是在给定的多个视图中找出最合适的视图并使用。对于大多数人来说，这是一个简单易用的容器。不过，本文打算对其进行彻底的剖析，包括规则细节、理想尺寸的含义、使用示例等。最后，我们将创建一个复刻版本的 ViewThatFits，以加深对其的认识和理解。

## ViewThatFits 详解

### 定义

在 SwiftUI 的官方文档中，对 ViewThatFits 的定义如下：

> A view that adapts to the available space by providing the first child view that fits.
> 
> 一个能够适应可用空间的视图，它提供的是第一个能够适应的子视图
> 

```swift
public struct ViewThatFits<Content> : View where Content : View {
    public init(in axes: Axis.Set = [.horizontal, .vertical], @ViewBuilder content: () -> Content)
}
```

`ViewThatFits` evaluates its child views in the order you provide them to the initializer. **It selects the first child whose ideal size on the constrained axes fits within the proposed size**. This means that you provide views in order of preference. Usually this order is largest to smallest, but since a view might fit along one constrained axis but not the other, this isn’t always the case. By default, `ViewThatFits` constrains in both the horizontal and vertical axes.

ViewThatFits 按照你提供给初始化器的顺序评估其子视图。**它选择在受限轴上理想尺寸适应建议尺寸的第一个子视图**。这意味着你按照优先级顺序提供视图。通常这个顺序是从最大到最小，但由于一个视图可能在一个受限轴上适应但在另一个轴上不适应，所以这并不总是如此。默认情况下，ViewThatFits 在水平和垂直轴上都进行约束。

我知道，通过示例代码并观察其运行结果能让你对 ViewThatFits 获得更好的感性认识，但请不要着急，让我们首先对 ViewThatFits 的判断和呈现逻辑进行更多的剖析。

```responser
id:1
```

### ViewThatFits 的判断和呈现逻辑

既然 ViewThatFits 是从给定的视图中挑选出最合适的那个，那么它的判断依据是什么呢？判断的顺序如何？最终又如何呈现呢？

1. 首先，ViewThatFits 需要获取它所能使用的空间，也就是其父视图给出的建议尺寸。
2. 判断顺序根据 ViewBuilder 闭包中的顺序，从上至下逐个对子视图进行。
3. ViewThatFits 向子视图查询其理想尺寸（根据未指定建议尺寸返回的需求尺寸）。
4. 根据受限轴的设置，在选择的受限轴上，比较子视图的理想尺寸和 ViewThatFits 的父视图给出的建议尺寸。
5. 如果在所有设置的受限轴上，理想尺寸都小于等于建议尺寸，那么选择该子视图，并停止对后续子视图进行判断。
6. 如果所有的子视图都不满足条件，则选择闭包中的最后一个子视图。
7. ViewThatFits 将父视图给出的建议尺寸作为自己的建议尺寸传递给选择的子视图，并获得该子视图在明确建议尺寸下的需求尺寸。
8. ViewThatFits 将上一步获得的需求尺寸作为自己的需求尺寸返回给父视图。

一个 ViewThatFits 最终会选择那个子视图，取决于以下几个因素：

- ViewThatFits 可用的空间（它的父视图给它的建议尺寸）
- ViewThatFits 设定的受限轴
- 子视图的在受限轴上的理想尺寸
- 子视图的排列顺序

任何一个因素发生变化，最终呈现的结果都可能会不同。

比如，对于下面的代码，用更符合开发者主观目标的语言来描述就是：

```swift
ViewThatFits(in: .horizontal) {
    Text("Hello Beautiful World")
    Text("Hello World")
    Text("Hi")
}
```

ViewThatFits 会选择闭包中首个在其给定的宽度内用不折行的方式完整显示的 Text 视图。

因此，当我们将上述代码放置在不同的上下文中时，它最终呈现的子视图（选择的子视图）可能会有所不同。

```swift
ViewThatFits(in: .horizontal) {
    Text("Hello Beautiful World") // 100 < width < 200
    Text("Hello World") //  20 < width < 100
    Text("Hi") // 10 < width < 20
}
.border(.blue) // required size of ViewThatFits
.frame(width:100)
.border(.red) // proposed size from parent View
```

![https://cdn.fatbobman.com/image-20231104213915624.png](https://cdn.fatbobman.com/image-20231104213915624.png)

在宽度只有 100 的情况下，最终显示的是 `Text("Hello World")`。当宽度调整为 200 时，它将显示为 `Text("Hello Beautiful World")`。

![https://cdn.fatbobman.com/image-20231104214010204.png](https://cdn.fatbobman.com/image-20231104214010204.png)

让我们增加一点难度，使用 `.frame(width:10)` 将 ViewThatFits 的可用尺寸（父视图给它的建议尺寸）设置为 10。根据代码中注释标注的不同 Text 的宽度，最终的呈现会是什么样子呢？

```swift
ViewThatFits(in: .horizontal) {
    Text("Hello Beautiful World") // 100 < width < 200
    Text("Hello World") //  20 < width < 100
    Text("Hi") // 10 < width < 20
}
.border(.blue) // required size of ViewThatFits
.frame(width:10)
.border(.red) // proposed size from parent View
```

![https://cdn.fatbobman.com/image-20231104215314315.png](https://cdn.fatbobman.com/image-20231104215314315.png)

我们最初的意图是选择一个适合给定尺寸并且不会自动换行的文本。为什么最后会变成这个样子呢？

首先，ViewThatFits 经过逐个比对，发现闭包中没有任何一个 Text 的理想尺寸宽度不大于 10 ，因此它选择了最后一个 `Text("Hi")` 。此时 `Text("Hi")` 只获得了宽度为 10 的建议尺寸。根据 Text 的默认显示规则（显示不下就折行），它用了两行才能将 `Hi` 全部显示完。

由此可以看出，ViewThatFits 本身在最终呈现时，并不对子视图施加理想尺寸的限制。它只在检查阶段使用子视图的理想尺寸进行判断，在最终呈现阶段，它将向子视图提交有值的建议尺寸，并使用子视图的需求尺寸作为自身的需求尺寸。

为了应对这种极端情况（文字折行），我们需要对子视图进行特别的设定，例如通过 `fixedSize` 强制展示完整内容（最终的显示尺寸可能会超过父视图给出的建议尺寸）：

```swift
Text("Hi")
    .fixedSize(horizontal: true, vertical: false)
```

![https://cdn.fatbobman.com/image-20231104221054205.png](https://cdn.fatbobman.com/image-20231104221054205.png)

或者可以使用 `lineLimit` 来限制其在垂直方向上只能使用 1 行的空间，但无法保证完全显示全部内容：

```swift
Text("Hi")
    .lineLimit(1)
```

![https://cdn.fatbobman.com/image-20231104221034986.png](https://cdn.fatbobman.com/image-20231104221034986.png)

好吧，我承认，我是故意将问题复杂化的。要真正正确地使用 ViewThatFits，我们必须充分了解它的判断、呈现逻辑，并且掌握“理想尺寸”的概念。否则，很可能会面对与预期不一致的情况。

### 理想尺寸（ Ideal Size ）

在 SwiftUI 中，相较于建议尺寸，很多开发者对理想尺寸接触的较少，理解的也不太深入。

就布局而言，"理想尺寸"指的是当父视图以未指定的模式提供建议尺寸时，视图返回的需求尺寸。

用更容易理解的语言来说，理想尺寸就是一个视图在不给其任何尺寸限定（理想的外部环境）的情况下，其最理想的呈现结果所占用的尺寸。

**对于不同种类的视图，它们的理想呈现处理规则是不同的**。

例如：

- Rectangle：在理想状态的轴上只使用 10（所有 Shape 都遵循该规则）。
- Text：在理想状态的轴上占用尽可能多的空间，展示全部文本（不进行任何截取）。
- ScrollView：如果理想状态的轴与滚动方向一致，则在滚动方向上一次性展示所有的子视图而无视父视图的建议尺寸。
- VStack、HStack、ZStack：所有子视图在理想状态下的整体呈现。

在 SwiftUI 中，我们可以通过 `fixedSize` 来强制一个视图以理想尺寸进行呈现：

```swift
struct IdealSizeDemo: View {
    var body: some View {
        VStack {
            Text("GeometryReader has been present since the birth of SwiftUI, playing a crucial role in many scenarios.")
                .fixedSize()
            Rectangle().fill(.orange)
                .fixedSize()
            Circle().fill(.red)
                .fixedSize()
            ScrollView(.horizontal) {
                HStack {
                    ForEach(0 ..< 50) { i in
                        Rectangle().fill(.blue).frame(width: 30, height: 30)
                            .overlay(Text("\(i)").foregroundStyle(.white))
                    }
                }
            }
            .fixedSize()
            VStack {
                Text("GeometryReader has been present since the birth of SwiftUI, playing a crucial role in many scenarios.")
                Rectangle().fill(.yellow)
            }
            .fixedSize()
        }
    }
}
```

![https://cdn.fatbobman.com/image-20231105155129190.png](https://cdn.fatbobman.com/image-20231105155129190.png)

从截图中可以看出，Text、Shape 和 ScrollView 的“理想呈现”都比较容易预测，与我们上面的描述一致。唯一有些奇怪的是 VStack：

```swift
VStack {
    Text("GeometryReader has been present since the birth of SwiftUI, playing a crucial role in many scenarios.")
    Rectangle().fill(.yellow)
}
.fixedSize()
```

对于这种视图，其“理想呈现”是一个复合的状态：

- 宽度：VStack 将逐个询问子视图的理想尺寸，使用其中宽度的最大值作为它的需求尺寸，并在最终布局时（placeSubviews）将其作为建议尺寸传递给子视图。
- 高度：VStack 将所有子视图的理想尺寸高度和 Spacing 的和作为自己的需求尺寸。

SwiftUI 提供了两个版本的 `fixedSize` ，我们当前使用的版本要求视图在水平和垂直两个轴向上都使用理想尺寸，而另一个版本允许我们对单个轴向进行限定。

```swift
struct IdealSizeDemo2: View {
    var body: some View {
        Text("GeometryReader has been present since the birth of SwiftUI, playing a crucial role in many scenarios.")
            .fixedSize(horizontal: false, vertical: true)
            .border(.red, width: 2)
            .frame(width: 100, height: 100)
            .border(.blue, width: 2)
    }
}
```

`fixedSize(horizontal: false, vertical: true)` 表示，我们要求 Text 在 vatical 轴向上呈现理想状态，在 horizontal 轴向上继续使用具有明确数值的建议尺寸宽度（ 100 ）。用易懂的描述就是，在有明确宽度限定的情况下，要求 Text 显示全部的文本内容。

![https://cdn.fatbobman.com/image-20231105160806434.png](https://cdn.fatbobman.com/image-20231105160806434.png)

从上图中可以看出，由于 `fixedSize` 的存在，Text 忽略了其父视图给出的 100 x 100 的建议尺寸高度，充分利用了垂直方向上的空间，将完整的文本内容呈现出来。

这种对理想尺寸在单个轴向上的限制与 ViewThatFits 构造方法中的受限轴设置完全对应。通过设置，我们可以让 ViewThatFits 只在特定轴向上对子视图的理想尺寸进行判断。

```swift
struct IdealSizeDemo3: View {
    var body: some View {
        HStack {
            // ViewThatFits result
            ViewThatFits(in: .vertical) {
                Text("1: GeometryReader has been present since the birth of SwiftUI, playing a crucial role in many scenarios.")
                Text("2: In addition, some views believe that:")
            }
            .border(.blue)
            .frame(width: 200, height: 100, alignment: .top)
            .border(.red)

            // Text1's ideal size ,only vetical fixed
            Text("1: GeometryReader has been present since the birth of SwiftUI, playing a crucial role in many scenarios.")
                .fixedSize(horizontal: false, vertical: true)
                .border(.blue)
                .frame(width: 200, height: 100, alignment: .top)
                .border(.red)

            // Text2's ideal size ,only vetical fixed
            Text("2: In addition, some views believe that:")
                .fixedSize(horizontal: false, vertical: true)
                .border(.blue)
                .frame(width: 200, height: 100, alignment: .top)
                .border(.red)
        }
    }
}
```

上面这段代码清晰地展示了 ViewThatFits 选择第二个 Text 的判断依据。当 Text1 在垂直轴上被单独限定为理想尺寸时，它的高度超过了 ViewThatFits 可提供的高度 100（蓝色边框高度大于红色边框）。而 Text2 的高度符合 ViewThatFits 的要求。

![https://cdn.fatbobman.com/image-20231105162429959.png](https://cdn.fatbobman.com/image-20231105162429959.png)

实际上，即使 Text2 的理想高度大于 ViewThatFits 提供的高度，根据 ViewThatFits 的判断规则，在所有子视图都不满足条件的情况下，它也会默认选择最后一个子视图（Text2）。不过，最终的呈现会是怎样的呢？

```swift
ViewThatFits(in: .vertical) {
    Text("1: GeometryReader has been present since the birth of SwiftUI, playing a crucial role in many scenarios.")
    Text("2: In addition, some views believe that:")
}
.border(.blue)
.frame(width: 200, height: 30, alignment: .top)
.border(.red)
```

![https://cdn.fatbobman.com/image-20231105162904137.png](https://cdn.fatbobman.com/image-20231105162904137.png)

开发者必须清楚，ViewThatFits 是基于理想尺寸来进行判断，但在最终呈现时，被选择的子视图并不是按照理想状态来呈现的。由于 ViewThatFits 能够提供的高度只有 30，在 Text2 最终呈现时，它将根据其默认显示规则对文字进行截断处理。

在 SwiftUI 中，我们可以通过 `frame` 来修改视图在理想状态下的呈现。

```swift
struct SetIdealSize: View {
    @State var useIdealSize = false
    var body: some View {
        VStack {
            Button("Use Ideal Size") {
                useIdealSize.toggle()
            }
            .buttonStyle(.bordered)

            Rectangle()
                .fill(.orange)
                .frame(width: 100, height: 100)
                .fixedSize(horizontal: useIdealSize ? true : false, vertical: useIdealSize ? true : false)

            Rectangle()
                .fill(.cyan)
                .frame(idealWidth: 100, idealHeight: 100)
                .fixedSize(horizontal: useIdealSize ? true : false, vertical: useIdealSize ? true : false)

            Rectangle()
                .fill(.green)
                .fixedSize(horizontal: useIdealSize ? true : false, vertical: useIdealSize ? true : false)
        }
        .animation(.easeInOut, value: useIdealSize)
    }
}
```

`.frame(width: 100, height: 100)` 与 `.frame(idealWidth: 100, idealHeight: 100)` 之间的不同在于前者在任何场景下（理想状态或非理想状态）均被视为视图的需求尺寸，后者仅在理想状态下作为需求尺寸。

![https://cdn.fatbobman.com/set-ideal-size-demo_2023-11-05_16.49.08.2023-11-05%2016_50_09.gif](https://cdn.fatbobman.com/set-ideal-size-demo_2023-11-05_16.49.08.2023-11-05%2016_50_09.gif)

> 如果你想进一步了解更多有关理想尺寸和建议尺寸的内容，请阅读 [SwiftUI 布局 —— 尺寸（ 上 ）](https://www.fatbobman.com/posts/layout-dimensions-1/) 一文。
> 

```responser
id:1
```

## 示例

所有的理论知识都是为实际应用而服务的。在本节中，我们将通过几个示例来展示 ViewThatFits 的功能。

### 自适应滚动

通过下面的代码，我们可以实现在内容宽度超过给定宽度时，自动进入可滚动状态。

```swift
struct ScrollViewDemo: View {
    @State var step: CGFloat = 3
    var count: Int {
        Int(step)
    }

    var body: some View {
        VStack(alignment:.leading) {
            Text("Count: \(count)")
            Slider(value: $step, in: 3 ... 20, step: 1)

            ViewThatFits {
                content
                ScrollView(.horizontal,showsIndicators: true) {
                    content
                }
            }
        }
        .frame(width: 300)
        .border(.red)
    }

    var content: some View {
        HStack {
            ForEach(0 ..< count, id: \.self) { i in
                Rectangle()
                    .fill(.orange.gradient)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(i, format: .number).foregroundStyle(.white)
                    )
            }
        }
    }
}
```

![https://cdn.fatbobman.com/viewThatFits-scrollView-demo_2023-11-05_17.06.10.2023-11-05%2017_08_32.gif](https://cdn.fatbobman.com/viewThatFits-scrollView-demo_2023-11-05_17.06.10.2023-11-05%2017_08_32.gif)

如果 `content` 的宽度超过了 ViewThatFits 允许的宽度（300），则 ViewThatFits 会选择最后一个使用 ScrollView 的子视图。在这个示例中，尽管 ScrollView 在理想状态下，呈现的宽度也超过了 ViewThatFits 允许的宽度，但由于它是最后一个子视图，因此最终选择了它。这也是一个典型的判断和呈现不一致的情况。

### 选择合适长度的文本

这也是 ViewThatFits 最常被使用的场景，从提供的一组文本中，找出最适合当前空间的那个。

```swift
struct TextDemo: View {
    @State var width: CGFloat = 100
    var body: some View {
        VStack {
            Slider(value: $width, in: 30 ... 300)
                .padding()
            ViewThatFits {
                Text("Fatbobman's Swift Weekly")
                Text("Fatbobman's Weekly")
                Text("Fat's Weekly")
                Text("Weekly")
                    .fixedSize()
            }
            .frame(width: width)
            .border(.red)
        }
    }
}
```

![https://cdn.fatbobman.com/viewThatFits-Text-Demo_2023-11-05_17.26.17.2023-11-05%2017_27_16.gif](https://cdn.fatbobman.com/viewThatFits-Text-Demo_2023-11-05_17.26.17.2023-11-05%2017_27_16.gif)

为了确保即使在空间有限的情况下，仍然可以完整显示文本，我们对最后一个 Text 使用了 `fixedSize`。

有些开发者可能会使用以下代码（相同的内容，不同的字体尺寸），为 ViewThatFits 提供不同尺寸的子视图：

```swift
ViewThatFits {
    Text("Fatbobman's Swift Weekly")
        .font(.body)
    Text("Fatbobman's Swift Weekly")
        .font(.subheadline)
    Text("Fatbobman's Swift Weekly")
        .font(.footnote)
}
```

![https://cdn.fatbobman.com/viewThatFits-Text-demo2_2023-11-05_17.38.52.2023-11-05%2017_39_20.gif](https://cdn.fatbobman.com/viewThatFits-Text-demo2_2023-11-05_17.38.52.2023-11-05%2017_39_20.gif)

然后，对于内容相同但尺寸不同的需求，ViewThatFits 可能并不是最优解决方案。下面的代码可以带来更好的效果：

```swift
Text("Fatbobman's Swift Weekly")
    .lineLimit(1)
    .font(.body)
    .minimumScaleFactor(0.3)
    .frame(width: width)
    .border(.red)
```

![https://cdn.fatbobman.com/viewThatFits-Text-demo3-minimumScaleFactor_2023-11-05_17.55.33.2023-11-05%2017_56_16.gif](https://cdn.fatbobman.com/viewThatFits-Text-demo3-minimumScaleFactor_2023-11-05_17.55.33.2023-11-05%2017_56_16.gif)

ViewThatFits 更擅长为不同的空间提供不同的备选内容。

### 自适应横竖布局

在给定的空间中，自动选择适合的布局方式：

```swift
var logo: some View {
    Rectangle()
        .fill(.orange)
        .frame(idealWidth: 100, maxWidth: 200, idealHeight: 100)
        .overlay(
            Image(systemName: "heart.fill")
                .font(.title)
                .foregroundStyle(.white)
        )
}

var title: some View {
    Text("Hello World")
        .fixedSize()
        .font(.headline).bold()
        .frame(maxWidth: 120)
}

struct LayoutSwitchDemo: View {
    @State var width: CGFloat = 100
    var body: some View {
        VStack {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    logo
                    title
                }
                VStack(spacing: 0) {
                    logo
                    title
                }
            }
            .frame(maxWidth: width, maxHeight: 130)
            .border(.blue)

            Spacer()
            Slider(value: $width, in: 90 ... 250).padding(50)
        }
    }
}
```

![https://cdn.fatbobman.com/viewThatFits-layout-switch-demo1_2023-11-05_18.51.22.2023-11-05%2018_52_23.gif](https://cdn.fatbobman.com/viewThatFits-layout-switch-demo1_2023-11-05_18.51.22.2023-11-05%2018_52_23.gif)

在这个示例中，我们利用了 ViewThatFits 的特性，在判断子视图和最终呈现时采用不同的建议尺寸模式，以确保最终呈现的子视图始终能够充满 ViewThatFits 视图。对于 logo 和 title，我们没有给出明确的尺寸。通过为 Rectangle 设置理想尺寸，供 ViewThatFits 用来选择合适的子视图。选定了子视图后，子视图中的 logo 会根据 ViewThatFits 提供的尺寸，在最终的呈现时调整自己的尺寸。

## 创建 ViewThatFits 的复刻版本

在学习 SwiftUI 的过程中，我经常尝试复刻一些布局容器和修饰符。通过这个过程，除了验证我的一些猜想外，还能更深入地理解和掌握它们。在本节中，我们将创建一个符合 Layout 协议的布局容器，来实现对 ViewThatFits 的复刻。

我们已经在第一个章节中详细阐述了 ViewThatFits 的实现细节（判断规则、呈现逻辑），因此使用 Layout 协议来实现非常方便。

```swift
struct _MyViewThatFitsLayout: Layout {
    let axis: Axis.Set
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Int?) -> CGSize {
        // 没有子视图，返回 zero
        guard !subviews.isEmpty else { return .zero }
        // 一个子视图，返回该子视图的需求尺寸
        guard subviews.count > 1 else {
            cache = subviews.endIndex - 1
            return subviews[subviews.endIndex - 1].sizeThatFits(proposal)
        }
        // 从第一个到倒数第二个子视图逐个在限定的轴向上获取其理想尺寸进行判断
        for i in 0..<subviews.count - 1 {
            let size = subviews[i].dimensions(in: .unspecified)
            switch axis {
            case [.horizontal, .vertical]:
                if size.width <= proposal.replacingUnspecifiedDimensions().width && size.height <= proposal.replacingUnspecifiedDimensions().height {
                    cache = i
                    // 满足判断条件，返回该子视图的需求尺寸（ 用正常的建议尺寸询问 ）
                    return subviews[i].sizeThatFits(proposal)
                }
            case .horizontal:
                if size.width <= proposal.replacingUnspecifiedDimensions().width {
                    cache = i
                    return subviews[i].sizeThatFits(proposal)
                }
            case .vertical:
                if size.height <= proposal.replacingUnspecifiedDimensions().height {
                    cache = i
                    return subviews[i].sizeThatFits(proposal)
                }
            default:
                break
            }
        }
        // 上述都不满足，则使用最后一个子视图
        cache = subviews.endIndex - 1
        return subviews[subviews.endIndex - 1].sizeThatFits(proposal)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Int?) {
        for i in subviews.indices {
            if let cache, i == cache {
                subviews[i].place(at: bounds.origin, anchor: .topLeading, proposal: proposal)
            } else {
                // 将不需要显示的子视图，放置在一个无法显示的位置
                subviews[i].place(at: .init(x: 100_000, y: 100_000), anchor: .topLeading, proposal: .zero)
            }
        }
    }

    func makeCache(subviews _: Subviews) -> Int? {
        nil
    }
}

public struct MyViewThatFitsByLayout<Content>: View where Content: View {
    let axis: Axis.Set
    let content: Content

    public init(axis: Axis.Set = [.horizontal, .vertical], @ViewBuilder content: @escaping () -> Content) {
        self.axis = axis
        self.content = content()
    }

    public var body: some View {
        _MyViewThatFitsLayout(axis: axis) {
            content
        }
    }
}
```

经过检验，我们的复刻版本与 ViewThatFits 的效果完全一致。

![https://cdn.fatbobman.com/MyViewThatFitsByLayoutDemo_2023-11-05_19.25.40.2023-11-05%2019_26_32.gif](https://cdn.fatbobman.com/MyViewThatFitsByLayoutDemo_2023-11-05_19.25.40.2023-11-05%2019_26_32.gif)

> 你可以在 [此处](https://github.com/fatbobman/BlogCodes/tree/main/ViewThatFits) 获取本文的全部代码。
> 

```responser
id:1
```

## 总结

正如我们所看到的，ViewThatFits 是 SwiftUI 工具箱中的一个强大而灵活的组件，它可以帮助开发者优雅地解决多种布局挑战，提升应用程序的用户体验和界面适应性。但是，与任何强大的工具一样，能否发挥期作用来自于深入理解其使用方式和限制。

在本文中，我们对 SwiftUI 中的 ViewThatFits 容器进行了深入的探索。从基本定义到复杂的布局机制，我们试图揭示这个强大工具背后的逻辑和潜力。通过对理想尺寸和布局适应性的详细分析，我们展示了 ViewThatFits 如何在多样化的应用场景中发挥作用。

尽管 ViewThatFits 在处理多种视图和布局挑战方面非常有用，但它并不是万能的。在某些复杂的布局需求下，开发者可能需要更精细的控制或采用其他布局策略。因此，理解它的内部工作原理和限制是至关重要的，这样开发者才能充分利用它的优势，同时避免潜在的布局问题。

希望这篇文章能为你在使用 SwiftUI 进行布局设计时提供有价值的见解。