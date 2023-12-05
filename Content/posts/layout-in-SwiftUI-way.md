---
date: 2023-03-01 08:12
description: 最近时常有朋友反映，尽管 SwiftUI 的布局系统学习门槛很低，但当真正面对要求较高的设计需求时，好像又无从下手。SwiftUI 真的具备创建复杂用户界面的能力吗？本文将通过用多种手段完成同一需求的方式，展示 SwiftUI 布局系统的强大与灵活，并通过这些示例让开发者对 SwiftUI 的布局逻辑有更多的认识和理解。
tags: SwiftUI,小题大做,布局
title: 用 SwiftUI 的方式进行布局
image: images/layout-in-SwiftUI-way.png
mediumURL: https://medium.com/p/563704527fd8
---
最近时常有朋友反映，尽管 SwiftUI 的布局系统学习门槛很低，但当真正面对要求较高的设计需求时，好像又无从下手。SwiftUI 真的具备创建复杂用户界面的能力吗？本文将通过用多种手段完成同一需求的方式，展示 SwiftUI 布局系统的强大与灵活，并通过这些示例让开发者对 SwiftUI 的布局逻辑有更多的认识和理解。

> 可在 [此处](https://github.com/fatbobman/BlogCodes/tree/main/LayoutInTheSwiftUIWay) 获取本文代码。

## 需求

不久前，在 [聊天室](https://discord.gg/ApqXmy5pQJ) 中，有网友提出了这样一个布局需求：

有两个竖向排列的视图。在初始状态时（ show == false ），视图一（ 红色视图 ）的底部与屏幕底部对齐，当 show == true 时，视图二（ 绿色视图 ）的底部与屏幕底部对齐。

大致效果如下：

![layoutInSwiftUIWayDemo](https://cdn.fatbobman.com/layoutInSwiftUIWayDemo_2023-02-28_11.23.58.2023-02-28%2011_24_54.gif)

```responser
id:1
```

## 解决方案

对于上面的需求，相信不少读者都会在第一时间想出多个解决方案。下文中，我们将用 SwiftUI 布局系统提供的多种手段来实现该要求。在这些解决方案中，有些非常简单、直接，有些则会略显烦琐，曲折。我尽量让每种方案都采用不同的布局逻辑。

### 准备工作

我们首先将一些可复用的代码提取出来，以简化之后的工作：

```swift
// 视图一
struct RedView: View {
    var body: some View {
        Rectangle()
            .fill(.red)
            .frame(height: 600)
    }
}

// 视图二
struct GreenView: View {
    var body: some View {
        Rectangle()
            .fill(.green)
            .frame(height: 600)
    }
}

// 状态切换按钮
struct OverlayButton: View {
    @Binding var show: Bool
    var body: some View {
        Button(show ? "Hide" : "Show") {
            show.toggle()
        }
        .buttonStyle(.borderedProminent)
    }
}

extension View {
    func overlayButton(show: Binding<Bool>) -> some View {
        self
            .overlay(alignment: .bottom) {
                OverlayButton(show: show)
            }
    }
}

// 获取视图尺寸
struct SizeInfoModifier: ViewModifier {
    @Binding var size: CGSize
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .task(id: proxy.size) {
                            size = proxy.size
                        }
                }
            )
    }
}

extension View {
    func sizeInfo(_ size: Binding<CGSize>) -> some View {
        self
            .modifier(SizeInfoModifier(size: size))
    }
}
```

### 一、Offset

VStack + offset 是一个相当符合直觉的处理方式。

```swift
struct OffsetDemo: View {
    @State var show = false
    @State var greenSize: CGSize = .zero
    var body: some View {
        Color.clear
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    RedView()
                    GreenView()
                        .sizeInfo($greenSize)
                }
                .offset(y: show ? 0 : greenSize.height)
                .animation(.default, value: show)
            }
            .ignoresSafeArea()
            .overlayButton(show: $show)
    }
}
```

代码提示：

* `Color.clear.ignoresSafeArea()` 将创建一个与屏幕尺寸一致的视图
*  overlay 可以很好的控制建议尺寸，同时又可享受到便捷的对齐设置
* 通过 `animation(.default, value: show)` 使动画与特定的状态变化相关联

在上面的代码中，考虑到当 show == true 时，视图二（ 绿色视图 ）的底部必然与屏幕底部对齐，因此，将 overlay 的对齐指南设置为 `bottom` ，可以极大地简化我们的初始布局声明。以此布局为基础，通过 offset ，分别为两种状态进行了位移值描述。

我们也可以使用其他的修饰符（ 例如：padding、postion ）采用该布局思路实现上述需求。

```swift
.offset(y: show ? 0 : greenSize.height) // 替换改行为
.padding(.bottom, show ? 0 : -greenSize.height)
```

> 尽管在本例中，offset 和 padding 的视觉呈现一致，但当需要与其他视图一起进行布局时，两者之间还是有很大的不同。padding 是在布局层面进行的调整，添加 padding 后的视图，同时也会对其他视图的布局产生影响。offset 则是在渲染层面进行的位置调整，即使出现了位置变化，其他视图在布局时，并不会将其位移考虑在其中。有关这方面的内容，请参阅 [SwiftUI 布局 —— 尺寸（ 下 ）](https://fatbobman.com/posts/layout-dimensions-2/#面子和里子) 一文中“面子和里子”章节。

![padding-offset](https://cdn.fatbobman.com/image-20230228134936300.png)

### 二、AlignmentGuide

在 SwiftUI 中，开发者可以使用 alignmentGuide 修饰器来修改视图某个对齐指南的值（ 设置显式值 ）。由于 `Color.clear.overlay` 为我们提供了一个相当理想的布局环境，因此，通过分别修改在不同状态下两个视图的对齐指南，也能满足本文的需求。

```swift
struct AlignmentDemo: View {
    @State var show = false
    @State var greenSize: CGSize = .zero
    var body: some View {
        Color.clear
            .overlay(alignment: .bottom) {
                RedView()
                    .alignmentGuide(.bottom) {
                        show ? $0[.bottom] + greenSize.height : $0[.bottom]
                    }
            }
            .overlay(alignment: .bottom) {
                GreenView()
                    .sizeInfo($greenSize)
                    .alignmentGuide(.bottom) {
                        show ? $0[.bottom] : $0[.top]
                    }
            }
            .animation(.default, value: show)
            .ignoresSafeArea()
            .overlayButton(show: $show)
    }
}
```

在本解决方案中，我们将两个视图分别置于两个 overlay 层中，尽管在视觉上，两者之间仍呈垂直排列，但实际上两者之间并无关联。

无论为同一个视图添加多少层 overlay（ 或 background ），它们为子视图所提供的建议尺寸都是一致的（ 与原视图的尺寸一致 ）。在上面的代码中，由于两个视图使用了同样的动画曲线设定，因此，在移动时并不会出现分离的情况。但如果为视图分别设定不同的动画曲线（ 例如：一个 linear、一个 easeIn ），状态切换时便无法保证视图之间的完全紧密。

> 有关建议尺寸、需求尺寸等内容，请参阅 [SwiftUI 布局 —— 尺寸（ 上 ）](https://fatbobman.com/posts/layout-dimensions-1/) 一文

### 三、NameSpace

从 3.0 版本（ iOS 15 ）开始，SwiftUI 提供了新的 NameSpace 以及 matchedGeometryEffect 修饰器，让开发者只需少量代码便可实现例如英雄动画这类的复杂需求。

严格意义上来说，NameSpace + matchedGeometryEffect 是对一组修饰器以及代码的统一封装。通过命名空间以及 ID 来保存特定视图的几何信息（ 位置、尺寸 ），并自动设置给其他有需求的视图。

```swift
struct NameSpaceDemo: View {
    @State var show = false
    @Namespace var placeHolder
    @State var greenSize: CGSize = .zero
    @State var redSize: CGSize = .zero
    var body: some View {
        Color.clear
            // green placeholder
            .overlay(alignment: .bottom) {
                Color.clear // GreenView().opacity(0.01)
                    .frame(height: greenSize.height)
                    .matchedGeometryEffect(id: "bottom", in: placeHolder, anchor: .bottom, isSource: true)
                    .matchedGeometryEffect(id: "top", in: placeHolder, anchor: .top, isSource: true)
            }
            .overlay(
                GreenView()
                    .sizeInfo($greenSize)
                    .matchedGeometryEffect(id: "bottom", in: placeHolder, anchor: show ? .bottom : .top, isSource: false)
            )
            .overlay(
                RedView()
                    .matchedGeometryEffect(id: "top", in: placeHolder, anchor: show ? .bottom : .top, isSource: false)
            )
            .animation(.default, value: show)
            .ignoresSafeArea()
            .overlayButton(show: $show)
    }
}
```

在上面的代码中，我们在第一个 overlay 中绘制了一个与视图二尺寸一致的视图（ 不显示 ），并将其底边与屏幕底边对齐。通过 `matchedGeometryEffect` 分别为该站位视图的顶部和底部设置了两个标识符以保存信息。

让视图一、视图二在两个状态下分别使用对应的 ID 位置，即可实现本文需求。

> NameSpace + matchedGeometryEffect 是一个十分强大的组合，尤其擅长面对同时有位置及尺寸变化的场景。不过需要注意的是，NameSpace 只适用于在同一棵视图树中分享数据，如果出现了例如 [一段因 @State 注入机制所产生的“灵异代码”](https://fatbobman.com/posts/bug-code-by-state-inject/) 一文中提到了两棵树的情况，则无法实现几何信息的共享。

### 四、ScrollView

考虑到本文需求的动画形态（ 竖向滚动 ），使用 ScrollViewReader 提供的滚动定位功能，同样可以满足需求。

```swift
struct ScrollViewDemo: View {
    @State var show = false
    @State var screenSize: CGSize = .zero
    @State var redViewSize: CGSize = .zero
    var body: some View {
        Color.clear
            .overlay(
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: screenSize.height - redViewSize.height)
                            RedView()
                                .sizeInfo($redViewSize)
                                .id("red")
                            GreenView()
                                .id("green")
                        }
                    }
                    .scrollDisabled(true)
                    .onAppear {
                        proxy.scrollTo("red", anchor: .bottom)
                    }
                    .onChange(of: show) { _ in
                        withAnimation {
                            if show {
                                proxy.scrollTo("green", anchor: .bottom)
                            } else {
                                proxy.scrollTo("red", anchor: .bottom)
                            }
                        }
                    }
                }
            )
            .sizeInfo($screenSize)
            .ignoresSafeArea()
            .overlayButton(show: $show)
    }
}
```

尽管都是垂直构图（ axis 为 vertical ），但 ScrollView 与 VStack 在处理各种尺寸的逻辑上还是有非常大的差别。

ScrollView 会使用父视图给定的全部建议尺寸创建滚动区域，但在询问其子视图的需求尺寸时只会提供理想尺寸。这意味着，在 ScrollView 中，子视图最好明确的设定尺寸（ 提出明确地需求尺寸 ）。因此，在上面的代码中，需要通过屏幕高度和视图一的高度差来计算上方的空白站位视图高度。

通过设定 `scrollTo` 的 anchor，在合理的要求下，我们可以让视图停在特定位置。`scrollDisabled`（ 则让我们可以在 iOS 16+ 中屏蔽 ScrollView 的滚动手势 ）。

```responser
id:1
```

### 五、LayoutPriority

在 SwiftUI 中，设置视图优先级（ 使用 `layoutPriority` ）是一个好用但并不常用的功能。SwiftUI 在进行布局时，当布局容器给出的建议尺寸无法满足全部子视图的需求尺寸时，会根据子视图的 Priority，优先满足级别较高的视图的布局需求。

```swift
struct LayoutPriorityDemo: View {
    @State var show = false
    @State var screenSize: CGSize = .zero
    @State var redViewSize: CGSize = .zero
    var body: some View {
        Color.clear
            .overlay(alignment: show ? .bottom : .top) {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: screenSize.height - redViewSize.height)
                        .layoutPriority(show ? 0 : 2)
                    RedView()
                        .sizeInfo($redViewSize)
                        .layoutPriority(show ? 1 : 2)
                    GreenView().layoutPriority(show ? 2 : 0)
                }
                .animation(.default, value: show)
            }
            .sizeInfo($screenSize)
            .ignoresSafeArea()
            .overlayButton(show: $show)
    }
}
```

在上面的代码中，我们让 overlay 在两种状态时，采取不同的布局指南策略，并让视图具备不同的优先级状态（ 状态切换时 ），以此来获得想要的布局结果。

> 尽管 Spacer 给定了明确的尺寸，但在状态二时，受限于建议尺寸，其并不会参与布局。视图二同理

### 六、再战 AlignmentGuide

在上面使用 AlignmentGuide 的例子中，我们通过 GeometryReader 获取了视图二的高度信息，并通过设置显式对齐指南来完成了移动。从某种逻辑上来说，这种方式与 offset 类似，都需要获取到明确的位移值才能满足需要。

在本例中，尽管仍使用 AlignmentGuide，但无需获取具体尺寸值，便可达成目标。

```swift
struct AlignmentWithoutGeometryReader: View {
    @State var show = false
    var body: some View {
        Color.clear
            .overlay(alignment: .bottom) {
                GreenView()
                    .alignmentGuide(.bottom) {
                        show ? $0[.bottom] : 0
                    }
                    .overlay(alignment: .top) {
                        RedView()
                            .alignmentGuide(.top) { $0[.bottom] }
                    }
                    .animation(.default, value: show)
            }
            .ignoresSafeArea()
            .overlayButton(show: $show)
    }
}
```

在上面的代码中，我们利用 overlay 嵌套 + alignmentGuide 的方式实现了将视图一的底边与视图二的顶部对齐绑定。因此，只需要在状态切换时，调整视图二的对齐指南即可（ 视图一将自动跟随视图二移动 ）。

此种方式在视觉上与通过  VStack 的实现类似，但两者在需求尺寸上有明显不同。VStack 的纵向需求尺寸为视图一与视图二的高度和，而通过 overlay 嵌套，纵向需求尺寸仅为视图二的高度（ 尽管视觉上视图一在视图二的上方且紧密相连 ）。

### 七、Transition

通过为视图设定 Transition（ 转场 ），在视图插入或将其移出视图树时，SwiftUI 将自动生成对应的动画效果。

```swift
struct TransitionDemo:View {
    @State var show = false
    var body: some View {
        Color.clear
            .overlay(alignment:.bottom){
                VStack(spacing:0) {
                    RedView()
                    if show {
                        GreenView()
                            .transition(.move(edge: .bottom))
                    }
                }
                .animation(.default, value: show)
            }
            .ignoresSafeArea()
            .overlayButton(show: $show) // 不能使用显式动画
    }
}
```

请注意，转场对动画设定的位置、方式要求很高。稍不注意便会出现转场完全失效或部分失效的情况，例如在本例中，如果在 Button 中（ 切换 show 状态时 ）添加 `withAnimation` 进行显式动画设定，将导致进入转场失效。

转场是 SwiftUI 提供的强大能力之一，可以极大地简化动画实现的难度。我写的视图管理器 [SwiftUI Overlay Container](https://fatbobman.com/posts/swiftUIOverlayContainer2/) ，便是建立在对转场功能的充分应用之上。

> 有关转场动画的更多内容，请参阅 [SwiftUI 的动画机制](https://fatbobman.com/posts/the_animation_mechanism_of_swiftUI/) 一文

### 八、Layout 协议

在 4.0 版本中，SwiftUI 增加了 Layout 协议，通过该协议，开发者可以针对特定的场景，创建自定义布局容器。尽管当前的需求仅有两个视图，但我们仍然可以从中提炼出场景特性：在垂直排列的前提下，在特定状态时，指定视图的底部与容器视图的底部对齐。

```swift
struct LayoutProtocolDemo: View {
    @State var show = false
    var body: some View {
        Color.clear
            .overlay(
                AlignmentBottomLayout {
                    RedView()
                        .alignmentActive(show ? false : true) // 设定当前的活动视图
                    GreenView()
                        .alignmentActive(show ? true : false)
                }
                .animation(.default, value: show)
            )
            .ignoresSafeArea()
            .overlayButton(show: $show)
    }
}

struct ActiveKey: LayoutValueKey {
    static var defaultValue = false
}

extension View {
    func alignmentActive(_ isActive: Bool) -> some View {
        layoutValue(key: ActiveKey.self, value: isActive)
    }
}

struct AlignmentBottomLayout: Layout {
    func makeCache(subviews: Subviews) -> Catch {
        .init()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Catch) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        var height: CGFloat = .zero
        for i in subviews.indices {
            let subview = subviews[i]
            if subview[ActiveKey.self] == true { // 获取活动视图
                cache.activeIndex = i
            }
            let viewDimension = subview.dimensions(in: proposal)
            height += viewDimension.height
            cache.sizes.append(.init(width: viewDimension.width, height: viewDimension.height))
        }
        return .init(width: proposal.replacingUnspecifiedDimensions().width, height: proposal.replacingUnspecifiedDimensions().height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Catch) {
        guard !subviews.isEmpty else { return }
        var currentY: CGFloat = bounds.height - cache.alignmentHeight + bounds.minY // 初始 y 位置
        for i in subviews.indices {
            let subview = subviews[i]
            subview.place(at: .init(x: bounds.minX, y: currentY), anchor: .topLeading, proposal: proposal)
            currentY += cache.sizes[i].height
        }
    }
}

struct Catch {
    var activeIndex = 0
    var sizes: [CGSize] = []

    var alignmentHeight: CGFloat {
        guard !sizes.isEmpty else { return .zero }
        return sizes[0...activeIndex].map { $0.height }.reduce(0,+)
    }
}
```

在上面的代码中，我们通过 `alignmentActive`（ LayoutValueKey ）指示当前与容器底部对齐的视图。

毋庸置疑，这是所有方案中最复杂的实现。不过，如果我们有类似的需求，使用该自定义容器将十分地便利。

```swift
struct LayoutProtocolExample: View {
    let views = (0..<8).map { _ in CGFloat.random(in: 100...150) }
    @State var index = 0
    var body: some View {
        VStack {
            Picker("", selection: $index) {
                ForEach(views.indices, id: \.self) { i in
                    Text("\(i)").tag(i)
                }
            }
            .pickerStyle(.segmented)
            .zIndex(2) 
            AlignmentBottomLayout {
                ForEach(views.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.orange.gradient)
                        .overlay(Text("\(i)").font(.title))
                        .padding([.horizontal, .top], 10)
                        .frame(height: views[i])
                        .alignmentActive(index == i ? true : false)
                }
            }
            .animation(.default, value: index)
            .frame(width: 300, height: 400)
            .clipped()
            .border(.blue)
        }
        .padding(20)
    }
}
```

![自定义布局容器](https://cdn.fatbobman.com/layoutProtocol_2023-02-28_16.24.29.2023-02-28%2016_25_19.gif)

## 总结

同大多的布局框架一样，最终决定布局能力的上限主要取决于开发者。SwiftUI 为我们提供了众多的布局手段，只有充分地理解并掌握它们，方可从容应对复杂的布局需求。

