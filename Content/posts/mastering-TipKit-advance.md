---
date: 2023-10-25 08:12
description: 在上文中，我们介绍了 TipKit 的基础用法。在本文中，我们将讨论一些与 TipKit 相关的进阶问题，例如如何完全自定义 Tip 视图（不使用 TipView 和 popoverTip）、如何在 UIKit 中使用 TipKit，以及 TipKit 如何在不同的应用程序之间共享数据。最后，我们将尝试解答一些与 TipKit 相关的疑惑。
tags: SwiftUI,TipKit
title: 掌握 TipKit：进阶
image: images/mastering-TipKit-advance.jpg
mediumURL: https://medium.com/p/b6927aeeb9b5
---
在上文中，我们介绍了 TipKit 的基础用法。在本文中，我们将讨论一些与 TipKit 相关的进阶问题，例如如何完全自定义 Tip 视图（不使用 TipView 和 popoverTip）、如何在 UIKit 中使用 TipKit，以及 TipKit 如何在不同的应用程序之间共享数据。最后，我们将尝试解答一些与 TipKit 相关的疑惑。

> 如果你对 TipKit 框架还不太了解，请先阅读 [掌握 TipKit：基础](https://www.fatbobman.com/posts/mastering-TipKit-basic/) 这篇文章。

## 透过现象看本质

TipKit 框架极大地简化了在应用程序中添加提示的难度。通过使用像`TipView`和`popoverTip`这样现成的提示视图，开发者可以专注于提示的内容，而不必过多关心视觉效果的实现。

然而，这些预制的提示视图仅仅是 TipKit 提供的辅助工具。TipKit 的真正精髓在于它采用了“契约式设计”的理念。换句话说，TipKit 允许你用代码的形式定义提示的内容和显示规则，而不需要考虑具体的实现。这些规则和内容构成了你和 TipKit 之间的一个契约。TipKit 会根据这个契约动态决定是否需要显示提示，开发者只需关注状态或事件的变化。

所以，TipKit 的精髓不在于外在的视觉效果，而在于内在的逻辑表达。它帮助开发者以声明的方式描述提示生成的规则，而提示的具体实现完全可以自定义。我们可以把 TipKit 想象成一个判断提示显示需求的规则引擎，至于如何可视化这些规则，则取决于开发者自己。

```responser
id:1
```

## 如何观察 Tip 的状态

既然我们将 TipKit 视作一个判断提示显示需求的规则引擎，那么 TipKit 是否为开发者提供了观察某个 Tip 状态的 API 呢？答案是肯定的。

TipKit 为 Tip 的实例提供了两个方法：`statusUpdates`和`shouldDisplayUpdates`，它们分别返回了两个 AsyncStream，用于提供该 Tip 类型的状态变化和显示与否的信息。

`statusUpdates` 会返回 Tip 的三种状态：`pending`（不符合显示条件）、`available`（符合显示条件）、`invalidated`（失效及失效原因）。

而 `shouldDisplayUpdates` 则简化了上述内容，仅通过 `true` 和 `false` 来表示是否可以显示 Tip 视图。

其中，`pending` 对应 `false`，`available` 对应 `true`。当一个 Tip 被设置为失效后，TipKit 在发送最后一个状态变化信息（`invalidated`）后，将不再观察该 Tip 的参数和事件的变化，停止继续提供状态信息。

让我们使用以下代码来演示观察某个 Tip 状态的过程：

```swift
struct DemoTip: Tip {
    var title: Text = .init("Hello World")

    @Parameter
    static var show: Bool = false

    var rules: [Rule] {
        #Rule(Self.$show) {
            $0
        }
    }
}

struct TipStatusView: View {
    let tip = DemoTip()
    var body: some View {
        List {
            Button("Show Toggle") {
                DemoTip.show.toggle()
            }
            Button("Invalidate") {
                tip.invalidate(reason: .actionPerformed)
            }
        }
        .task {
            for await status in tip.statusUpdates {
                print("Status:", status)
            }
        }
        .task {
            for await shouldDisplay in tip.shouldDisplayUpdates {
                print("Display:", shouldDisplay)
            }
        }
    }
}
```

点击 "Show Toggle" 按钮，将改变 `DemoTip.show` 的值，从而影响 TipKit 根据 rules 进行判断的结果。点击 "Invalidate" 将使该 Tip 失效。

![https://cdn.fatbobman.com/tipkit-status-stream-demo_2023-10-18_15.57.18.2023-10-18%2015_59_07.gif](https://cdn.fatbobman.com/tipkit-status-stream-demo_2023-10-18_15.57.18.2023-10-18%2015_59_07.gif)

也许你已经注意到了，在当前的视图中我们没有添加 `TipView` 或 `popoverTip`，这完全验证了上文中提到的“规则引擎”概念。是否展示 Tip 视图完全取决于开发者。

> TipKit 为 Tip 还提供了两个属性，`status` 和 `shouldDisplay` ，考虑到 Tip 的状态会经常变化，而这两个属性并不具备良好的观察方式，因此不建议完全依赖这两个属性来判断当前 Tip 的状态。

## 根据状态展示自定义 Tip 视图

一旦开发者掌握了观察 Tip 状态的方式，就可以轻松在应用中根据状态展示任何形式和样式的提示视图。

```swift
struct TipStatusView: View {
    let tip = DemoTip()
    @State var shouldDisplay = DemoTip.show
    var body: some View {
        List {
            if shouldDisplay {
                tip.title
            }
            Button("Show Toggle") {
                DemoTip.show.toggle()
            }
            Button("Invalidate") {
                tip.invalidate(reason: .actionPerformed)
            }
        }
        .task {
            for await shouldDisplay in tip.shouldDisplayUpdates {
                withAnimation(.smooth) {
                    self.shouldDisplay = shouldDisplay
                }
            }
        }
    }
}
```

![https://cdn.fatbobman.com/tipkit-show-tip-by-status-demo_2023-10-18_16.55.40.2023-10-18%2016_56_22.gif](https://cdn.fatbobman.com/tipkit-show-tip-by-status-demo_2023-10-18_16.55.40.2023-10-18%2016_56_22.gif)

## 在 UIKit 和 AppKit 中使用 TipKit

由于 UIKit 和 AppKit 并非响应式的框架，即使使用 TipKit 提供的预制 Tip 视图（[TipUIView](https://developer.apple.com/documentation/tipkit/tipuiview)、[TipUIPopoverViewController](https://developer.apple.com/documentation/tipkit/tipuipopoverviewcontroller)、[TipUICollectionViewCell](https://developer.apple.com/documentation/tipkit/tipuicollectionviewcell)、[TipNSView](https://developer.apple.com/documentation/tipkit/tipnsview)、[TipNSPopover](https://developer.apple.com/documentation/tipkit/tipnspopover)），开发者也需要显式地跟踪 Tip 的状态，然后根据状态显示 Tip 视图。

以下代码摘自苹果的官方文档：

```swift
import TipKit
import UIKit

struct CatTracksFeatureTip: Tip {
    var title: Text { Text("Sample tip title")}
    var message: Text? { Text("Sample tip message")}
    var image: Image? { Image(systemName: "globe")}
}

class CatTracksViewController: UIViewController {
    private var catTracksFeatureTip = CatTracksFeatureTip()
    private var tipObservationTask: Task<Void, Never>?
    private weak var tipView: TipUIView?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tipObservationTask = tipObservationTask ?? Task { @MainActor in
            for await shouldDisplay in catTracksFeatureTip.shouldDisplayUpdates {
                if shouldDisplay {
                    let tipHostingView = TipUIView(catTracksFeatureTip)
                    tipHostingView.translatesAutoresizingMaskIntoConstraints = false

                    view.addSubview(tipHostingView)

                    view.addConstraints([
                        tipHostingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                        tipHostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20.0),
                        tipHostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20.0)
                    ])

                    tipView = tipHostingView
                }
                else {
                    tipView?.removeFromSuperview()
                    tipView = nil
                }
            }
        }
    }
}

override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    tipObservationTask?.cancel()
    tipObservationTask = nil
}
```

需要提醒一下，因为在 Tip 协议中，`title`、`message`、`image` 等属性类型均为 SwiftUI 特有的类型，因此如果想在 UIKit 或 AppKit 中实现完全自定义视图，最好在声明 Tip 类型时为其添加其他的附加信息，以方便使用。

## 关于 TipKit 的几个疑问

TipKit 通过代码的形式让开发者定义 Tip 的内容、显示规则以及影响规则的参数和事件。那么 TipKit 是如何理解用户定义的“Tip”呢？是将一个符合 Tip 协议的类型视为一个 Tip，还是将一个用该类型创建的实例视为一个 Tip？

从接触 TipKit 开始，一直有几个疑问困扰着我：

- 在一个应用中，是否可以在多个视图中使用同一个 Tip 类型？
- 同一个 Tip 类型的不同实例是否可以返回不一样的属性值（比如 `title`、`rules`）？
- 在不同的应用之间（ AppGroup ），是否可以使用同一个 Tip 定义？Tip 的状态是否可以同步？
- 怎样才算是同一个 Tip 的定义？是指完全相同的代码吗？
- TipKit 会持久化哪些 Tip 状态？共享 Tip 间状态同步的机制是什么？
- `@Parameter` 是否有类型限制？

对于上述疑问，无论是在 TipKit 的文档还是 WWDC 有关 TipKit 的 [Session](https://developer.apple.com/videos/play/wwdc2023/10229/) 中，都没有给出清晰的解释。幸好，TipKit 采用了我们熟悉的数据持久化机制，我们可以从中找到我们想要的答案。

在进一步寻找答案之前，我们首先需要了解以下几点：

- Tip 中的参数（Parameter）和事件（Event）是以静态属性的形式声明的。
- 对参数的修改以及对事件的触发和查询无需通过实例。
- TipView 和 popoverTip 需要使用 Tip 实例作为参数。
- 观察 Tip 的状态需要通过实例。

```responser
id:1
```

## 从 TipKit 的持久化数据中找寻答案

考虑到 TipKit 需要保存的数据量和数据类型的多样性，UserDefaults 显然不是一个好的选择。最终，我们在应用的 `Application Support` 目录中找到了 TipKit 的持久化数据（在未指定目录和设置 AppGroupIdentifier 的情况下）。TipKit 将数据保存在名为 `.tipkit` 的目录中的 `tips-store.db` 文件里。

打开数据库文件后，我们就能看到熟悉的 Core Data 数据格式的身影。

> 请阅读 [Core Data 是如何在 SQLite 中保存数据的](https://www.fatbobman.com/posts/tables_and_fields_of_CoreData/) 一文，了解 Core Data 的持久化数据格式。

![https://cdn.fatbobman.com/image-20231019105146293.png](https://cdn.fatbobman.com/image-20231019105146293.png)

TipKit 一共创建了 5 个实体（ Entity ），分别是：CoreTipRecord、CoreParameterRecord、CoreEventRecord、CoreDonationRecord 和 CoreRuleRecord。了解了这五个实体的构成，对解答上面的疑问很有帮助。

### CoreTipRecord

保存与 Tip 相关的信息，包括显示日期、次数、Option 设定等。大致的定义如下：

```swift
class CoreTipRecord {
    // Tip Type Name , for example : MyTip
    var id: String
    // pending , available , invalidated
    var statusValue: Int
    // Reason of invalidated
    var invalidationReasonValue: Int
    // The lost display date
    var lastDisplayed: Date?
    // Unclear
    var content: ConstellationContent?
    // Some info of Tip , including : display count, options setting, etc
    var tipInfo: [String: Any]

    var rules: Set<CoreRuleRecord>
    var events: Set<CoreEventRecord>
}
```

> 为了方便阅读，我们将不再使用 NSManagedObject 的方式来进行类型的定义。

其中 `id` 为 Tip 的类型名称，也就是说，下面的代码对应的 CoreTipRecord 的 `id` 值为 `MyTip`：

```swift
struct MyTip: Tip {}
```

无论创建多少个 MyTip 实例，它们都对应着同一个 CoreTipRecord 记录。而且，对于通过 App Group 进行 TipKit 数据共享的应用来说，只要是类型名称为 `MyTip`，它们都对应着同一个 CoreTipRecord 数据。

`tipInfo` 中保存了与该提示相关的其他一些信息，例如：

- 显示记录：所有的显示日期，无论在哪个应用（ App Group ）中对该 Tip 进行显示
- 已显示次数
- 最大显示次数设定（ Option ）
- 是否忽略显示频次策略（ Option ）

只要显示 Tip，显示日期都将被记录。同样，最大显示次数设定适用于 App Group 中的所有成员，并且显示状态在不同成员之间共享。

由于 Tip 的 Option 也被进行了持久化，因此应在不同的应用中（App Group）采用相同的 Option 设置。

> 实践发现，如果在不同的应用中采用了不同的 Option 设置，后启动的会覆盖之前的设置，不推荐这种做法。

### CoreParameterRecord

CoreParameterRecord 大致的定义如下：

```swift
class CoreParameterRecord {
    // Composite name of a paramter property
    var id: String
    // The name of the paramter property type
    var valueType: String
    // Encoded default value
    var valueData: Data?

    var rules: Set<CoreRuleRecord>
}
```

从 CoreParameterRecord 的命名上很容易看出，这个对象用于保存 Tip 中的参数（ Parameter ）信息。

```swift
struct MyTip: Tip {
  @Parameter
  static var show:Bool = false
}
```

上面的代码中，对应 CoreParameterRecord 的数据为：

- id：`Bool.MyTip+show` ，属性类型 + Tip 类型名称 + 属性名称
- valueType：字符串 `Bool`
- valueData: Bool.false 的 Encode 数据

从中我们可以看出，TipKit 并没有对 `@Parameter` 所能支持的数据类型做出太多的限制，类型只需符合 Encodable 协议即可。

```swift
struct MyData: Codable {
  var id: String
  var count: Int
}

struct MyTip: Tip {
  @Parameter
  static var data: MyData = MyData(id:"1", count: 1)
}
```

很遗憾，受限于当前 Predicate 的问题，我们还无法使用以下规则（该规则将在运行时会导致应用崩溃）：

```swift
var rules: [Rule] {
    #Rule(Self.$data){
        $0.count > 3
    }
}
```

### CoreEventRecord

下面是 CoreEventRecord 的大致定义，它用于记录与 Event 定义相关的信息。

```swift
class CoreEventRecord {
    // event property name
    var id: String
    // No data recorded yet
    var eventInfo: [String: Any]

    var donations: Set<CoreDonationRecord>
    var rules: Set<CoreRuleRecord>

    var tip: CoreTipRecord?
}
```

在多个应用（AppGroup）甚至多个设备上（iCloud 同步）触发同一个事件时，所有的触发数据都是共享的。

```swift
static let didTriggerControlEvent = Event(id: "didTriggerControlEvent")
```

CoreEventRecord 中 `id` 为 `didTriggerControlEvent`。

### CoreDonationRecord

CoreDonationRecord 的定义如下：

```swift
class CoreDonationRecord {
    var date: Date
    var donationInfo: DonationInfo?

    var event: CoreEventRecord
}
```

用来记录 Donation 的日期，每次触发都会记录一条数据。

```swift
MyTip.didTriggerControlEvent.sendDonation()
```

![https://cdn.fatbobman.com/image-20231019184513075.png](https://cdn.fatbobman.com/image-20231019184513075.png)

由于 TipKit 尚未公开 DonationInfo，所以我们无法在触发事件时附带自定义的信息。如果未来开放了自定义 EventInfo 的能力，就可以创建更加灵活的规则。

### CoreRuleRecord

CoreRuleRecord 的定义如下，用于记录 Tip 的 Rule 设定：

```swift
class CoreRuleRecord {
    var id: String
    var categoryValue: Int
    var statusValue: Int
    var predicate: Predicate
    var ruleInfo: [String: Any]

    var event: CoreEventRecord?
    var parameter: CoreParameterRecord?
    var parent: CoreRuleRecord?

    var subrules: Set<CoreRuleRecord>
    var tip: CoreTipRecord?
}
```

其中，id 是最有意思的属性，它 Rule 中 Predicate 的自定义版本的字符串表述。

```swift
var rules: [Rule] {
    #Rule(Self.didTriggerControlEvent){
        $0.donations.count > 3
    }
}
```

`id` 为：

```swift
MyTip.event.didTriggerControlEvent.count(donationsCount) > Optional(3)
```

每个 Rule 保存为一条 CoreRuleRecord 记录。在验证时，它们之间是 `AND` 的关系。

```swift
    var rules: [Rule] {
        #Rule(Self.didTriggerControlEvent){
            $0.donations.count > 3
        }
        #Rule(Self.$show){
            $0
        }
    }
```

![https://cdn.fatbobman.com/image-20231019193739995.png](https://cdn.fatbobman.com/image-20231019193739995.png)

## 释疑

通过对 TipKit 持久化数据的分析并结合我做的另外一些测试，我们基本上可以得出以下结论：

- TipKit 的数据是通过 Core Data 来管理并保存的
- 因为 Core Data 的关系，TipKit 的数据可以在不同的应用（AppGroup）或不同的设备间（iCloud）进行共享和同步
- TipKit 根据 Tip 的类型名称来标识 Tip。在不同的应用（AppGroup）之间，相同的 Tip 类型名称将使用同一个 Tip 数据源。
- 在不同的应用（AppGroup）之间，对于同一个 Tip 类型，如果不复用代码，所有的持久化属性（包括静态属性）应该保持一致，包括：Parameter、Event、rules、options。
- 与外观有关的属性可以在创建实例时根据需要进行修改和调整，比如：标题（title）、消息（message）、图片（image）、操作（action）。
- 同一个 Tip 的失效状态、显示状态、点击次数、允许的最大展示量等都是共享的。
- 同一个 Tip 的事件触发数据也是共享的。

> 无论是在 WWDC 的演讲中，还是在 tipInfo 的信息中，都表明 TipKit 支持通过 iCloud 进行同步。然而，我尚未找到正确的开启方式。如果有人成功实现了，请告诉我一下。

## 最后

在本文中，我们从“规则引擎”的角度对 TipKit 进行了分析。尽管分析显示开发团队预留了一些升级空间，但 TipKit 的设计主旨是为了方便在应用中展示 Tip 信息，因此在数据筛选效率和规则制定灵活性方面，并没有过度增加不必要的能力。即便如此，TipKit 还是为我们提供了一个实现可共享数据的微型“规则引擎”的良好范例。