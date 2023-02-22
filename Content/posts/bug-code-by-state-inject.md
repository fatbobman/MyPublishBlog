---
date: 2023-02-23 08:20
description: 本文将通过一段可复现的“灵异代码”，对 State 注入优化机制、模态视图（ Sheet、FullScreenCover ）内容的生成时机以及不同上下文（ 相互独立的视图树 ）之间的数据协调等问题进行探讨。
tags: SwiftUI,小题大做
title: 一段因 @State 注入机制 Bug 所产生的“灵异代码”
image: images/bug-code-by-state-inject.png
---
本文将通过一段可复现的“灵异代码”，对 State 注入优化机制、模态视图（ Sheet、FullScreenCover ）内容的生成时机以及不同上下文（ 相互独立的视图树 ）之间的数据协调等问题进行探讨。

> 可在 [此处](https://github.com/fatbobman/BlogCodes/tree/main/StateInject) 获取本文代码

## 问题

不久之前，网友 Momo6 在 [聊天室](https://discord.gg/ApqXmy5pQJ) 中咨询了如下一个 [问题](https://stackoverflow.com/questions/73110567/how-state-variables-in-swiftui-are-modified-and-rendered-in-different-views)：

![image-20230222145532644](https://cdn.fatbobman.com/image-20230222145532644.png)

在下面的代码中，如果注释掉 ContentView 中的 `Text("n = \(n)")` 代码，在按下按钮后（ n 设置为 2），fullScreenCover 视图中 Text 显示的 n 仍为 1（ 预期为 2）。如果不注释这行代码，fullScreenCover 中将显示 ` n = 2` （ 符合预期 ）。这是为什么？

```swift
struct ContentView: View {
    @State private var n = 1
    @State private var show = false
    
    var body: some View {
        VStack {
            // 如果注释掉下面这行 Text 代码
            // 在按下 Button ( n = 2 ) 后 , full-screen 中的 Text 仍显示 n = 1
            
            // Text("n = \(n)") // 解除注释，sheet 中的 Text 将显示 n = 2
            
            Button("Set n = 2") {
                n = 2
                show = true
            }
        }
        .fullScreenCover(isPresented: $show) {
            VStack {
                Text("n = \(n)") 
                Button("Close") {
                    show = false
                    print("n in fullScreenCover is", n) // 无论是否注释掉上面的 Text ，此处均打印为 2
                }
            }
        }
    }
}
```

> 为了演示清晰，我将 fullScreenCover 换成了 sheet（ 改动不影响上面所描述的现象 ）, 并为 Button 添加了 ButtonStyle。

![question_2023-02-22_15.12.26.2023-02-22 15_15_32](https://cdn.fatbobman.com/question_2023-02-22_15.12.26.2023-02-22%2015_15_32.gif)

**此处建议暂停几分钟，看看你是否能想出其中的问题所在？**

```responser
id:1
```

## 问题构成

尽管看起来有些奇怪，但 Text 的添加与否，确实将影响 Sheet 视图中的显示内容。而出现这种现象的原因则是由 State 注入的优化机制、 Sheet（ FullScreenCover ）视图的生命周期以及新建上下文等几方面共同造成的。

### State 注入的优化机制

在 SwiftUI 中，对于引用类型，开发者可以通过 @StateObject、@ObservedObject 或 @EnvironmentObject 将其注入到视图中。通过这些方式注入的依赖，无论视图的 body 中是否使用了该实例的属性，只要该实例的 `objectWillChange.send()` 方法被调用，与其关联的视图都将被强制刷新（ 重新计算 body 值 ）。

与之不同的是，针对值类型的主要注入手段 @State，SwiftUI 则为其实现了高度的优化机制（ EnvironmentValue 没有提供优化，行为与引用类型注入行为一致 ）。这意味着，即使我们在定义视图的结构体中声明了使用 @State 标注的变量，但只要 body 中没有使用该属性（ 通过 ViewBuilder 支持的语法 ），即使该属性发生变化，视图也不会刷新。

```swift
struct StateTest: View {
    @State var n = 10
    var body: some View {
        VStack {
            let _ = print("update")
            Text("Hello")
            Button("n = n + 1") {
                n += 1
                print(n)
            }
        }
    }
}
```

在下方的动图中，在 Text 中不包含 n 的情况下，即使 n 值改变，StateTest 视图的 body 也不会重新计算。当在 Text 中添加 n 的引用后，每次 n 值发生变化，都将引发视图更新。

![stateTest_2023-02-22_16.44.55.2023-02-22 16_47_35](https://cdn.fatbobman.com/stateTest_2023-02-22_16.44.55.2023-02-22%2016_47_35.gif)

通过观察加载后视图的 State 源数据，我们可以看到，State 包含一个 _wasRead 私有属性，在其与任意视图关联后，该值为 true。

![stateDump_2023-02-22_16.54.19.2023-02-22 16_56_09](https://cdn.fatbobman.com/stateDump_2023-02-22_16.54.19.2023-02-22%2016_56_09.gif)

回到我们当前的“问题”代码：

```swift
struct ContentView: View {
    @State private var n = 1
    @State private var show = false

    var body: some View {
        VStack {
            // Text("n = \(n)") // 注释掉该行后，sheet 中的 n 显示为 1（ 并非预期中的 2 ）
            Button("Set n = 2") {
                n = 2
                show = true
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $show) {
            VStack {
                Text("n = \(n)")
                Button("Close") {
                    show = false
                    print("n in fullScreenCover is", n)
                }
                .buttonStyle(.bordered)
            }
        }

    }
}
```

当我们在 ContentView 中添加了 Text 后，Button 中对 n 的修改将引发 body 重新求值，注释后则不引发求值。这也就造成了是否添加 Text（ 在 body 中引用 n ），会影响 body 能否再度求值。

### Sheet（ FullScreenCover ）视图的生命周期

或许有人会问，在 sheet 的代码中，Text 同样包含了对 n 的引用。这个引用难道不会让 n 与 ContentView 视图之间建立关联吗？

与大多数的 View Extension 和 ViewModifier 不同，在视图中，通过 `.sheet` 或 `.fullScreenCover ` 来声明的模态视图内容代码的闭包，只会在显示模态视图的时候才会被调用、解析（ 对闭包中的 View 进行求值 ）。

而其它通过视图修饰器声明的代码块，则会在主视图 body 求值时进行一定的操作：

* overlay、background 等，会在 body 求值时调用、解析（ 因为要与主视图一并显示 ）
* alert、contextMenu 等则会在 body 求值时调用（ 可以理解为创建实例 ），但只有在需要显示时才进行求值

这就是说，即使我们在 Sheet 代码块的 Text 中添加了对 n 的引用，但只要模态视图尚未显示，则 n 的 _wasRead 仍为 false（ 并没有与视图创建关联 ）。

为了演示上面的论述，我们将 Sheet 中的代码用一个符合 View 协议的结构体包装起来，以方便我们观察。

```swift
struct AnalyticsView: View {
    @State private var n = 1
    @State private var show = false

    var body: some View {
        let _ = print("Parent View update") // 主视图 body 求值
        VStack {
            // Text("n = \(n)") // 注释掉该行后，sheet 中的 n 显示为 1（ 并非预期中的 2 ）
            Button("Set n = 2") {
                n = 2
                show = true
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $show) {
            SheetInitMonitorView(show: $show, n: n)
        }
    }
}

struct AnalyticsViewPreview: PreviewProvider {
    static var previews: some View {
        AnalyticsView()
    }
}

struct SheetInitMonitorView: View {
    @Binding var show: Bool
    let n: Int
    init(show: Binding<Bool>, n: Int) {
        self._show = show
        self.n = n
        print("sheet view init") // 创建实例（ 表示 sheet 的闭包被调用 ）
    }

    var body: some View {
        let _ = print("sheet view update") // sheet 视图求值
        VStack {
            Text("n = \(n)")
            Button("Close") {
                show = false
                print("n in fullScreenCover is", n)
            }
            .buttonStyle(.bordered)
        }
    }
}
```

![SplitSheetView_2023-02-22_17.25.22.2023-02-22 17_26_04](https://cdn.fatbobman.com/SplitSheetView_2023-02-22_17.25.22.2023-02-22%2017_26_04.gif)

通过输出内容我们可以看出，在首次对 ContextView 进行求值时（ 打印 `Parent View update`），Sheet 代码块中的 SheetInitMonitorView 没有任何输出（ 意味着闭包没有被调用 ），只有在模态视图进行显示时，SwiftUI 才执行 `.sheet` 闭包中的函数，创建 Sheet 视图。

回到最初的代码：

```swift
.fullScreenCover(isPresented: $show) {
    VStack {
        Text("n = \(n)")
        Button("Close") {
            show = false
            print("n in fullScreenCover is", n) // 无论是否注释掉上面的 Text ，此处均打印为 2
        }
    }
}
```

尽管我们通过 `.fullScreenCover` 在 Text 中引用了 n , 但由于该段代码并不会在 ContextView 求值时被调用，因此也不会让 n 与 ContextView 创建关联。

> 在 ContextView 不包含 Text 的情况下，在 Sheet 显示后，n 的 _wasRead 将转变为 true（ Sheet 视图显示后，方创建关联 ）。可以通过在 Button 中添加如下代码进行查看：

```swift
Button("Set n = 2") {
    n = 2
    show = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1){ // 延迟已保证 Sheet 中的视图已完成创建
        dump(_n)
    }
}
```

### Sheet 视图的上下文

当 SwiftUI 创建并显示一个 Sheet 视图时，并非在现有的视图树上创建分支，而是新建一棵独立的视图树。也就是说 Sheet 中的视图与原有视图分别处于不同的上下文中。

> 在 SwiftUI 早期的版本中，对于分别位于不同上下文的独立的视图树，开发者需要显式为 Sheet 视图树注入环境依赖。后期版本已为开发者自动完成该注入工作。

这意味着，相较于在原有视图树上创建分支，在新上下文中重建视图树的开销更大，需要进行的工作也更多。

而 SwiftUI 为了优化效率，通常会对若干操作进行合并，并汇总在 一个 Render Loop 中执行。在合并操作的过程中，如果出现了前后顺序错误的问题，那么就会导致一些奇怪的结果。

根据本文问题代码的表现，我们基本可以推测出，在新建 Sheet 视图树的过程中，SwiftUI 在将原有视图的 State 与 Sheet 视图进行关联时，出现了顺序错乱的问题。在已经完成了对 Sheet 视图（ 对 body 求值 ）的渲染后才进行关联。如此会导致在首次渲染时，获取的未必为最新关联值。

```responser
id:1
```

## 现象分析

根据上文中介绍的内容，我们对本文代码的奇怪现象进行一个完整的梳理：

### 当 ContextView 中不包含 Text（ ContextView 没有与 n 创建关联 ）

* 程序运行，SwiftUI 对 ContextView 的 body 进行求值并渲染

* `.fullScreenCover` 的闭包此时并未被调用，但捕获了视图当前的 n 值 （ n = 1 ）

* 点击 Button 后，尽管 n 的内容发生变化，但 ContextView 的 body 并未重新求值

* 由于 show 转变为 true ，SwiftUI 开始调用 `.fullScreenCover` 的闭包，创建 Sheet 视图

  尽管 show 也是通过 State 声明的，但 show 的变化并不会导致 ContextView 重新更新。这是因为在 `.fullScreenCover` 的构造方法中，我们传递的是 show 的 projectedValue（ Binding 类型 ）

* 由于合并操作中执行顺序出现了问题，SwiftUI 在 Sheet 视图完成对 n 的关联前，率先对视图内容进行了求值（ 此时 n 为 1）并根据此值进行了渲染

* Sheet 中的 Text 显示 n = 1

* 点击 Sheet 中的 Close 按钮，执行 Button 闭包，重新获得 n 的当前值（ n = 2 ），打印值为 2

### 当 ContextView 中包含 Text （ ContextView 与 n 之间创建了关联 ）

* 程序运行，SwiftUI 对 ContextView 的 body 进行求值并渲染
* `.fullScreenCover` 的闭包此时并未被调用，但捕获了视图当前的 n 值 （ n = 1 ）
* 点击 Button 后，由于 n 值发生了变化，ContextView 重新求值（ 重新解析 DSL 代码 ）
* 在重新求值的过程中，`.fullScreenCover` 的闭包捕获了新的 n 值 （ n = 2 ）
* 创建 Sheet 视图并渲染
* 尽管在合并操作中出现先渲染后才关联的问题，但由于 `.fullScreenCover` 闭包已经毕竟捕获了新值，因此 Sheet 的 Text 显示为 n = 2

也就是说，通过添加 Text，让 ContextView 与 n 创建了关联，在 n 变化后，ContextView 进行了重新求值，从而让 `fullScreenCover` 的闭包捕获了变化后的 n 值，并呈现了预期中的结果。

## 解决方案

在了解了错误的原因后，解决并避免再次出现类似的奇怪现象已不是难事。

### 方案一、在 DSL 中进行关联，强制刷新

原代码中，通过添加 Text 为 ContextView 和 n 之间创建关联便是一个可以接受的解决方案。

另外，我们也可以通过无需增加额外显示内容的方式来创建关联：

```swift
Button("Set n = 2") {
    n = 2
    show = true
}
.buttonStyle(.bordered)
// .id(n)  
.onChange(of:n){_ in } // id 或 onChange 均可以在不添加显示内容的情况下，创建关联
```

> 在 [创建自适应高度的 Sheet 的推文](https://twitter.com/fatbobman/status/1584715584507637760?s=61&t=KMscJ8nzk9sreOXno95FIA) 中，我便使用过 id 来解决重制 Sheet 高度的问题。

### 方案二、使用 @StateObject 强制刷新

我们可以通过创建引用类型的 Source 来避免在不同上下文之间关联 State 可能出现的顺序错误。事实上，使用 @StateObject 相当于在 vm.n 发生变化后，强制视图重新计算。

```swift
struct Solution2: View {
    @StateObject var vm = VM()
    @State private var show = false

    var body: some View {
        VStack {
            Button("Set n = 2") {
                vm.n = 2
                show = true
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $show) {
            VStack {
                Text("n = \(vm.n)")
                Button("Close") {
                    show = false
                    print("n in fullScreenCover is", vm.n)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

class VM: ObservableObject {
    @Published var n = 1
}

```

### 方案三、使用 Binding 类型，重获新值

我们可以将 Binding 类型视作一个对某值的 get 和 set 方法的包装。Sheet 视图在求值时，将通过 Binding 的 get 方法，获得 n 的最新值。

> Binding 中 get 方法对应的是 ContextView 中 n 的原始地址，无需经过为 Sheet 重新注入的过程（ 可以无视顺序错误 ），因此在求值阶段便可以获得最新值

```swift
struct Solution3: View {
    @State private var n = 1
    @State private var show = false

    var body: some View {
        VStack {
            Button("Set n = 2") {
                n = 2
                show = true
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $show) {
            SheetView(show: $show, n: $n)
        }
    }
}

struct SheetView:View {
    @Binding var show:Bool
    @Binding var n:Int
    var body: some View {
        VStack {
            Text("n = \(n)")
            Button("Close") {
                show = false
                print("n in fullScreenCover is", n)
            }
            .buttonStyle(.bordered)
        }
    }
}
```

### 方案四、延迟更新数据

通过延迟修改 n 值（ 在 Sheet 视图求值并关联数据后再修改 ），强迫 Sheet 视图重新求值

```swift
struct Solution4: View {
    @State private var n = 1
    @State private var show = false

    var body: some View {
        VStack {
            Button("Set n = 2") {
                // 极小的延迟便可以达到效果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01 ){
                    n = 2
                }
                show = true
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $show) {
            VStack {
                Text("n = \(n)")
                Button("Close") {
                    show = false
                    print("n in fullScreenCover is", n)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
```

## 总结

尽管已经发展到 4.0 版本，但 SwiftUI 仍会出现一些与预期不符的行为。在面对这些“灵异现象”时，如果我们能对其进行更多的研究，那么不仅可以在今后避免类似的问题，而且在分析的过程中，也能对 SwiftUI 的各种运行机制有深入的掌握。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**