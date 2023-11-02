---
date: 2023-06-09 08:12
description: WWDC 2023 正在如火如荼地进行。苹果不仅带来了全新形态的硬件产品，还推出了几个相当震撼的新框架。本文将聊聊我对本届 WWDC 中 SwiftUI 和 SwiftData 的初步印象。
tags: SwiftUI,Core Data,WWDC23,持久化框架,SwiftData
title: WWDC 23 ，SwiftUI 5 和 SwiftData 的初印象
image: images/impressions-of-WWDC23.png
mediumURL: https://medium.com/p/85d16df77e2c
---
WWDC 2023 正在如火如荼地进行。苹果不仅带来了全新形态的硬件产品，还推出了几个相当震撼的新框架。本文将聊聊我对本届 WWDC 中 SwiftUI 5.0 和 SwiftData 的初步印象。

## SwiftUI

如果说从 SwiftUI 1.0 到 4.0 每年的升级是一种小修小补的行为，那么今年苹果在 SwiftUI 5.0 上做出的努力至少算得上是中期改款了。

今年 SwiftUI 的提升相当的大，有些改动可以视为革命性的变化。

### 全新的数据流声明和注入方式

利用 Swift 5.9 的新特性，对于引用类型的 Source of truth，只需使用 `@Observable` 进行标注，视图将对数据源的变化以属性为粒度进行响应。这从根本上解决了当前影响 SwiftUI 应用（ 过渡计算 ）的效率问题。让开发者可以更加自由的来设计数据结构以及随心所欲的注入数据源。

不过很遗憾，这项新特性只能在 SwiftUI 5 上实现。如果你打算开发 iOS 17+ 的应用，那么就应该马上抛弃 `@ObservableObject` 这样的声明方式。

由于在同一个系统中存在了两种不同的数据源声明逻辑，这也给初学者带来了更多的困扰。

### 革命性的动画和视觉效果升级

SwiftUI 原本欠缺一些高级的动画和视觉功能在本次升级中一并被补上了，而且苹果大幅更新了动画、转场、Shape、效果等方面的内部实现。

本次升级带来了动画完成回调、阶段性动画、关键帧动画、全新的 Transition 协议（ 支持转场状态 ）、全新的 Shape 协议（ 支持 Shape 之间的运算 ）、全新的 TransactionKey（ 支持自定义 Transaction 属性 ）、Shader 支持（ 实现某些特殊效果将异常容易 ）、类型安全的图片和颜色资源类型（ Assets 会自动生成对应的代码 ）、便捷的 Symbol 动画、全新的 CustomAnimation 协议（ 支持自定义动画函数 ）、弹簧动画等众多新功能。总之，当前制约动画或视觉效果的将不再是 SwiftUI 的能力，而是开发者的创意。

### 大幅改善了 ScrollView 的控制力

本次升级中，为 ScrollView 带来了新的动态滚动定位系统（ 不依赖 ScrollViewReader 和显式的 id 声明）、一次性的定位系统（ 在视图进入后，直接定位到滚动视图的特定位置，只能使用一次 ）、全新的滚动条控制（ 闪烁 ）、可自定义行视图在滚动区域的顶端和显示区域的显示状态（ 例如可用其实现类似 watchOS 中的滚动到顶端子视图缩小的视觉效果 ）、支持分页滚动（ 开发者长期盼望的 ）、自定义滚动内容的缩进、为滚动内容（非滚动容器）添加安全区域等众多功能。

### 其他功能

本次的升级内容非常多，导致苹果给出的 [更新文档](https://developer.apple.com/documentation/Updates/SwiftUI) 中，很多的新功能也没有列出。在接下来的一段时间中，互联网上应该会有不少的文章对这些功能进行进一步的说明和讲解。

不过极为遗憾的是，苹果并没有充分的利用 Swift 的 `@_backDeploy` 功能，在 SwiftUI 5.0 中，仅有极少切不太重要的功能或类型实现了低版本的适配：`topBarLeading: SwiftUI.ToolbarItemPlacement`、`topBarTrailing: SwiftUI.ToolbarItemPlacement`、`accessoryBar<ID>`、`horizontalSizeClass`、`verticalSizeClass`、`typeSelectEquivalent` 。

在不考虑兼容旧版本的情况下，我认为 SwiftUI 5.0 的升级可以打 95 分（满分 100 分），不过考虑到很多的开发者在相当一段时间内还无法使用这些新功能，心情就会异常的低落。

```responser
id:1
```

## SwiftData

经过开发者长时间的期盼，苹果终于推出了基于 Swift 开发的对象图管理和持久化框架 —— SwiftData。与之前的预判一样，在数据存储领域，苹果不会贸然地另起炉灶，创建一套全新的逻辑。SwiftData 本质上就是一套官方推出的，基于 Swift 5.9 新功能实现的 Core Data 的 Swift 封装库。

从我这两天的使用来看，在其功能和稳定性得到进一步改善和增强的情况下，它确实会给开发者带来更多的便利。

这是我目前整理的一些有关 SwiftData 的问题和注意事项（ 原文发表在推文中，没有进行更系统的归纳）：

- 尚不支持公共和共享数据的云同步
- 在当前版本中，通过其他上下文（ModelContext）创建的数据并不会自动合并到视图上下文中
- 自定义迁移 plan 在第一版中有问题
- 可以与 Core Data 代码混用，需通过 entityVersionHashesByName 来判断 SwiftData 与 Core Data 两者的模型是否完全一致
- PersistentModel 和 ModelContext 都不是 Sendable 的（ModelContainer 符合 Sendable），与 Core Data 一样，同样有线程限制
- 开启 `com.apple.CoreData.ConcurrencyDebug 1` 后，即使在新的 Context 中使用 transaction 尝试保持线程一致，仍会强制报错（即使是在一个新创建的 actor 中进行）
- 同样受到 CloudKit 同步的限制，演示中的 Attribute(.unique) 并不适用于同步场景
- 目前功能比 Core Data 少，没有新的增加
- PersistentModel 的性质与通过宏创建的 Observed 状态类似，可直接驱动视图更新（传递时无需使用属性包装器）
- Attribute 的派生选项被废弃了
- 可以在 Xcode 中使用 Model Editor 将 Model 转换为 SwiftData 代码，但目前问题还不少，当有多个选项，或属性类型为 transformable ，无法很好地应对
- Model 原来设置的 Index，目前无法转换（可生成对应的代码，但 Attributed 尚未完全）
- 所有针对 Core Data 的启动参数目前同样适用
- modelContext 的自动保存有问题，当前仍应调用 save 方法
- 与 Core Data Stack 混用时，Core Data 端要开启持久化历史跟踪
- Query（FetchRequest 的替代品）没有提供动态切换 predicate 和 sort 的方法

从代码风格和实现来看，SwiftData 有着光明的未来，但由于目前仍存在不少问题，即使你打算开发 iOS 17+ 应用，目前也不建议直接使用 SwiftData。

为配合 SwiftData，Core Data 做了很小幅度的升级，其中一个值得关注的功能是 [自定义 composite 类型](https://twitter.com/fatbobman/status/1666677142170779648?s=20)。

然而，Core Data with CloudKit API 在客户端方面没有任何调整，很令人失望。

## 开心还是无奈

在今年的 WWDC 中，苹果为 SwiftUI 带来了非常大的变革，并推出了开发者向往已久的 SwiftData。一开始看到这些信息时，我内心无比兴奋，但很快就平静下来了，最终还有些无奈。

对于绝大多数开发者来说，一旦能够在应用中使用这些新功能，苹果或许又会带来更多的新诱惑。SwiftUI 的新特性极大拓展了其表达能力，但同时也增加了其学习曲线，特别是对初学者而言。SwiftData 虽然简化了 Core Data 的开发，但作为一款新框架，其稳定性与健壮性还有待进一步验证。

在过去几年，苹果推出的新技术层出不穷，开发者要不断学习与适应，这无形中也增加了开发成本与风险。虽然苹果的新技术普遍都具有实用价值，但在追新与稳定之间，开发者也需要慎重地权衡。

不过对于我来说，本次 WWDC 提供了不少学习和写作的素材。在接下来的一段时间里，我将在博客中介绍和探讨 SwiftUI、SwiftData 以及几个我比较感兴趣的新框架 TipKit 和 CKSyncEngine。
