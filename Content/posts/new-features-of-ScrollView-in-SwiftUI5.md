---
date: 2023-06-13 08:12
description: 在 SwiftUI 5.0 中，苹果大幅强化了 ScrollView 功能。新增了大量新颖、完善的 API。本文将对这些新功能进行介绍，希望能够让它们更多、更早的帮助到有需要的开发者。
tags: SwiftUI,WWDC23
title: 深入了解 SwiftUI 5 中 ScrollView 的新功能
image: images/new-features-of-ScrollView-in-SwiftUI5.jpg
mediumURL: https://medium.com/p/440b9f0e0e09
---
在 SwiftUI 5.0 中，苹果大幅强化了 ScrollView 功能。新增了大量新颖、完善的 API。本文将对这些新功能进行介绍，希望能够让它们更多、更早的帮助到有需要的开发者。

> 可以在 [此处](https://github.com/fatbobman/BlogCodes/tree/main/NewFeaturesOfScrollView) 获取完整的演示代码

## contentMargins

```swift
public func contentMargins(_ edges: Edge.Set = .all, _ length: CGFloat?, for placement: ContentMarginPlacement = .automatic) -> some View
```

为可滚动容器的内容或滚动指示器（Scroll Indicator）添加外边距（Margin）。

- 不限于 ScrollView，支持所有可滚动容器（包括 List、TextEditor 等）。
- 将可滚动容器内的所有子视图视为一个整体，并为其添加 margin。之前在 List 或 TextEditor 中实现类似操作是十分困难的。
- 默认的 ContentMarginPlacement（.automatic）将导致指示器与内容之间的长度不一致。如果想保持长度一致，应使用`.scrollContent`。
- 适用于作用域内的所有可滚动容器。

```swift
struct ContentMarginsForScrollView: View {
    @State var text = "Hello world"
    var body: some View {
        VStack {
            ScrollView(.horizontal) {
                HStack {
                    CellView(color: .yellow)
                        // a custom overlay view for easy display of auxiliary information
                        .idView("leading")
                    ForEach(0 ..< 5) { i in
                        CellView()
                            .idView(i)
                    }
                    CellView(color: .green)
                        .idView("trailing")
                }
            }

            // Also affected by contentMargins
            TextEditor(text: $text)
                .border(.red)
                .padding()
                .contentMargins(.all, 30, for: .scrollContent)
        }
        // Applies to all scrollable containers within the scope
        .contentMargins(.horizontal, 50, for: .scrollContent)
    }
}
```

![contentMargins_demo_2023-06-12_11.02.35.2023-06-12 11_04_43](https://cdn.fatbobman.com/contentMargins_demo_2023-06-12_11.02.35.2023-06-12%2011_04_43.gif)

```responser
id:1
```

## safeAreaPadding

为视图的安全区域添加内嵌。在某些场景下，其效果与 safeAreaInset 十分相似。例如，在下面的代码中，为 ScrollView 的 leading 方向添加安全区域的两种方式效果是一致的。

```swift 
struct SafeAreaPaddingDemo: View {
    var body: some View {
        VStack {
            ScrollView {
                ForEach(0 ..< 20) { i in
                    CellView(width: nil)
                        .idView(i)
                }
            }
            .safeAreaPadding(.leading,20)
            // .safeAreaInset(edge: .leading){
            //       Color.clear.frame(width:20)
            //  }
        }
    }
}
```

* 该属性不仅适用于可滚动视图，而适用于所有类型的视图。
* 它只会影响最近的一个视图。
* 对于全面屏的额外安全区域，safeAreaInset 和 safeAreaPadding 的处理逻辑不一致。

例如，下面的两种实现中，ScrollView 的底部空间是不同的。

使用 safeAreaInset：

```swift
ScrollView {
    ForEach(0 ..< 20) { i in
        CellView(width: nil)
            .idView(i)
    }
}
.safeAreaInset(edge: .bottom){
    Text("Bottom View")
        .font(.title3)
        .foregroundColor(.indigo)
        .frame(maxWidth: .infinity, maxHeight: 40)
        .background(.green.opacity(0.6))
}
```

![image-20230612112714343](https://cdn.fatbobman.com/image-20230612112714343.png)

使用 safeAreaPadding：

```swift
ZStack(alignment: .bottom) {
    ScrollView {
        ForEach(0 ..< 20) { i in
            CellView(width: nil)
                .idView(i)
        }
    }
    .safeAreaPadding(.bottom, 40)

    Text("Bottom View")
        .font(.title3)
        .foregroundColor(.indigo)
        .frame(maxWidth: .infinity, maxHeight: 40)
        .background(.green.opacity(0.6))
}
```

![image-20230612112755403](https://cdn.fatbobman.com/image-20230612112755403.png)

> 阅读 [掌握 SwiftUI 的 Safe Area](https://fatbobman.com/posts/safeArea/) 一文，了解更多有关安全区域的内容。

## scrollIndicatorsFlash

控制滚动指示器

使用 `scrollIndicatorsFlash(onAppear: true)` 可以在滚动视图出现时使其滚动指示器短暂闪烁。

使用 `scrollIndicatorsFlash(trigger:)` 可以在提供的值更改时，修饰符作用域范围内的所有可滚动容器的滚动指示器短暂闪烁。

```swift
struct ScrollIndicatorsFlashDemo: View {
    @State private var items = (0 ..< 50).map { Item(n: $0) }
    var body: some View {
        VStack {
            Button("Remove First") {
                guard !items.isEmpty else { return }
                items.removeFirst()
            }.buttonStyle(.bordered)
            ScrollView {
                ForEach(items) { item in
                    CellView(width: 100, debugInfo: "\(item.n)")
                        .idView(item.n)
                        .frame(maxWidth:.infinity)
                }
            }
            .animation(.bouncy, value: items.count)
        }
        .padding(.horizontal,10)
        .scrollIndicatorsFlash(onAppear: true)
        .scrollIndicatorsFlash(trigger: items.count)
    }
}
```

![scrollIndicatorFlash_demo_2023-06-12_13.44.03.2023-06-12 13_44_40](https://cdn.fatbobman.com/scrollIndicatorFlash_demo_2023-06-12_13.44.03.2023-06-12%2013_44_40.gif)

## scrollClipDisable

scrollClipDisable 用于控制是否对滚动内容应用裁剪以适应滚动容器的边界。

当 scrollClipDisable 为 false 时，滚动内容会被裁剪以适应滚动容器边界。任何超出边界的部分将不会显示。

当 scrollClipDisable 为 true 时，滚动内容不会被裁剪。它可以延伸超出滚动容器的边界，从而显示更多内容。

- 仅适用于 ScrollView
- 适用于作用域内的所有可滚动容器

```swift
struct ScrollClipDisableDemo: View {
    @State private var disable = true
    var body: some View {
        VStack {
            Toggle("Clip Disable", isOn: $disable)
                .padding(20)
            ScrollView {
                ForEach(0 ..< 10) { i in
                    CellView()
                        .idView(i)
                        .shadow(color: .black, radius: 50)
                }
            }
        }
        .scrollClipDisabled(disable)
    }
}
```

![scrollClipDisable_demo_2023-06-12_13.58.10.2023-06-12 13_58_50](https://cdn.fatbobman.com/scrollClipDisable_demo_2023-06-12_13.58.10.2023-06-12%2013_58_50.gif)

## scrollTargetLayout

此修饰符用于配合下文介绍的 `scrollTargetBehavior( ViewAlignedScrollTargetBehavior 模式） ` 或 `scrollPosition(id:) `使用。

应将此修饰符应用于 ScrollView 中包含主要重复内容的布局容器，如 LazyHStack 或 VStack。

```swift
@State private var isEnabled = true

ScrollView {
    LazyVStack {
        ForEach(items) { item in
            CellView(width: 200, height: 140)
                .idView(item.n)
        }
    }
    .scrollTargetLayout(isEnabled: isEnabled)
}
```

## defaultScrollAnchor

使用此修饰符可以指定滚动视图内容最初可见部分的锚点。它只影响滚动视图的初始状态，一次性设置。通常用于实现类似初始状态从底部显示的 IM 应用、从 trailing 开始显示数据等情况。通过 UnitPoint 可以同时设置两个轴向的初始位置。

```swift
struct ScrollPositionInitialAnchorDemo: View {
    @State private var show = false
    @State private var position: Position = .leading
    var body: some View {
        VStack {
            Toggle("Show", isOn: $show)
            Picker("Position", selection: $position) {
                ForEach(Position.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
            if show {
                ScrollView(.horizontal) {
                    LazyHStack {
                        ForEach(0 ..< 10000) { i in
                            CellView(debugInfo: "\(i)")
                                .idView(i)
                        }
                    }
                }
                .defaultScrollAnchor(position.unitPoint)
            }
        }
        .padding()
    }

    enum Position: String, Identifiable, CaseIterable {
        var id: UnitPoint { unitPoint }
        case leading, center, trailing
        var unitPoint: UnitPoint {
            switch self {
            case .leading:
                .leading
            case .center:
                .center
            case .trailing:
                .trailing
            }
        }
    }
}
```

![scrollPostion_initialAnchor_demo_2023-06-12_14.37.09.2023-06-12 14_37_47](https://cdn.fatbobman.com/scrollPostion_initialAnchor_demo_2023-06-12_14.37.09.2023-06-12%2014_37_47.gif)

> 尽管使用此修饰符实现初始定位十分容易，但当数据集很大时，仍然会有较严重的性能问题。可采用 [优化在 SwiftUI List 中显示大数据集的响应效率](https://fatbobman.com/posts/optimize_the_response_efficiency_of_List/) 一文中介绍的方式来解决。

## scrollPostion(id:)

使用此修饰符可以让滚动视图滚动到特定的位置。可以将其理解为 ScrollViewReader 的简化版本。

- 仅适用于 ScrollView
- 当 ForEach 中的数据源遵循 Identifiable 协议时，无需显式使用 `id` 修饰符设置标识
- 与 scrollTargetLayout 配合使用，可以获取当前的滚动位置（视图标识）
- 不支持锚点设定，固定锚点为子视图的 center
- 正如 [优化在 SwiftUI List 中显示大数据集的响应效率](https://fatbobman.com/posts/optimize_the_response_efficiency_of_List/) 一文所提到的，当数据集很大时，也会出现性能问题。

```swift
struct ScrollPositionIDDemo: View {
    @State private var show = false
    @State private var position: Position = .trailing
    @State private var items = (0 ..< 500).map {
        Item(n: $0)
    }

    @State private var id: UUID?

    var body: some View {
        VStack {
            Picker("Position", selection: $position) {
                ForEach(Position.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
            Text(id?.uuidString ?? "").fixedSize().font(.caption2)
            ScrollView(.horizontal) {
                LazyHStack {
                    ForEach(items) { item in
                        CellView(debugInfo: "\(item.n)")
                            .idView(item.n)
                    }
                }
            }
            .scrollPosition(id: $id)
            .scrollTargetLayout()
        }
        .animation(.default, value: id)
        .padding()
        .frame(height: 300)
        .task(id: position) {
            switch position {
            case .leading:
                id = items.first!.id
            case .center:
                id = items[250].id
            case .trailing:
                id = items.last!.id
            }
        }
    }
}
```

![scrollPositionID_demo_2023-06-12_15.38.35.2023-06-12 15_39_13](https://cdn.fatbobman.com/scrollPositionID_demo_2023-06-12_15.38.35.2023-06-12%2015_39_13.gif)

对应的 ScrollViewReader 版本：

```swift
ScrollViewReader { proxy in
    ScrollView(.horizontal) {
        LazyHStack {
            ForEach(items) { item in
                CellView(debugInfo: "\(item.n)")
                    .idView(item.n)
                    .id(item.id)
            }
        }
    }
    .task(id: position) {
        switch position {
        case .leading:
            proxy.scrollTo(items.first!.id)
        case .center:
            proxy.scrollTo(items[250].id)
        case .trailing:
            proxy.scrollTo(items.last!.id)
        }
    }
}
```

ScrollViewReader 和 scrollPostion(id:) 的内部实现原理应该差不多。但是，ScrollViewReader 可用于 List 中，还可设置锚点。scrollPostion(id:) 与 scrollTargetLayout 配合使用时，可获取当前滚动位置（标识）。

```responser
id:1
```

## scrollTargetBehavior

scrollTargetBehavior 用于设置 ScrollView 的滚动行为：分页还是与子视图对齐。

使用 `.scrollTargetBehavior(.paging)` 可以使 ScrollView 分页滚动，每次滚动一页（即 ScrollView 的可视尺寸）。

```swift
LazyVStack {
    ForEach(items) { item in
        CellView(width: 200, height: 140)
            .idView(item.n)
    }
}
.scrollTargetBehavior(.paging)
```

![scrollTarget_paging_demo_2023-06-12_15.55.29.2023-06-12 15_55_55](https://cdn.fatbobman.com/scrollTarget_paging_demo_2023-06-12_15.55.29.2023-06-12%2015_55_55.gif)

当设置为 .scrollTargetBehavior(.viewAligned) 时，需要与 scrollTargetLayout 一同使用。滚动停止时，容器顶端将与子视图的顶部对齐（在垂直模式下）。开发者可以通过控制 scrollTargetLayout 的启用与否来开关 viewAligned 的行为。

```swift
struct ScrollTargetBehaviorDemo: View {
    @State var items = (0 ..< 100).map { Item(n: $0) }
    @State private var isEnabled = true
    var body: some View {
        VStack {
            Toggle("Layout enable", isOn: $isEnabled).padding()
            ScrollView {
                LazyVStack {
                    ForEach(items) { item in
                        CellView(width: 200, height: 95)
                            .idView(item.n)
                    }
                }
                .scrollTargetLayout(isEnabled: isEnabled)
            }
            .border(.red, width: 2)
        }
        .scrollTargetBehavior(.viewAligned)
        .frame(height: 300)
        .padding()
    }
}
```

![scrollTarget_viewAligned_demo_2023-06-12_16.11.06.2023-06-12 16_11_42](https://cdn.fatbobman.com/scrollTarget_viewAligned_demo_2023-06-12_16.11.06.2023-06-12%2016_11_42.gif)

通过 `.scrollTargetBehavior(.viewAligned(limitBehavior:))` 我们可以定义对齐滚动目标行为的机制。

- `.automatic` 是默认行为，在紧凑的水平尺寸类中受限，否则不受限。
- `.always` 始终限制可滚动视图的数量。
- `.never` 不限制可滚动视图的数量。

同时，通过 ViewAlignedScrollTargetBehavior ，开发者还可以基于系统提供的目标覆盖滚动视图的滚动位置（ 尚未仔细研究实现细节 ）。

## NamedCoordinateSpace.scrollView

在 SwiftUI 5 中，苹果新增了 NamedCoordinateSpace 类型，方便用户命名坐标系，并提供了预置的 .scrollView 坐标系（仅支持 ScrollView）。通过这个坐标系，开发者可以非常容易地获取子视图与滚动视图之间的位置关系。利用这些信息，我们可以轻松地实现很多效果，尤其是配合另一个新 API，visualEffect 修饰符。

```swift
struct CoordinatorDemo: View {
    var body: some View {
        ScrollView {
            ForEach(0 ..< 30) { _ in
                CellView()
                    .overlay(
                        GeometryReader { proxy in
                            if let distanceFromTop = proxy.bounds(of: .scrollView)?.minY {
                                Text(distanceFromTop * -1, format: .number)
                            }
                        }
                    )
            }
        }
        .border(.blue)
        .contentMargins(30, for: .scrollContent)
    }
}
```

![scrollView_coodinatorName_demo_2023-06-12_17.28.22.2023-06-12 17_28_54](https://cdn.fatbobman.com/scrollView_coodinatorName_demo_2023-06-12_17.28.22.2023-06-12%2017_28_54.gif)

与使用 `.coordinateSpace(.named("MyScrollView"))` 设置的坐标系不同，预设的 `.scrollView` 坐标系可以正确处理 `contentMargins` 创建的 margin。

```swift
ScrollView {
    ForEach(0 ..< 30) { _ in
        CellView()
            .overlay(
                GeometryReader { proxy in
                    if let distanceFromTop = proxy.bounds(of: .named("MyScrollView"))?.minY {
                        Text(distanceFromTop * -1, format: .number)
                    }
                }
            )
    }
}
.border(.blue)
.contentMargins(30, for: .scrollContent)
// margin not recognized
.coordinateSpace(.named("MyScrollView"))
```

![image-20230612173216588](https://cdn.fatbobman.com/image-20230612173216588.png)

> `bounds(of coordinateSpace: NamedCoordinateSpace) -> CGRect?` 是今年新增的 API，用于获取指定坐标空间的边界矩形。

## scrollTransition

其实，在很多场景下，我们并不需要通过 `NamedCoordinateSpace.scrollView` 获取非常精确的位置关系。苹果为我们提供了另一个 API，可以简化上述过程。

当子视图滑入和滑出包含它的滚动视图的可视区域时，`scrollTransition` 会对该视图应用给定的过渡动画，并在不同阶段之间平滑地过渡。

目前定义了三种阶段状态（`Phase`）：

- `topLeading`: 视图滑入滚动容器的可见区域
- `identity`: 表示视图目前在可见区域中
- `bottomTrailing`: 视图滑出滚动容器的可见区域

`scrollTransition` 的 `transition` 闭包要求你返回一个符合 [VisualEffect](https://developer.apple.com/documentation/swiftui/visualeffect) 协议的类型（`VisualEffect` 协议定义了一种不影响视图布局的效果类型，苹果已经让很多 Modifier 符合了该协议）。

```swift
struct ScrollTransitionDemo: View {
    @State var clip = false
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                ForEach(0 ..< 30) { i in
                    CellView()
                        .idView(i)
                        .scrollTransition(.animated) { content, phase in
                            content
                                .scaleEffect(phase != .identity ? 0.6 : 1)
                                .opacity(phase != .identity ? 0.3 : 1)
                        }
                }
            }
            .frame(height: 300)
            .scrollClipDisabled(clip)
            Toggle("Clip", isOn: $clip)
                .padding(16)
        }
    }
}
```

![scrollTransition_demo_2023-06-12_19.19.19.2023-06-12 19_20_18](https://cdn.fatbobman.com/scrollTransition_demo_2023-06-12_19.19.19.2023-06-12%2019_20_18.gif)

> 可以将 scrollTransition 视为 NamedCoordinateSpace.scrollView 和 visualEffect（视图修饰符）的缩减版本，用于更方便地实现效果。

## 总结

我完全没有想到，在 SwiftUI 5 中，苹果对 ScrollView 进行了全面增强。值得赞赏的是，他们不仅提供了一些一直期待的功能，而且在 API 的设计和实现完成度上都非常出色。

就我个人而言，在 SwiftUI 5 中，ScrollView 的原生方案已经能够满足大多数需求，因此我们将看到更多人采用 ScrollView + LazyStack 的组合方式。


