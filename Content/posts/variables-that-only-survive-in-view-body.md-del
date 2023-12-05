---
date: 2023-03-22 08:12
description: 本文将探讨在 SwiftUI 的视图 body 中用 var 来创建变量的意义和可能的场景。相信不少开发者都会在视图中使用过 let _ = print("update")，通过打印的信息，可以让我们了解视图的 body 被调用的时机、原因，并大致地了解次数。但很少有人会在 body 中去使用 `var` 来定义变量，因为实在找不到使用 `var` 的理由和意义。
tags: SwiftUI
title: 只在视图 Body 中生存的变量
image: images/variables-that-only-survive-in-view-body.png
---
SwiftUI 通过调用视图实例的 body 属性来获取视图值。在 View 协议中，body 被属性包装器 @ViewBuilder 所标注，这意味着，通常我们只能在 body 中使用 ViewBuilder 认可的 Expression 来声明视图（ 如果显式使用 return ，虽然可以避开 ViewBuilder 的限制，但因受只能返回一种类型的限制，影响视图的表达能力 ）。

不过 ViewBuilder 却允许开发者可以通过 `let` 或 `var` 在视图声明中定义常量或变量，它们具体有什么作用呢？

相信不少开发者都会在视图中用下面的形式使用过 `let`：

```swift
VStack {
  let _ = print("update") // 或 let = Self._pringChanges()
  Text("hello")
}
```

通过打印的信息，可以让我们了解视图的 body 被调用的时机、原因，并大致地了解次数。但很少有人会在 body 中去使用 `var` 来定义变量，因为实在找不到使用 `var` 的理由和意义。本文将探讨在 SwiftUI 的视图 body 中用 var 来创建变量的意义和可能的场景。

## 意义

严格来说，本文接下来介绍的两个场景，都有其他的替代方案（ 无需在 body 中创建变量 ）。不过就和通过 `let _ = print("update")` 能够帮助我们了解视图的动态一样，掌握了在 body 中通过 `var` 创建变量及应用的方法，也将**有助于开发者更好地理解 SwiftUI 视图的求值逻辑并掌握其时机**。

## 场景一

前几天在 [聊天室](https://discord.gg/ApqXmy5pQJ) 中有这个一个讨论：

![image-20230321195140004](https://cdn.fatbobman.com/image-20230321195140004.png)

由于 @FetchRequest 的返回类型 FetchedResults 并不支持索引，因此为了给每个对象添加一个序号，通常会使用将 FetchResults 进行枚举化再转成数组的方式来处理：

```swift
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default
    )
    private var items: FetchedResults<Item>

    var body: some View {
        VStak {
            // 两次转换
            ForEach(Array(items.enumerated()), id: \.element) { offset, item in
                Text("\(offset) : \((item.timestamp ?? .now).formatted(.iso8601))")
            }
        }
    }
}
```

![image-20230321201604435](https://cdn.fatbobman.com/image-20230321201604435.png)

每次有数据发生变化时，都要重复上面的转换工作，如果数据量很大，还是会对性能造成一定的影响的。在此种情况下，在 body 中使用 `var` 来声明一个变量，或许会有意想不到的效果。

```swift
var body: some View {
        VStack {
            var offset = 0
            ForEach(items) { item in
                let _ = offset += 1 // 通过 let _ 来执行命令
                Text("\(offset) : \((item.timestamp ?? .now).formatted(.iso8601))")
            }
        }
    }
```

![image-20230321201625852](https://cdn.fatbobman.com/image-20230321201625852.png)

？？ 为什么和想象的不一样！起始点不是 0 ？

同我们不要去推断在一个视图的存续期内，SwiftUI 会创建多少个该视图的实例一样，我们也不应假设，在渲染第一行数据之前，body 没有被调用过。

> 在本例中，渲染成我们看到的首行数据之前， offset 已被调用过 14 次，与当前的数据量（ 13 ）非常接近。FetchRequest 导致了上述的重复调用。在数据变化时（包括首次提取数据），FetchRequest 会根据数据量向视图发送更新信号（可通过 onRecevie 来验证）

虽然不能假设，但我们可以通过下面的方法，让 offset 的数据，在首行获得重置：

```swift
VStack {
    var offset = 0
    ForEach(items) { item in
        // 判断当前是否为首个数据
        let _ = offset = item.objectID == items.first?.objectID ? 0 : offset + 1
        Text("\(offset) : \((item.timestamp ?? .now).formatted(.iso8601))")
    }
}
```

通过 `item.objectID == items.first?.objectID` ，我们在首行重置了 offset 数据，得到了想要的结果。

![image-20230321203001315](https://cdn.fatbobman.com/image-20230321203001315.png)

假如，我们将 VStack 换成 List 或 LazyVStack 呢？

```swift
List { // LazyVStack 或其他惰性容器
    var offset = 0
    ForEach(items) { item in
        // 判断当前是否为首个数据
        let _ = offset = item.objectID == items.first?.objectID ? 0 : offset + 1
        Text("\(offset) : \((item.timestamp ?? .now).formatted(.iso8601))")
    }
}
```

![image-20230321203100103](https://cdn.fatbobman.com/image-20230321203100103.png)

每行都被计算过两次。在 SwiftUI 所有的惰性容器中，都会出现计算两次的情况（ 或许与惰性容器的视图值保存机制有关 ），这就要求我们为了得到正确的 offset 值必须进行除 2 的操作。

```swift
List { // 或 LazyVStack
    var offset = 0
    ForEach(items) { item in
        // 判断当前是否为首个数据
        let _ = offset = item.objectID == items.first?.objectID ? 0 : offset + 1
        Text("\(offset / 2) : \((item.timestamp ?? .now).formatted(.iso8601))") // offset / 2
    }
}
```

尽管相较 enumerated 方案，当前的方法对使用者的要求更高、代码也更难阅读，不过，一旦你能掌握其规律，将获得更多的性能优势。

> 这并不意味着我推荐本节介绍的方法，在日常使用中，除非真的出现了不可调和的性能问题，enumerated 仍是最符合直觉的解决之道。

即使不在 body 中通过 `var` 来声明变量，我们同样可以通过使用一个引用类型实例来达成同样的效果：

> 必须用 @State 来持有该实例，如此才能保证在视图的存续期内，只有一个 holder

```swift
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default
    )
    private var items: FetchedResults<Item>
    // 必须用 @State 来持有该实例，如此才能保证在视图的存续期内，只有一个 holder
    @State var holder = Holder() 
    
    var body: some View {
        List {
            ForEach(items) { item in
                let _ = holder.offset = item.objectID == items.first?.objectID ? 0 : holder.offset + 1
                Text("\(holder.offset / 2) : \((item.timestamp ?? .now).formatted(.iso8601))")
            }
        }
    }
}

final class Holder {
    var offset = 0
}
```

## 场景二

Swift 5.8 取消了结果构建器中对变量的所有限制，让我们可以直接在结果生成器中使用惰性变量。

```swift
struct LazyDemo:View {
    var body: some View {
        VStack {
            lazy var name = LargeCalculationResults()
            Text("Hello, \(name).")
        }
    }
    
    func LargeCalculationResults() -> String {
        "text" // 假设经过大量计算
    }
}
```

这意味着，name 仅在 SwiftUI 对该 body 进行首次求值时才进行赋值（ 通过 LargeCalculationResults 获取结果 ），减轻了之后的求值计算压力。

即使没有 Swift 5.8 的改进，我们一样可以利用场景一的替代方案来支持惰性变量：

```swift
struct LazyDemo:View {
    @State var holder = LazyHolder()
    var body: some View {
        VStack {
            Text("Hello, \(holder.name).")
        }
    }
}

final class LazyHolder {
    lazy var name:String = {
        "text" // 假设经过大量计算
    }()
}
```

不过，如果你的计算需要使用到只有环境才能提供的信息，那么在 body 中使用 `lazy var` 则更有优势。

> @State + onAppear 也能实现类似的效果，不过会让视图多刷新一次。如果计算时间真的较长（ 会导致视图停滞 ），通过在 task 中使用异步方法才是更好的选择。

## 总结

我也是一时兴起写了本文，写完后我也不知道是否能给读者带来什么有价值的东西。只要不被认为是水文章就行🐶。

欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的博客更新信息。**
