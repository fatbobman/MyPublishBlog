---
date: 2023-11-09 08:20
description: GeometryReader 自 SwiftUI 诞生之初就存在，它在许多场景中扮演着重要的角色。然而，从一开始就有开发者对其持负面态度，认为应尽量避免使用。特别是在最近几次 SwiftUI 更新中新增了一些可以替代 GeometryReader 的 API 后，这种观点进一步加强。本文将对 GeometryReader 的“常见问题”进行剖析，看看它是否真的如此不堪，以及那些被批评为“不符预期”的表现，是否其实是因为开发者的“预期”本身存在问题。
tags: SwiftUI
title: GeometryReader ：好东西还是坏东西？
image: images/from-Data-Model-Construction-to-Managed-Object-Instances-in-Core-Data.jpg
---
GeometryReader 自 SwiftUI 诞生之初就存在，它在许多场景中扮演着重要的角色。然而，从一开始就有开发者对其持负面态度，认为应尽量避免使用。特别是在最近几次 SwiftUI 更新中新增了一些可以替代 GeometryReader 的 API 后，这种观点进一步加强。本文将对 GeometryReader 的“常见问题”进行剖析，看看它是否真的如此不堪，以及那些被批评为“不符预期”的表现，是否其实是因为开发者的“预期”本身存在问题。

## 对 GeometryReader 的一些批评

开发者对 GeometryReader 的批评主要集中在以下两个观点：

- GeometryReader 会破坏布局：这种观点认为，由于 GeometryReader 会占用全部可用空间，因此可能会破坏整体的布局设计。
- GeometryReader 无法获取正确的几何信息：这种观点认为，在某些情况下，GeometryReader 无法获取精确的几何信息，或者在视图未发生变化（视觉上）的情况下，其获取的信息可能不稳定。

此外，有些观点认为：

- 过度依赖 GeometryReader 会导致视图布局变得僵化，失去了 SwiftUI 的灵活性优势。
- GeometryReader 打破了 SwiftUI 声明式编程的理念，使得需要直接操作视图框架，更接近命令式编程。
- GeometryReader 更新几何信息时资源消耗较大，可能会引发不必要的重复计算和视图重建。
- 使用 GeometryReader 需要编写大量的辅助代码来计算和调整框架，这会增加编码量，降低代码的可读性和可维护性。

这些批评并非全无道理，其中相当一部分已经通过新的 API 在 SwiftUI 版本更新后得到了改善或解决。然而，关于 GeometryReader 破坏布局、无法获取正确信息的观点，通常是由于开发者对 GeometryReader 的理解不足和使用不当引起的。接下来，我们将针对这些观点进行分析和探讨。

> 在本文发表之前，我发起了一个 [投票](https://twitter.com/fatbobman/status/1719926573896544593) 询问大家对 GeometryReader 的看法，从结果来看，对其持负面印象的比例较高。

![image-20231104120125753](https://cdn.fatbobman.com/image-20231104120125753.png)

```responser
id:1
```

## GeometryReader 是什么

在我们深入探讨上述负面观点之前，我们首先需要理解 GeometryReader 的功能以及设计这个 API 的原因。

这是苹果官方文档对于 GeometryReader 的定义：

> A container view that defines its content as a function of its own size and coordinate space.
> 
> 一个容器视图，根据其自身大小和坐标空间定义其内容。
> 

严格来讲，我并不完全赞同上述描述。这并非因为存在事实上的错误，而是这种表述可能会引起用户的误解。实际上，"GeometryReader" 这个名字更符合其设计目标：**一个几何信息读取器**。

确切来说，GeometryReader 的作用主要是获取父视图的大小、frame 等几何信息。官方文档中的“定义其内容（ defines its content ）”这一表述容易让人误以为 GeometryReader 的主要功能是主动影响子视图，或者说其获取的几何信息主要用于子视图，但实际上，它更应被视为一个获取几何信息的工具。这些信息是否应用到子视图完全取决于开发者。

如果一开始就把它设计成下面这样的方式，也许就能避免对它的误解和滥用。

```swift
@State private proxy:GeometryProxy

Text("Hello world")
    .geometryReaer(proxy:$proxy)
```

如果改为基于 View Extension 的方式，我们可以将 geometryReader 的作用描述为：它提供了其所应用的视图的大小、frame 等几何信息，是视图获取**自身**几何信息的有效手段。这种描述可以有效地避免几何信息主要应用于子视图的误解。

对于为什么不采用 Extension 的方式，设计者可能考虑了以下两个因素：

- 通过 Binding 的方式向上传递信息，并不是当前官方 SwiftUI API 的主要设计方式。
- 将几何信息传递到上层视图，可能会引起不必要的视图更新。而向下传递信息，可以确保更新只在 GeometryReader 的闭包中进行。

## GeometryReader 是布局容器吗，它的布局逻辑是什么？

是，但是其行为有些与众不同。

当前，GeometryReader 以一个布局容器的形式存在，其布局规则如下：

- 它是一个多视图容器，其默认堆叠规则类似于 ZStack
- 将父视图的建议尺寸（ Proposed size ）作为自身的需求尺寸（ Required Size ）返回给父视图
- 将父视图的建议尺寸作为自身的建议尺寸传递给子视图
- 将子视图的原点（0,0）置于 GeometryReader 的原点位置
- 其理想尺寸（ Ideal Size）为 (10,10)

如果不考虑获取几何信息的功能，一个 GeometryReader 的布局行为与以下的代码很接近。

```swift
GeometryReader { _ in
  Rectangle().frame(width:50, height:50)
  Text("abc").foregroundStyle(.white)
}
```

大致等于：

```swift
ZStack(alignment: .topLeading) {
    Rectangle().frame(width: 50, height: 50)
    Text("abc").foregroundStyle(.white)
}
.frame(
    idealWidth: 10,
    maxWidth: .infinity,
    idealHeight: 10,
    maxHeight: .infinity,
    alignment: .topLeading
)
```

简单来说，GeometryReader 会占用父视图提供的所有空间，并将所有子视图的原点与容器的原点对齐（即放置在左上角）。这种非常规的布局逻辑是我不推荐将其直接用作布局容器的原因之一。

> GeometryReader 不支持对齐指南的调整，因此上面的描述使用了原点。
> 

然而，这并不意味着不能将 GeometryReader 作为视图容器使用。在某些情况下，它可能比其他容器更适合。例如：

```swift
struct PathView: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height

                path.move(to: CGPoint(x: width / 2, y: 0))
                path.addLine(to: CGPoint(x: width, y: height))
                path.addLine(to: CGPoint(x: 0, y: height))
                path.closeSubpath()
            }
            .fill(.orange)
        }
    }
}
```

在绘制 Path 时，GeometryReader 提供的信息（尺寸，原点）正好满足我们的需求。因此，对于需要充满空间且采用原点对齐方式的子视图，GeometryReader 作为布局容器非常合适。

GeometryReader 将完全无视子视图提出的需求尺寸，在这一点上，它的处理方式与 overlay 和 background 对待子视图的方式一致。

在上面对 GeometryReader 的布局规则描述中，我们指出了它的 ideal size 是（10,10 ）。或许有些读者不太了解其含义，ideal size 是指当父视图给出的建议尺寸为 nil 时（未指定模式），子视图返回的需求尺寸。如果对 GeometryReader 的这个设定不了解，可能会在某些场景下，开发者会感觉 GeometryReader 并没有如预期那样充满所有空间。

例如，执行以下代码，你只能得到一个高度为 10 的矩形：

```swift
struct GeometryReaderInScrollView: View {
    var body: some View {
        ScrollView {
            GeometryReader { _ in
                Rectangle().foregroundStyle(.orange)
            }
        }
    }
}
```

![https://cdn.fatbobman.com/image-20231030192917562.png](https://cdn.fatbobman.com/image-20231030192917562.png)

这是因为 ScrollView 在向子视图提交建议尺寸时，其处理逻辑与大多数布局容器不同。在非滚动方向上，ScrollView 会向子视图提供该维度上的全部可用尺寸。而在滚动方向上，它向子视图提供的建议尺寸为 nil。由于 GeometryReader 的 ideal size 为 (10,10)，因此，在滚动方向上，其返回给 ScrollView 的需求尺寸即为 10。在这点上，GeometryReader 的行为与 Rectangle 一致。因此，可能会有开发者认为 GeometryReader 并没有按照预期充满全部的可用空间。但实际上，它的显示结果是完全正确的，这就是正确的布局结果。

因此，在这种情况下，通常我们只会使用拥有明确值维度的尺寸（ 建议尺寸有值 ），并以此为来计算另一维度的尺寸。

例如，如果我们想在 ScrollView 中以 16:9 的比例显示图片（即使图片自身的比例与此不符）：

```swift
struct GeometryReaderInScrollView: View {
    var body: some View {
        ScrollView {
            ImageContainer(imageName: "pic")
        }
    }
}

struct ImageContainer: View {
    let imageName: String
    @State private var width: CGFloat = .zero
    var body: some View {
        GeometryReader { proxy in
            Image("pic")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .onAppear {
                    width = proxy.size.width
                }
        }
        .frame(height: width / 1.77)
        .clipped()
    }
}
```

![https://cdn.fatbobman.com/image-20231030200535483.png](https://cdn.fatbobman.com/image-20231030200535483.png)

首先，我们使用 GeometryReader 获取 ScrollView 提供的建议宽度，并根据这个宽度计算出所需的高度。然后，通过 `frame` 调整 GeometryReader 向 ScrollView 提交的需求尺寸高度。这样，我们就能得到期望的显示结果。

在这个演示中，Image 正好满足了之前提出的充满空间且原点对齐的要求，因此直接使用 GeometryReader 作为布局容器是完全没有问题的。

> 本章节包含了许多关于 SwiftUI 的尺寸和布局的知识。如果你对此还不太了解，建议你继续阅读以下文章：[SwiftUI 布局 —— 尺寸（上）](https://www.fatbobman.com/posts/layout-dimensions-1/)、[SwiftUI 布局 —— 尺寸（下）](https://www.fatbobman.com/posts/layout-dimensions-2/)、[SwiftUI 布局 —— 对齐](https://www.fatbobman.com/posts/layout-alignment/)。
> 

## 为什么 GeometryReader 无法获取正确的信息

一些开发者可能会抱怨，GeometryReader 无法获取正确的尺寸（总是返回 0,0），或者返回异常的尺寸（比如负数），导致布局错误。

为此，我们首先需要理解 SwiftUI 的布局原理。

SwiftUI 的布局是一个协商过程。父视图向子视图提供建议尺寸，子视图返回需求尺寸。父视图是否根据子视图的需求尺寸来放置子视图，以及子视图是否根据父视图给出的建议尺寸来返回需求尺寸，完全取决于父视图和子视图的预设规则。比如，对于 VStack ，它会在垂直维度上，分别向子视图发送具有明确值的建议尺寸、未指定的建议尺寸、最大建议尺寸以及最小建议尺寸的信息，并获得子视图在不同建议尺寸下的需求尺寸。VStack 会结合视图的优先级，它的父视图给其的建议尺寸，在摆放时对子视图提出最终的建议尺寸。

在一些复杂的布局场景中，或者在某些设备或系统版本中，布局可能需要经过几轮的协商才能获得最终稳定的结果，尤其是当视图需要依赖 GeometryReader 提供的几何信息来重新确定自己的位置和尺寸时。因此，这可能导致 GeometryReader 在获得稳定结果之前，不断向子视图发送新的几何信息。如果我们仍然使用上文代码中的信息获取方式，那么就无法获得变更后的信息：

```swift
.onAppear {
    width = proxy.size.width
}
```

因此，正确的获取信息的方式为：

```swift
.task(id: proxy.size.width) {
    width = proxy.size.width
}
```

这样，即使数据发生变化，我们也能持续更新数据。一些开发者表示，在屏幕方向发生变化时，无法获取新的信息，原因也是如此。`task(id:)` 同时涵盖了 `onAppear` 和 `onChange` 的场景，是最可靠的数据获取方式。

另外，在某些情况下，GeometryReader 有可能返回尺寸为负数的数据。如果直接将这些负数数据传递给 `frame`，就可能会出现布局异常（在调试状态下，Xcode 会用紫色的提示警告开发者）。因此，为了进一步避免这种极端情况，可以在传递数据时，将不符合要求的数据过滤掉。

```swift
.task(id: proxy.size.width) {
    width = max(proxy.size.width, 0)
}
```

由于 GeometryProxy 并不符合 Equatable 协议，同时也为了尽可能的减少因信息更新而导致的视图重新评估，开发者应该只传递当前需要的信息。

至于如何传递获取的几何信息（例如上文中使用的 @State 或是通过 PreferenceKey），则取决于开发者的编程习惯和场景需求。

通常，我们会在 `overlay` 或 `background` 中使用 GeometryReader + Color.clear 来获取并传递几何信息。这既保证了信息获取的准确性（尺寸、位置与要获取的视图完全一致），也不会在视觉上造成额外的影响。

```swift
extension View {
    func getWidth(_ width: Binding<CGFloat>) -> some View {
        modifier(GetWidthModifier(width: width))
    }
}

struct GetWidthModifier: ViewModifier {
    @Binding var width: CGFloat
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    let proxyWidth = proxy.size.width
                    Color.clear
                        .task(id: proxy.size.width) {
                            $width.wrappedValue = max(proxyWidth, 0)
                        }
                }
            )
    }
}
```

注意：如果想通过 PreferenceKey 传递信息，最好在 `overlay` 中进行。因为在某些系统版本中，从 `background` 传递的数据无法被 `onPreferenceChange` 获取到。

```swift
struct GetInfoByPreferenceKey: View {
    var body: some View {
        ScrollView {
            Text("Hello world")
                .overlay(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: MinYKey.self, value: proxy.frame(in: .global).minY)
                    }
                )
        }
        .onPreferenceChange(MinYKey.self) { value in
            print(value)
        }
    }
}

struct MinYKey: PreferenceKey {
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
    static var defaultValue: CGFloat = .zero
}
```

在某些情况下，通过 GeometryReader 获取的值可能会使你陷入无尽的循环，从而导致视图的不稳定和性能损失，例如：

```swift
struct GetSize: View {
    @State var width: CGFloat = .zero
    var body: some View {
        VStack {
            Text("Width = \(width)")
                .getWidth($width)
        }
    }
}
```

![https://cdn.fatbobman.com/unstable-Text-by-GeometryReader_2023-10-30_22.16.35.2023-10-30%2022_17_21.gif](https://cdn.fatbobman.com/unstable-Text-by-GeometryReader_2023-10-30_22.16.35.2023-10-30%2022_17_21.gif)

严格来说，这个问题的根源在于 Text。由于默认字体的宽度不是固定的，所以无法形成一个稳定的尺寸协商结果。解决方法很简单，可以通过添加`.monospaced()`或使用固定宽度的字体。

```swift
Text("Width = \(width)")
    .monospaced()
    .getWidth($width)
```

> 字符抖动的示例来自于 SwiftUI-Lab 的 [Safely Updating The View State](https://swiftui-lab.com/state-changes/) 这篇文章。
> 

```responser
id:1
```

## GeometryReader 的性能问题

只要了解 GeometryReader 获取几何信息的时机，就能理解其对性能的影响。作为一个视图，GeometryReader 只能在被评估、布局和渲染后，才能将获取的数据传递给闭包中的代码。这意味着，如果我们需要利用其提供的信息进行布局调整，必须先完成至少一轮的评估、布局和渲染过程，然后才能获取数据，并根据这些数据重新调整布局。这个过程将导致视图被多次重新评估和布局。

由于早期的 SwiftUI 缺少了 LazyGrid 等布局容器，开发者只能通过 GeometryReader 来实现各种自定义布局。当视图数量较多时，这将会导致严重的性能问题。

自从 SwiftUI 补充了一些之前缺失的布局容器后，GeometryReader 对性能的大规模影响已经有所减轻。特别是在允许自定义符合 Layout 协议的布局容器后，上述的问题已基本解决。与 GeometryReader 不同，满足 layout 协议的布局容器能够在布局阶段就获取到父视图的建议尺寸和所有子视图的需求尺寸。这样可以避免由于反复传递几何数据导致的大量视图的反复更新。

然而，这并不意味着在使用 GeometryReader 时没有需要注意的事项。为了进一步减少 GeometryReader 对性能的影响，我们需要注意以下两点：

- 只让少数视图受到几何信息变化的影响
- 仅传递所需的几何信息

以上两点符合我们优化 SwiftUI 视图性能的一贯原则，即控制状态变化的影响范围。

## 用 SwiftUI 的方式进行布局

由于对 GeometryReader 的负面看法，一些开发者会尝试寻找其他方式以避免使用它。不过，大家是否想过，其实在很多场景中，GeometryReader 本来就并非最优解。与其说避免使用，到不如说用更加 SwiftUI 的方式来进行布局。

GeometryReader 常用于需要限定比例的场景，例如让视图占据可用空间的 25% 宽度，或者像上文中根据给定的高宽比来计算高度。在处理类似需求时，我们应优先采用更符合 SwiftUI 的思维方式来考虑布局方案，而非依赖某个特定的几何数据进行计算。

例如，我们可以使用以下代码来满足上文中限定图片高宽比的需求：

```swift
struct ImageContainer2: View {
    let imageName: String
    var body: some View {
        Color.clear
            .aspectRatio(1.77, contentMode: .fill)
            .overlay(alignment: .topLeading) {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .clipped()
    }
}

struct GeometryReaderInScrollView: View {
    var body: some View {
        ScrollView {
            ImageContainer2(imageName: "pic")
        }
    }
}
```

通过 `aspectRatio` 创建一个符合高宽比的基底视图，然后将 `Image` 放置在 `overlay` 中。此外，由于 `overlay` 支持设置对齐指南，比起 GeometryReader，它可以更方便地调整图片的对齐位置。

另外，GeometryReader 经常用于按照一定比例分配两个视图的空间。对于这类需求，也可以通过其他手段处理（以下代码实现了宽度的 40% 和 60% 的分配）：

```swift
struct FortyPercent: View {
    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            // placeholder
            GridRow {
                ForEach(0 ..< 5) { _ in
                    Color.clear.frame(maxHeight: 0)
                }
            }
            GridRow {
                Image("pic")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .gridCellColumns(2)
                Text("Fatbobman's Swift Weekly").font(.title)
                    .gridCellColumns(3)
            }
        }
        .border(.blue)
        .padding()
    }
}
```

![https://cdn.fatbobman.com/image-20231031103955150.png](https://cdn.fatbobman.com/image-20231031103955150.png)

不过，单纯就按照一定比例将两个视图置于特定空间（ 无视子视图尺寸 ）中这个需求而言，GeometryReader 至今仍是最优解之一（ Gird 的解决方案整体高度由子视图来决定）。

```swift
struct RatioSplitHStack<L, R>: View where L: View, R: View {
    let leftWidthRatio: CGFloat
    let leftContent: L
    let rightContent: R
    init(leftWidthRatio: CGFloat, @ViewBuilder leftContent: @escaping () -> L, @ViewBuilder rightContent: @escaping () -> R) {
        self.leftWidthRatio = leftWidthRatio
        self.leftContent = leftContent()
        self.rightContent = rightContent()
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: proxy.size.width * leftWidthRatio)
                    .overlay(leftContent)
                Color.clear
                    .overlay(rightContent)
            }
        }
    }
}

struct RatioSplitHStackDemo: View {
    var body: some View {
        RatioSplitHStack(leftWidthRatio: 0.25) {
            Rectangle().fill(.red)
        } rightContent: {
            Color.clear
                .overlay(
                    Text("Hello World")
                )
        }
        .border(.blue)
        .frame(width: 300, height: 60)
    }
}
```

![image-20231104145027741](https://cdn.fatbobman.com/image-20231104145027741.png)

本章并不是在暗示开发者应避免使用 GeometryReader，而是在提醒开发者，SwiftUI 还有许多其他的布局手段。

> 请阅读 [用 SwiftUI 的方式进行布局](https://www.fatbobman.com/posts/layout-in-SwiftUI-way/) 和 [在 SwiftUI 中实现视图居中的若干种方法](https://www.fatbobman.com/posts/centering_the_View_in_SwiftUI/) 两篇文章，以了解面对同一个需求，SwiftUI 有多种布局手段。
> 

## 里子和面子：不同的尺寸数据

在 SwiftUI 中，有一些 modifier 是在布局之后，在渲染层面对视图进行的调整。在 [SwiftUI 布局 —— 尺寸（ 下 ）](https://www.fatbobman.com/posts/layout-dimensions-2/) 一文中，我们探讨过有关尺寸的“里子和面子”的问题。比如下面的代码：

```swift
struct SizeView: View {
    var body: some View {
        Rectangle()
            .fill(Color.orange.gradient)
            .frame(width: 100, height: 100)
            .scaleEffect(2.2)
    }
}
```

在布局时，Rectangle 的需求尺寸为 100 x 100，但在渲染阶段，经过`scaleEffect`的处理，最终将呈现一个 220 x 220 的矩形。由于`scaleEffect`是在布局之后调整的，因此即使创建一个符合 Layout 协议的布局容器，也无法获知其渲染尺寸。在这种情况下，GeometryReader 就发挥了它的作用。

```swift
struct SizeView: View {
    var body: some View {
        Rectangle()
            .fill(Color.orange.gradient)
            .frame(width: 100, height: 100)
            .printViewSize()
            .scaleEffect(2.2)
    }
}

extension View {
    func printViewSize() -> some View {
        background(
            GeometryReader { proxy in
                let layoutSize = proxy.size
                let renderSize = proxy.frame(in: .global).size
                Color.clear
                    .task(id: layoutSize) {
                        print("Layout Size:", layoutSize)
                    }
                    .task(id: renderSize) {
                        print("Render Size:", renderSize)
                    }
            }
        )
    }
}

// OUTPUT：
Layout Size: (100.0, 100.0)
Render Size: (220.0, 220.0)
```

`GeometryProxy` 的 `size` 属性返回的是视图的布局尺寸，而通过 `frame.size` 返回的则是最终的渲染尺寸。

```responser
id:1
```

## visualEffect：无需使用 GeometryReader 也能获取几何信息

考虑到开发者经常需要获取局部视图的 GeometryProxy，而不断地封装 GeometryReader 又显得过于繁琐，因此在 WWDC 2023 中，苹果为 SwiftUI 添加了一个新的 modifier：[visualEffect](https://developer.apple.com/documentation/swiftui/visualeffect)。

`visualEffect` 允许开发者在不破坏当前布局的情况下（不改变其祖先和后代）直接在闭包中使用视图的 GeometryProxy，并对视图应用某些特定的 modifier。

```swift
var body: some View {
    ContentRow()
        .visualEffect { content, geometryProxy in
            content.offset(x: geometryProxy.frame(in: .global).origin.y)
        }
}
```

`visualEffect` 仅允许符合 VisualEffect 协议的 modifier 被使用于闭包当中，以保证安全和效果。简单来说，SwiftUI 让只作用于“面子”（ 渲染层面）的 modifier 符合了 VisualEffect 协议，禁止在闭包中使用所有能对布局造成影响的 modifier（ 例如：frame、padding 等）。

我们可以通过以下代码，创建一个`visualEffect`的粗糙仿制版本（没有限制可使用的 modifier 类型）：

```swift
public extension View {
    func myVisualEffect(@ViewBuilder _ effect: @escaping @Sendable (AnyView, GeometryProxy) -> some View) -> some View {
        modifier(MyVisualEffect(effect: effect))
    }
}

public struct MyVisualEffect<Output: View>: ViewModifier {
    private let effect: (AnyView, GeometryProxy) -> Output
    public init(effect: @escaping (AnyView, GeometryProxy) -> Output) {
        self.effect = effect
    }

    public func body(content: Content) -> some View {
        content
            .modifier(GeometryProxyWrapper())
            .hidden()
            .overlayPreferenceValue(ProxyKey.self) { proxy in
                if let proxy {
                    effect(AnyView(content), proxy)
                }
            }
    }
}

struct GeometryProxyWrapper: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ProxyKey.self, value: proxy)
                }
            )
    }
}

struct ProxyKey: PreferenceKey {
    static var defaultValue: GeometryProxy?
    static func reduce(value: inout GeometryProxy?, nextValue: () -> GeometryProxy?) {
        value = nextValue()
    }
}
```

与 `visualEffect` 进行比较：

```swift
struct EffectTest: View {
    var body: some View {
        HStack {
            Text("Hello")
                .font(.title)
                .border(.gray)

            Text("Hello")
                .font(.title)
                .visualEffect { content, proxy in
                    content
                        .offset(x: proxy.size.width / 2.0, y: proxy.size.height / 2.0)
                        .scaleEffect(0.5)
                }
                .border(.gray)
                .foregroundStyle(.red)

            Text("Hello")
                .font(.title)
                .myVisualEffect { content, proxy in
                    content
                        .offset(x: proxy.size.width / 2.0, y: proxy.size.height / 2.0)
                        .scaleEffect(0.5)
                }
                .border(.gray)
                .foregroundStyle(.red)
        }
    }
}
```

![https://cdn.fatbobman.com/image-20231031145420378.png](https://cdn.fatbobman.com/image-20231031145420378.png)

## 总结

随着 SwiftUI 功能的不断完善，直接使用 GeometryReader 的情况可能会越来越少。然而，毫无疑问，GeometryReader 仍是 SwiftUI 中一个重要的工具。开发者需要正确地将其应用于适当的场景。