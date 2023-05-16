---
date: 2023-05-17 08:12
description: 上周，我在博客中列出了我对今年 WWDC 中期待看到的 SwiftUI 方面的变化。这周，我想继续分享我对 Core Data 的期待。
tags: Core Data,WWDC23
title: WWDC 2023 我期待 Core Data 带来的新变化
image: images/What-I-Hope-to-See-for-Core-Data-at-WWDC-2023.jpg
---
上周，我在博客中列出了我对今年 WWDC 中期待看到的 SwiftUI 方面的变化。这周，我想继续分享我对 Core Data 的期待。

## Swift 重制版

紧迫性：3  实现可能性：0.5（ 总分 5 分 ）

在最近两三年中，每当 WWDC 临近时，总有开发者在网上预测（更多的是期望）苹果能够推出完全基于 Swift 的 Core Data 实现。 然而，理性地说，目前各个方面条件尚不成熟。一方面，作为一个被广泛使用的具有持久化能力的对象图管理框架，苹果对其的调整必定会非常谨慎；另一方面，尽管 Core Data 的实现有些过时，但仍然可以稳定地与许多新框架、新服务配合使用，苹果对其进行革命性调整的动力也不足；最后，当前的 Swift 语言以及其他与 Core Data 配合使用的框架仍未具备支持创建纯 Swift 实现的能力。

从 SwiftUI 的经验可以看出，当苹果打算启动 Core Data 的 Swift 化时，我们必然能够从 Swift 社区的提案中看到端倪。

尽管如此，我仍然对基于 Swift 实现的 Core Data 充满了向往，期盼这一天早日到来。说不定，Swift 重制版能够让其具有跨平台能力。

## 用 Swift 重制部分 API

紧迫性：5  实现可能性：4.5（ 总分 5 分 ）

虽然我认为苹果不会在短时间内实现 Core Data 的 Swift 化，但与之配套的框架和 API 的 Swift 化工作已经持续进行了几年。

目前，基于 Swift 实现的 API 包括：FetchRequest（ 在 SwiftUI 框架中 ）和 SortDescriptor。

在不久前推出的 [swift-foundation](https://github.com/apple/swift-foundation) 中，Predicate 已经被提及，预计将在下半年实现。如果苹果能将其他一些 API（例如：NSExpression 等）也用 Swift 实现，届时再对 Swift 语言进行有针对性的增强，基于 Swift 实现的 Core Data 将应运而生。

```responser
id:1
```

## 支持更多 SQLite 新特性

紧迫性：4  实现可能性：3.5（ 总分 5 分 ）

尽管 Core Data 当前支持四种存储模式，但是绝大多数开发者仍然将 SQLite 作为首选的存储类型。苹果也很清楚这种情况，因此在最近几年为 Core Data 开发的一些新增功能上，也仅支持 SQLite。

然而，苹果已经很久没有对 Core Data 的 SQLite 支持进行增强了。就我个人而言，SQLite 所能实现的全文检索和原生的 JSON 查询能力都是我迫切需要的。

我希望上述功能能在最近一两年内被 Core Data 所采纳。

## 更好的 Model Editor 体验

紧迫性：4  实现可能性：4（ 总分 5 分 ）

近年来，除了为某些新功能添加必要的配套外，苹果基本上放弃了对 Xcode 中的 Model Editor 进行改善。尤其是在 Xcode 14 中，苹果移除了数据模型的关系图编辑器，这一点让我感到非常困惑。

尽管我并不经常使用这个功能，但是相对于其他持久化框架，Core Data 最大的优势或特点就是其对关系的管理能力。这也是 Core Data 被认为是对象图管理框架而非持久化框架的主要原因之一。

即使不能对 Model Editor 进行强化，也不应该抹杀其原有的优势。

我仍然衷心希望 Xcode 团队不要放弃 Model Editor，并进一步增强其功能。功能，改善其使用体验。

## 完善 Core Data with CloudKit 的部分 API

紧迫性：5  实现可能性：4（ 总分 5 分 ）

在 Core Data with CloudKit 推出的前三年，苹果以每年一大步的速度推进该框架的发展。目前已拥有了私有库同步、公共库同步、共享数据等众多功能。可以说，相较于 Core Data 框架本身，苹果在推动 Core Data 云端同步的工作上的成绩是有目共睹的。

不过比较遗憾的是，去年并没有延续这种发展势头，没有继续推出新的功能，也没有对之前出现的一些问题进行改进。

尤其是共享数据这一功能，因为本身 API 的一些不完善，始终没有被开发者广泛采用。

Core Data with CloudKit 目前已经是苹果生态的一把利器，基于其开发的应用具备了相当的平台排他性。苹果应该利用好之前创造的优势，进一步增强该功能，至少让当前所有的功能都能被正常地使用。

## 改善 Core Data with CloudKit 的同步表现

紧迫性：5  实现可能性：3.5（ 总分 5 分 ）

随着采用 Core Data with CloudKit 的应用增加，使用者创建的数据也急剧膨胀。因此，网络同步效率差的问题也越来越明显。

作为开发者，我理解基于成本的考量，官方有意控制了数据同步的频率和数量，但考虑到如此多的应用已将 Core Data with CloudKit 作为其同步框架，苹果是否可以考虑为开发者或用户提供更多的选择。

例如，允许开发者或使用者通过额外支付一定的费用获得更好、更快的同步服务。

当然，如果苹果能对 iCloud 服务进行整体的性能升级，让所有的开发者和用户都能免费获得收益，那将是最好的结果。

## 总结

俗话说，“爱之深责之切”。作为 Core Data 的重度使用者，我衷心希望苹果能够继续发扬这个拥有悠久历史的框架，焕发其第二春。

欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周最新文章。**
