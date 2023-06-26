---
date: 2023-06-27 08:12
description: SwiftUI 因其简便的动画 API 与极低的动画设计门槛而广受欢迎。但是，随着应用程序的复杂性增加，开发者会逐渐发现，尽管动画设计变得前所未有的简单，但要实现精确细致的动画控制并非易事。同时，在 SwiftUI 的动画系统中，Transaction 始终有点像谜一样的存在。无论是官方资料还是第三方文章，都很少对其运作机制进行系统的阐述。本文将通过探讨 Transaction 的原理、作用、创建和分发逻辑等内容，告诉读者如何在 SwiftUI 中实现更加精确的动画控制，以及需要注意的其他问题。
tags: SwiftUI
title: 掌握 Transaction，实现 SwiftUI 动画的精准控制
image: images/mastring-transaction.png
---
SwiftUI 因其简便的动画 API 与极低的动画设计门槛而广受欢迎。但是，随着应用程序复杂性的增加，开发者逐渐发现，尽管动画设计十分简单，但要实现精确细致的动画控制并非易事。同时，在 SwiftUI 的动画系统中，有关 Transaction 的解释很少，无论是官方资料还是第三方文章，都没有对其运作机制进行系统的阐述。

本文将通过探讨 Transaction 的原理、作用、创建和分发逻辑等内容，告诉读者如何在 SwiftUI 中实现更加精准的动画控制，以及需要注意的其他问题。

## Transaction 是什么

- transaction 是一个值，包含了 SwiftUI 在处理当前状态变化时需要了解的上下文，其中最重要的是用于计算插值的动画函数。
- 与环境值有些类似，SwiftUI 会在视图层次结构中隐式向下传播 transaction。
- 所谓的“显式动画”和“隐式动画”的核心区别在于生成 transaction 和派发 transaction 的位置和逻辑不同。
- transaction 只与当前的状态变化有关。每当状态发生变化时，SwiftUI 会根据是否由“显式动画”发起或是否有声明”隐式动画”等情况按需生成新的 transaction，并在需要的视图层次中进行传递。
- 下游的 transaction 生成者（`.animation`、`.transaction`）将根据设置选择是否采用上游分发的 transaction 或生成新的 transaction。
- 在状态变化时，与当前变化状态有关联的可动画组件（通常遵守 Animatable 协议）将获取本次状态变化的上下文（transaction），得到动画曲线函数，并使用它来计算插值。
- transaction 并不能单独生成或派发，它是状态变化的附带信息。

我相信，很多读者在看完上述对 transaction 的描述后仍然会感到困惑。因此，在接下来的内容中，我们将更详细地介绍和阐述 transaction 的细节和实现，帮助你更好地理解。

```responser
id:1
```

## 如何观察 Transaction 的变化

通过 `.transaction` 视图修饰器，我们可以创建一个工具，以帮助我们更好地研究和理解 transaction。

```swift
extension View {
    @ViewBuilder
    func transactionMonitor(_ title: String, _ showAnimation: Bool = true) -> some View {
        transaction {
            print(title, terminator: showAnimation ? ": " : "\n")
            if showAnimation {
                print($0.animation ?? "nil")
            }
        }
    }
}
```

## 什么是隐式动画

隐式动画是通过 `.animation` 或 `.transaction`（通常使用 `.animation`）修饰器，在视图分支上声明在状态变化时应该创建的 transaction。

SwiftUI 会在以下情况下调用隐式动画创建 transaction：

- 当前视图分支在状态变化时会发生变化
- 当前视图分支上声明了隐式动画

下面的代码将展示隐式动画是如何创建 transaction 并向下传递的：

```swift
struct ImplicitAnimationDemo: View {
    @State private var isActive = false
    var body: some View {
        VStack {
            Text("Hello")
                .font(.largeTitle)
                .offset(x: isActive ? 200 : 0)
                .transactionMonitor("inner")
                .animation(.smooth, value: isActive)
                .transactionMonitor("outer")

            Text("World")
                .transactionMonitor("world")

            Toggle("Active", isOn: $isActive)
                .padding()
        }
        .transactionMonitor("VStack")
        .animation(.linear, value: isActive)
    }
}
```

![implicit-animation-demo1_2023-06-25_15.43.04.2023-06-25 15_43_40.gif](https://cdn.fatbobman.com/implicit-animation-demo1_2023-06-25_15.43.04.2023-06-25_15_43_40.gif)

输出为：

```bash
VStack: BezierAnimation(duration: 0.35, curve: SwiftUI.UnitCurve.CubicSolver(ax: -2.0, bx: 3.0, cx: 0.0, ay: -2.0, by: 3.0, cy: 0.0))
outer: BezierAnimation(duration: 0.35, curve: SwiftUI.UnitCurve.CubicSolver(ax: -2.0, bx: 3.0, cx: 0.0, ay: -2.0, by: 3.0, cy: 0.0))
inner: FluidSpringAnimation(response: 0.5, dampingFraction: 1.0, blendDuration: 0.0)
VStack: nil
outer: nil
```

- 通过 Toggle 调整 isActive，应用的状态发生了变化。
- SwiftUI 发现 `Text("Hello")` 和包裹它的 `VStack` 两个视图链会在状态变化时发生变化。
- `VStack` 通过 `.animation` 声明了在 `isActive` 变化时应创建的 transaction（动画函数为 `linear`）。
- `Text("Hello")` 通过 `.animation` 声明了在 `isActive` 变化时应创建的 transaction（动画函数为 `smooth`）。
- SwiftUI 调用 `VStack` 的 `.animation` 创建了新的 transaction，并向下传递。通过 VStack 和 outer 的输出信息可以看到获得了对应的值。
- SwiftUI 调用 `Text("Hello")` 的 `.animation` 创建了新的 transaction，并向下传递，该 transaction 替换了 VStack 向下传递的 transaction（ 查看 inner 的输出信息 ）。
- 在状态变化结束后，SwiftUI 重置了 `VStack` 和 `Text("Hello")` 外侧的 transaction（nil）。

几点提示：

- SwiftUI 可能会在应用初始阶段为部分视图设置 transaction（ 值为 nil ），即使没有设置，也不影响视图在状态变化时获取正确的 transaction。
- SwiftUI 可能会在状态改变后为部分视图重置 transaction（ 值为 nil ），即使没有重置，也不影响下次的动画（ 下次状态变化时，会生成新的 transaction ）。
- 当传递进来的 transaction 为 nil 时，SwiftUI 会优化调用 `.transaction` 修饰器闭包的时机。如果没有在闭包中修改 transaction，可能会忽略该闭包（ 不调用 ）。

## `.animation` 和 `.transaction` 有什么不同

`.animation` 修饰器是 `.transaction` 修饰器的快捷方式。同样，用于“显式动画”的 `withAnimation` 则是 `withTransaction` 的快捷方式。

例如，我们可以通过下面的代码为 iOS 13 创建与特定值关联的 `.animation` 修饰器版本。

```swift
extension View {
    func myAnimation<V>(_ animation: Animation?, value: V) -> some View where V: Equatable {
        modifier(MyAnimationWithValueModifier(animation: animation, value: value))
    }
}

struct MyAnimationWithValueModifier<V>: ViewModifier where V: Equatable {
    @State private var holder: Holder
    private let value: V
    private let animation: Animation?
    init(animation: Animation?, value: V) {
        self.animation = animation
        self.value = value
        _holder = State(wrappedValue: Holder(value: value))
    }

    func body(content: Content) -> some View {
        content
            .transaction { transaction in
                guard value != holder.value else { return }
                holder.value = value
                guard !transaction.disablesAnimations else { return }
                transaction.animation = animation
            }
            .onAppear {} // Fixed the issue where the animation was not playing correctly on its first execution.
    }

    class Holder {
        var value: V
        init(value: V) {
            self.value = value
        }
    }
}
```

代码提示：

- 保存要比较的值。
- 当关联的值发生变化时，更新保存的值。
- 检查上游的 transaction 的 disablesAnimations 属性，以判断是否用新的 transaction 替代上游的 transaction（有关 disablesAnimations，下文有更多说明）。
- onAppear 是用来保证第一次设置便起作用（解决 SwiftUI 的 Bug）。

使用方法和效果与 SwiftUI 官方版本 `animation<V>(_ animation: Animation?, value: V)` 完全一致。

## 使用与特定值关联的 `.animation` 修饰器版本，就可以避免动画的异常问题了吗？

并不是。

在最初的版本中，SwiftUI 只提供了一个版本的 `.animation`。它会在当前视图链发生变化时创建 transaction，而不关心该变化是否由特定的关联值所导致。

后来提供的具备关联值版本的修饰器（类似于上面的自定义版本），将保证只在特定关联值发生变化时才创建 transaction，但如果使用不当，仍会出现问题。

例如，我们想要创建一个矩形。当 isActive 为 true 时，通过动画更改颜色；当 scale 为 true 时，不使用动画进行缩放。

```swift
struct ImplicitAnimationBugDemo: View {
    @State private var isActive = false
    @State private var scale = false
    var body: some View {
        VStack {
            Rectangle()
                .fill(isActive ? .red : .blue)
                .frame(width: 200, height: 200)
                .scaleEffect(scale ? 1.5 : 1.0)
                .animation(.smooth, value: isActive)

            Button("Change") {
                isActive.toggle()
                scale.toggle()
            }
        }
    }
}
```

执行上面的代码后，我们会发现，尽管 `.animation` 仅在 `isActive` 发生变化时才创建 transaction，但由于 `isActive` 和 `scale` 在同一个状态变化周期内都发生了改变，因此 `scaleEffect` 同样会使用该 transaction，并没有达到我们想要的效果。

![implicit-animtion-bug-demo1_2023-06-25_18.03.24.2023-06-25 18_04_05.gif](https://cdn.fatbobman.com/implicit-animtion-bug-demo1_2023-06-25_18.03.24.2023-06-25_18_04_05.gif)

解决方法很简单，只需调整`.animation`的位置，使需要动画的组件获取到正确的 transaction 即可。

```swift
Rectangle()
    .fill(isActive ? .red : .blue)
    .animation(.smooth, value: isActive) // move animation modifier
    .frame(width: 200, height: 200)
    .scaleEffect(scale ? 1.5 : 1.0)
```

![implicit-animation-bug-demo2_2023-06-25_18.05.24.2023-06-25 18_06_02.gif](https://cdn.fatbobman.com/implicit-animation-bug-demo2_2023-06-25_18.05.24.2023-06-25_18_06_02.gif)

当然，我们也可以为不同的可动画组件设置不同的 transition。

```swift
Rectangle()
    .fill(isActive ? .red : .blue)
    .animation(.smooth(duration: 0.2), value: isActive)
    .frame(width: 200, height: 200)
    .scaleEffect(scale ? 1.5 : 1.0)
    .animation(.bouncy(duration: 2), value: scale)
```

![implict-animtion-bug-demo3_2023-06-25_18.08.16.2023-06-25 18_09_07.gif](https://cdn.fatbobman.com/implict-animtion-bug-demo3_2023-06-25_18.08.16.2023-06-25_18_09_07.gif)

**需要注意！在 SwiftUI 中，某些可动画组件存在获取 transaction 的 Bug**。如果我们将 scaleEffect 替换为 offset，就无法实现与上面相同的效果：不同的动画组件应用不同的 transaction。

理论上，使用以下代码进行平移操作时不应该带有动画效果。

```swift
struct ImplicitAnimationBugDemo: View {
    @State private var isActive = false
    @State private var scale = false
    var body: some View {
        VStack {
            Rectangle()
                .fill(isActive ? .red : .blue)
                .animation(.smooth, value: isActive)
                .frame(width: 200, height: 200)
                .offset(x: scale ? 200 : 0) // change scaleEffect to offset
                .animation(.none, value: scale)

            Button("Change") {
                isActive.toggle()
                scale.toggle()
            }
        }
    }
}
```

![implicit-animtion-bug-demo4_2023-06-25_18.13.37.2023-06-25 18_14_16.gif](https://cdn.fatbobman.com/implicit-animtion-bug-demo4_2023-06-25_18.13.37.2023-06-25_18_14_16.gif)

**面对 `offset` 不听话这样的情况该怎么办！**

还记得 transaction 的派发原理吗？如果我们将 isActive 和 scale 的变化分开（改为两次状态调整），那么不同的可动画组件就可以获取到正确的 transaction 了。

```swift
Button("Change") {
    isActive.toggle()
	  // Adjust one-time state change to two-time state change
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01){
        scale.toggle()
    }
}
```

这是因为，在第一次状态变化时（isActive），`fill` 将获得由 `animation(.smooth, value: isActive)` 创建的 transaction。而在第二次状态变化时，`fill` 已经完成了状态变化（动画进行中），它不需要再次获取 transaction。`offset` 则获取了由 `animation(.none, value: scale)` 生成的 transaction。我们通过这种方式解决了 `offset` 无法正确获取 transaction 的 Bug。

## 新的隐式动画声明方式在 WWDC 2023 中被宣布

在 WWDC 2023 中，苹果为 SwiftUI 增加了新的 `animation` 和 `transaction` 版本。

```swift
struct ImplicitAnimationNewVersionDemo: View {
    @State private var isActive = false
    @State private var scale = false
    var body: some View {
        VStack {
            Rectangle()
                .animation(.smooth) {
                    $0.foregroundStyle(isActive ? Color.red : Color.blue)
                }
                .frame(width: 200, height: 200)
                .transaction {
                    $0.animation = .none
                } body: {
                    $0.scaleEffect(scale ? 1.5 : 1)
                }

            Button("Change") {
                isActive.toggle()
                scale.toggle()
            }
        }
    }
}
```

与之前的版本相比，新版的 `animation` 和 `transaction` 会将新创建的 transaction 仅应用于闭包内部。这样一来，上游传来的 transaction 将按照原样沿视图链继续传递，从而保证开发者的动画意图被正确地传递下去。

> 截止到 Xcode 15 beta 2，新版本的修饰符还无法正常工作。
> 

## 什么是显式动画

在视图中，通过 `animation` 或 `transaction` 修饰器声明的 transaction 被称为“隐式动画”。使用命令式编程的手段，通过全局函数 `withAnimation` 或 `withTransaction` 创建 transaction 的方式则被称为“显式动画”。

相较于“隐式动画”，“显式动画”有以下不同之处：

- 无论在何处执行 `withAnimation` 函数，SwiftUI 都将从根视图开始派发“显式动画”创建的 transaction
- 当状态发生变化时，SwiftUI 会自动为所有受影响的视图分发 transaction

要创建显式动画，请按照以下方式进行：

```swift
@main
struct TransactionApp: App {
    var body: some Scene {
        WindowGroup {
            ExplicitAnimationDemo()
                .transactionMonitor("App")
        }
    }
}

struct ExplicitAnimationDemo: View {
    var body: some View {
        VStack {
            Text("Hello World")
                .transactionMonitor("Hello World")
            SubView()
                .transactionMonitor("SubView")
        }
        .transactionMonitor("VStack")
    }
}

struct SubView: View {
    @State private var isActive = false
    var body: some View {
        Rectangle()
            .fill(.cyan)
            .frame(width: 300, height: isActive ? 400 : 200)
            .transactionMonitor("Rectangle")

        Button("Active") {
            withAnimation(.smooth) {
                isActive.toggle()
            }
        }
    }
}
```

输出为：

```bash
App: FluidSpringAnimation(response: 0.5, dampingFraction: 1.0, blendDuration: 0.0)
VStack: FluidSpringAnimation(response: 0.5, dampingFraction: 1.0, blendDuration: 0.0)
SubView: FluidSpringAnimation(response: 0.5, dampingFraction: 1.0, blendDuration: 0.0)
Rectangle: FluidSpringAnimation(response: 0.5, dampingFraction: 1.0, blendDuration: 0.0)
Hello World: FluidSpringAnimation(response: 0.5, dampingFraction: 1.0, blendDuration: 0.0)
App: nil
VStack: nil
SubView: nil
```

![explicit-animtion-demo1_2023-06-25_19.45.37.2023-06-25 19_46_57.gif](https://cdn.fatbobman.com/explicit-animtion-demo1_2023-06-25_19.45.37.2023-06-25_19_46_57.gif)

也许有人会想知道，为什么几乎所有的视图分支都被重新派发了 transaction，SwiftUI 是根据什么来决定哪些视图分支要派发“显式动画”创建的 transaction。

根据我的测试，SwiftUI 将为所有在本次状态变化时（ `withAnimation` 闭包引发）发生**视觉变化**的视图分支派发 transaction。

例如，上面代码中的 `Text("Hello World")`，由于在 `isActive` 发生变化后，它的位置也将改变，因此，该分支也将被派发 transaction。另外，所有的 Button，无论是否发生变化，都将被派发 transaction（ 感觉上像 Bug ）。

通过修改代码，我们可以让 `Text("Hello World")` 在 `isActive` 变化后，不改变其位置：

```swift
struct SubView: View {
    @State private var isActive = false
    var body: some View {
        Rectangle()
            .fill(.cyan)
            .frame(width: 300, height: isActive ? 400 : 200)
            .transactionMonitor("Rectangle")
        Spacer() // add Spacer()
        Button("Active") {
            withAnimation(.smooth) {
                isActive.toggle()
            }
        }
    }
}
```

输出：

```bash
App: FluidSpringAnimation(response: 0.5, dampingFraction: 1.0, blendDuration: 0.0)
VStack: FluidSpringAnimation(response: 0.5, dampingFraction: 1.0, blendDuration: 0.0)
SubView: FluidSpringAnimation(response: 0.5, dampingFraction: 1.0, blendDuration: 0.0)
Rectangle: FluidSpringAnimation(response: 0.5, dampingFraction: 1.0, blendDuration: 0.0)
App: nil
VStack: nil
SubView: nil
```

![explicit-animation-demo2_2023-06-25_19.54.17.2023-06-25 19_55_23.gif](https://cdn.fatbobman.com/explicit-animation-demo2_2023-06-25_19.54.17.2023-06-25_19_55_23.gif)

通过添加 Spacer，我们可以确保 `Text("Hello world")` 的位置不会受到状态变化的影响。这样，SwiftUI 就不会为 `Text("Hello World")` 分发 transaction 了。

## 显式动画可以和隐式动画合作吗

可以。

开发者可以通过在“显式动画”派发的视图分支上声明“隐式动画”的方式，来改变局部的 transaction。

```swift
struct SubView: View {
    @State private var isActive = false
    var body: some View {
        Rectangle()
            .fill(.cyan)
            .frame(width: 300, height: isActive ? 400 : 200)
            .animation(.bouncy, value: isActive) // bouncy will replace smooth

        Button("Active") {
            withAnimation(.smooth) {
                isActive.toggle()
            }
        }
    }
}
```

```responser
id:1
```

## 用显式动画覆盖隐式动画

相较于“隐式动画”，“显式动画”需要在更多、更深的视图分支和层级上派发 transaction。因此，理论上来说，为了达到相同的动画效果，“显式动画”的运行效率要低一点。

然而，在某些特定情况下，使用“显式动画”会更方便，例如：通过显式动画来覆盖隐式动画。

还记得上文中我们自定义的 `animation` 修饰器实现吗？在这个实现中，修饰器会判断上游 transaction 的 `disablesAnimations` 属性。如果该属性为 `true`，则不创建新的 transaction。

这个自定义实现完全仿照了 SwiftUI 提供的 `animation` 修饰器的实现逻辑。

```swift
struct CoverImplicitAnimationDemo: View {
    @State var isActive = false
    var body: some View {
        VStack {
            Rectangle()
                .fill(isActive ? .red : .blue)
                .frame(width: 300, height: 300)
                .animation(.smooth, value: isActive)

            Button("Cover ImplicitAnimation") {
                var transaction = Transaction(animation: .none)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    isActive.toggle()
                }
            }
        }
    }
}
```

![explicit-cover-implicit-demo_2023-06-25_20.52.34.2023-06-25 20_53_36.gif](https://cdn.fatbobman.com/explicit-cover-implicit-demo_2023-06-25_20.52.34.2023-06-25_20_53_36.gif)

虽然我们使用了“隐式动画”来为 `fill` 声明了 transaction，但是通过“显式动画”，我们创建并派发了一个 `disablesAnimations` 属性为 `true` 的 transaction。这样，`animation` 修饰符将不再创建新的 transaction（smooth）。

 `animation` 修饰符会判断 `disablesAnimations` 属性，而 `transaction` 修饰符需要开发者自行决定采用何种逻辑。

## 利用显示动画的 diff 和自动分发 Transaction 的能力

大家是否会有些奇怪，为什么“显式动画”要对所有受影响的视图分发 transaction 呢？事实上，这也是在某些情况下，“显式动画”的另一个优势。

我们将上面“显式动画”与“隐式动画”合作的代码，改成纯“隐式动画”（去掉 withAnimation）的实现：

```swift
struct ExplicitAnimationDemo: View {
    var body: some View {
        VStack {
            Text("Hello World")
            SubView()
        }
    }
}

struct SubView: View {
    @State private var isActive = false
    var body: some View {
        Rectangle()
            .fill(.cyan)
            .frame(width: 300, height: isActive ? 400 : 200)
            .animation(.bouncy, value: isActive)

        Button("Active") {
            isActive.toggle()
        }
    }
}
```

![implicit-bug-demo5_2023-06-26_07.04.36.2023-06-26 07_05_36.gif](https://cdn.fatbobman.com/implicit-bug-demo5_2023-06-26_07.04.36.2023-06-26_07_05_36.gif)

请注意，上图中，“Hello World” 的位移没有动画。

这是因为在上面的代码中，没有为 SubView 外面的 VStack 声明“隐式动画”。因此，当 Rectangle 的尺寸增大时，VStack 会调整布局。但由于没有找到对应的 transaction，此布局调整的过程是非动画的。从而导致了这种情况。使用“显式动画”，SwiftUI 将自动为 VStack 派发 transaction。

当然，如果我们可以调整数据源的位置，那么 “隐式动画” 同样可以避免上面的情况。

```swift
struct ExplicitAnimationDemo: View {
    @State private var isActive = false // source of truth
    var body: some View {
        VStack {
            Text("Hello World")
                .transactionMonitor("Hello World")
            SubView(isActive: $isActive)
                .transactionMonitor("SubView")
        }
        .animation(.bouncy, value: isActive) // implicit aniamtion for VStack
    }
}

struct SubView: View {
    @Binding var isActive: Bool
    var body: some View {
        Rectangle()
            .fill(.cyan)
            .frame(width: 300, height: isActive ? 400 : 200)
            .animation(.bouncy, value: isActive)

        Button("Active") {
            isActive.toggle()
        }
    }
}
```

在这种情况下，“显式动画”确实比“隐式动画”更方便。但是，过多的 transaction 派发也可能产生不必要的动画。通过将“显式动画”和“隐式动画”结合起来使用，才能更精确地控制动画效果。

## 使用显式动画屏蔽系统组件动画

在 iOS 17 中，SwiftUI 会让大多数系统组件（如 Sheet、FullScreeCover、NavigationStack、Inspector 等）在实现动画时，首先检查来自上游 transaction 的 `disablesAnimations` 属性。开发者终于可以用纯 SwiftUI 的方式来决定是否在这些组件的切换过程中使用动画了。

NavigationStack:

```swift
struct NavigationStackDemo: View {
    @State var pathStore = PathStore()
    var body: some View {
        @Bindable var pathStore = pathStore
        NavigationStack(path: $pathStore.path) {
            List {
                Button("Go Link without Animation") {
                    var transaction = Transaction(animation: .none)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        pathStore.path.append(1)
                    }
                }
                Button("Go Link with Animation") {
                    pathStore.path.append(1)
                }
            }
            .navigationDestination(for: Int.self) {
                ChildView(store: pathStore, n: $0)
            }
        }
    }
}

@Observable
class PathStore {
    var path: [Int] = []
}

struct ChildView: View {
    let store: PathStore
    let n: Int
    @Environment(\.dismiss) var dismiss
    var body: some View {
        List {
            Text("\(n)")
            Button("Dismiss without Animation") {
                var transaction = Transaction(animation: .none)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    store.path = []
                }
            }
            Button("Dismiss with Animation") {
                dismiss()
            }
        }
    }
}
```

![disable-animation-demo1_2023-06-26_08.55.59.2023-06-26 08_56_52.gif](https://cdn.fatbobman.com/disable-animation-demo1_2023-06-26_08.55.59.2023-06-26_08_56_52.gif)

Sheet:

```swift
struct SheetDemo: View {
    @State private var isActive = false
    var body: some View {
        List {
            Button("Pop Sheet without Animation") {
                var transaction = Transaction(animation: .none)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    isActive.toggle()
                }
            }
            Button("Pop Sheet with Animation") {
                isActive.toggle()
            }
        }
        .sheet(isPresented: $isActive) {
            VStack {
                Button("Dismiss without Animation") {
                    var transaction = Transaction(animation: .none)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        isActive.toggle()
                    }
                }
                Button("Dismiss with Animation") {
                    isActive.toggle()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
```

![disable-aniamtion-demo2_2023-06-26_09.02.07.2023-06-26 09_03_12.gif](https://cdn.fatbobman.com/disable-aniamtion-demo2_2023-06-26_09.02.07.2023-06-26_09_03_12.gif)

## 可动画组件如何获取 Transaction

SwiftUI 会自动帮助符合 Animatable 协议的可动画组件获取 transaction，并计算插值。

如果你使用例如 UIViewRepresentable 的方式对 UIKit 或 AppKit 组件进行包装，则可以在 `update` 方法中获取当前的 transaction。这样就能保证在每次状态发生变化时都能获取正确的上下文信息。

```swift
struct MyView:UIViewRepresentable {
    @Binding var isActive:Bool
    func makeUIView(context: Context) -> some UIView {
        return UIView()
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        let transaction = context.transaction
        // check animation
        // do something
    }
}
```

> 在 WWDC 2023 中，苹果为 Animation 添加了新的方法，可以帮助开发者获取在特定时间点对应的值。
> 

## 支持设置 Transaction 或 Animation 的组件

在 SwiftUI 中，一些组件或类型允许开发者为其设置 transaction 或 animation，例如：Binding、FetchRequest 等。开发者应根据需要选择是否采用其内置的动画设置。

例如，对于 FetchRequest，我们可以通过三种方式来控制其在数据增加或删除时是否采用动画效果。

```swift
// Solution 1
@FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
    animation: .none  // animation
)

// Soulution 2
List {
    ForEach(items) { item in
       ....
    }
    .onDelete(perform: deleteItems)
}
.animation(.bouncy, value: items.count) // animation

// Solution 3
withAnimation {
   addNewItem()
}

withAniamtion {
    delItem()
}
```

使用后两种方法，开发者将拥有更强的动画控制力。

```responser
id:1
```

## TransactionKey

在 WWDC 2023 上，苹果为 SwiftUI 添加了 TransactionKey。这允许开发者在 transaction 中携带一些自定义信息。

创建 TransactionKey 的方式与 EnvironmentKey 十分相似。

```swift
enum TapSource {
    case root
    case welcome
    case other

    var animation: Animation? {
        switch self {
        case .root:
            Animation.smooth(duration: 3)
        case .welcome:
            nil
        case .other:
            Animation.linear
        }
    }
}

struct SourceKey: TransactionKey {
    static var defaultValue: TapSource = .root
}

extension Transaction {
    var source: TapSource {
        get { self[SourceKey.self] }
        set { self[SourceKey.self] = newValue }
    }
}
```

使用方法：

```swift
@Observable
class Store {
    var isActive = false
}

struct KeyDemo: View {
    @State private var store = Store()
    var body: some View {
        VStack {
            Rectangle()
                .fill(store.isActive ? .orange : .cyan)
                .frame(width: 300, height: 300)
                .transaction {
                    $0.animation = $0[SourceKey.self].animation
                }

            RootView(store: store)
            WelcomeView(store: store)
        }
    }
}

struct RootView: View {
    let store: Store
    var body: some View {
        Button("From Root") {
            withTransaction(\.source, .root) {
                store.isActive.toggle()
            }
        }
    }
}

struct WelcomeView: View {
    let store: Store
    var body: some View {
        Button("From Welcome") {
            withTransaction(\.source, .welcome) {
                store.isActive.toggle()
            }
        }
    }
}
```

![transactionKey-demo_2023-06-25_21.07.29.2023-06-25 21_08_28.gif](https://cdn.fatbobman.com/transactionKey-demo_2023-06-25_21.07.29.2023-06-25_21_08_28.gif)

> 请阅读 [深度解读 Observation —— SwiftUI 性能提升的新途径](https://www.fatbobman.com/posts/mastering-Observation/) 一文，了解 `@Observable` 的具体用法。
> 

## 实现精准动画的一些建议

- 在需要使用动画的可动画组件附近声明“隐式动画”。
- 可能的情况下，使用新的“隐式动画”声明方法。
- 在同样的效果下，优先使用“隐式动画”。
- 在使用“显式动画”时，通过在局部声明“隐式动画”来避免部分视图出现动画异常。
- 在需要的情况下，可以通过 TransactionKey 提供更丰富的上下文信息
- 尽量不在一次状态改变中修改过多的属性。
- 出现动画异常时，应首先明确异常部位在状态变化时所获取到的 transaction。
- 对可动画部件要有明确的理解，除了支持动画的修饰器外，布局容器也是。
- 在包装 UIKit 或 AppKit 控件时，应添加检查当前 transaction 的逻辑。
- 在 iOS 17 中，更多的导航组件已支持通过使用“显式动画”来屏蔽动画转场。

## 最后

本文着重介绍 transaction 的创建和派发机制，对于 transaction 中的其他属性没有进行更多的讨论。无论 SwiftUI 未来为 transaction 添加多少信息，只要我们掌握了其原理，就能实现高效精准的动画。在出现预期之外的动画行为时，开发者也知道该如何调整。

欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周最新文章。**