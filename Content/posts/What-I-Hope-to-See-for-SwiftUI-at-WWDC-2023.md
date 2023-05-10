---
date: 2023-05-11 08:12
description: 距离 2023 年的 WWDC 还有约 20 天，每个苹果生态的开发者都在期待苹果会在当天带来哪些新东西。在本文中，我将列出个人对于 SwiftUI 的愿望单，期待着看到哪些愿望能够实现。
tags: SwiftUI,WWDC23
title: WWDC 2023, 我期待 SwiftUI 带来的新变化
image: images/What-I-Hope-to-See-for-SwiftUI-at-WWDC-2023.png
---
距离 2023 年的 WWDC 还有约 20 天，每个苹果生态的开发者都在期待苹果会在当天带来哪些新东西。在本文中，我将列出个人对于 SwiftUI 的愿望单，期待着看到哪些愿望能够实现。

如果不限制数量，SwiftUI 开发者可能会列出一个长长的愿望列表。在此仅列出几个我认为重要且近一两年内有望实现的愿望，避免期望过高而带来的失望。

## 以属性为粒度的视图关联

紧迫性：4  实现可能性：3.5（ 总分 5 分 ）

在上个月，Swift 社区出现了一个提案 **[SE-0395: Observability](https://forums.swift.org/t/se-0395-observability/64342)** , 简单来说可以将其理解为 Swift 原生的 KVO 加强版实现。如果这个提案得以在近期通过，那么在 SwiftUI 中，视图就有可能实现以属性为粒度的依赖关联。如此一来，在使用基于 ObservableObject 协议的引用类型 Source of truth 时，不必要的计算将大大减少，开发者将可以用更自由的方式来组织 Data flow。

## 统一的 Gesture 逻辑、允许创建真正的自定义手势

紧迫性：5  实现可能性：2.5

在 SwiftUI 中，开发者很难实现复杂的手势逻辑。其中一个重要原因是 SwiftUI 目前存在两个手势系统，而且两者的兼容性很差，其中一种很容易被另一种打断。从 SwiftUI 的 interface 文件可以看到，ScrollView、List、TabView、Button 等控件都有其对应的内部手势实现，这些实现与常用的 DragGesture、TapGesture 等开放给开发者的手势在很大程度上不同。它们在优先级上更高，而且它们之间也不能很好地共融。这就导致无法用原生的 SwiftUI 方式应对有复杂手势需求的场景（例如多重滚动嵌套）。

此外，SwiftUI 并未提供真正的自定义手势能力，目前仅支持基于当前已提供手势的组合功能。如果开发者使用基于 UIKit 的自定义手势，则将落入到上文提到的手势之间相互竞争的困境中。

只有尽早提供完善的自定义手势功能，并在 SwiftUI 内部实现手势逻辑的统一，才能解决这些问题。

## 更完善的文字输入和显示

紧迫性：5  实现可能性：4

相较于最初版本，SwiftUI 4.0 的 Text 和 TextField 功能已经有了极大的增强和改善。然而，与成熟的解决方案相比，它们仍有相当的差距。许多开发者为了解决某些问题不得不基于 UIKit（ AppKit ）重新包装所需的显示和录入控件，这不仅增加了工作量，也放弃了许多原生控件所提供的优秀能力。

说实话，无论 Text 和 TextField 增强到何种程度都不为过。但对我而言，目前急需解决的问题有以下几点：

- 提供更好的 AttributedString 支持

除了在 AttributedString 诞生的那一年 Text 提供了部分支持外，上一个版本中没有在这方面做出任何改进。Text 应该提供更多对 AttributedString 属性的支持，特别是针对段落的支持。最好还能提供自定义 Attribute 显示的 API，给开发者提供自行扩充的能力。此外，TextField 也应该支持 AttributedString，这样就可以用原生的方式应对一些简单的排版场景。

- 为避免状态黑洞，需要更统一的状态响应逻辑。

虽然 TextField 的构造方法很好地遵循了 SwiftUI 由状态驱动的逻辑，但这只是表象。实际上，在很多情况下，它只是在表演状态与显示一一对应的关系。由于经过了二次包装，这些控件在内部实现时经常遗漏与外部状态的对应，从而出现无法处理的情况（无法从状态下手，也无法从内部找到 hack 的点）。

> 这种问题不仅出现在 TextField 上，很多主要依赖对 UIkit 二次包装的控件目前都存在类似的问题。从某些 Bug 的分析中可以看出，SwiftUI 团队的部分开发人员也没有完全转换至声明、状态、响应的思维逻辑上。在包装时，他们经常会遗漏与外部状态的同步。
> 

```responser
id:1
```

## 稳定、高效的 ForEach 实现

紧迫性：5  实现可能性：3.5

在 SwiftUI 中，ForEach 是一个经常使用的控件，尤其在 Lazy 容器中。 然而，直到 4.0 版本，它的稳定性和性能仍然无法完全令人满意。例如：

- [在子视图使用的 id 修饰符的情况下，优化机制失效](https://www.fatbobman.com/posts/optimize_the_response_efficiency_of_List/)
- [内存释放不及时，容易导致应用崩溃](https://www.fatbobman.com/posts/memory-usage-optimization/)
- [task 修饰器闭包任务无法 100% 调用（ 已在 16.4 修复 ）](https://twitter.com/fatbobman/status/1574252681467637760?s=61&t=ecQh6_M1bDgzJDGbrFupaw)
- [二级及以下子视图在 onDisappear 后无法保持状态](https://twitter.com/fatbobman/status/1572507700436807683?s=61&t=6wE0YqMg9Y85zDZMQr_ycg)（ 在写本文前两天，收到苹果的回复，证实此为 by Design 的行为 ）

这导致在数据量较大的情况下，基于 SwiftUI 的应用性能较差，用户体验不佳。随着基于 SwiftUI 的应用越来越复杂，ForEach 的问题急需解决。

> 当然，如果在改善 ForEach 问题的同时能提供一个支持 Lazy 的 Layout 协议那就更好了👏。
> 

## 向前兼容性

紧迫度：4 实现可能性：4.5

当看到 Swift 5.8 提供了 `@backDeployed` 特性时，相信很多开发者都迫切希望苹果能将其应用于 SwiftUI，以增强老版本的功能并修复 bug。每次 WWDC 推出新版本 SwiftUI 时，开发者在高兴的同时也会感到痛苦：难道又要提高应用的最低版本要求？

如果苹果能充分利用该特性，将为开发者带来巨大好处。

## 最后

作为未来数年中苹果生态中最主要的开发框架，SwiftUI 应该提供更多原生、稳定的底层 API，让有经验的开发者能够自行添加特性。这样既可以减轻苹果的工作量，又能让开发者有更多的选择。何乐而不为呢？

## 写出你的愿望单，赢取 🍒

如果你对 SwiftUI 5 有什么期望，请在此 **[推文](https://twitter.com/fatbobman/status/1656109768795365376?s=20)** 下回复。获得最多 ❤️ 的 **7** 个回复者，我将送出一箱大连 🍒。

![Untitled](https://cdn.fatbobman.com/Untitled.png)

向公众号的读者道歉，昨天我本打算在公众号上举办这个活动，结果发出文章后才发现，我的公众号没有评论功能😅。只能把原来准备给公众号的两箱樱桃也放到 Twitter 上了。