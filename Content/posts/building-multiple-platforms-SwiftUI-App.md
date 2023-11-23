---
date: 2023-04-25 08:11
description: 本文是笔者参加 2023 年 4 月 20 日 “SwiftUI 技术沙龙（ 北京站 ）” 活动的分享内容。基于记忆整理而成。本次活动采用的是线下交流并辅以 live coding 的形式，因此内容的侧重点以及组织形式与以往的博客文章会有明显的不同。
tags: SwiftUI
title: 打造可适配多平台的 SwiftUI 应用
image: images/building-multiple-platforms-SwiftUI-App.png
mediumURL: https://medium.com/p/964624fa7b2

---
本文是笔者参加 2023 年 4 月 20 日 “SwiftUI 技术沙龙（ 北京站 ）” 活动的分享内容。基于记忆整理而成。有关本次活动的情况，可以参阅 [我在北京参加 SwiftUI 技术沙龙](https://fatbobman.com/posts/attended-SwiftUI-salon-in-Beijing/) 一文。

本次活动采用的是线下交流并辅以 live coding 的形式，因此内容的侧重点以及组织形式与以往的博客文章会有明显的不同。

## 开场白

大家好，我是肘子。今天我要和大家交流的主题是 —— 打造可适配多平台的 SwiftUI 应用。

## 电影猎手

我们先看一个例子，然后再进入今天的正题。

![image-20230424090248356](https://cdn.fatbobman.com/image-20230424090248356.png)

这是我为本次交流主题写的一个 Demo 应用 —— “[电影猎手](https://github.com/fatbobman/MovieHunter)”。100% 基于 SwiftUI 开发，目前支持三个平台： iPhone、iPad 和 macOS。

使用者可以通过它来浏览电影信息，包括正在上映以及即将上映的影片。并且可以根据口碑、评分、流行度、电影类型等维度查看想要了解的影片。

> "[电影猎手](https://github.com/fatbobman/MovieHunter)" 是一个专门为本次交流会准备的 Demo，因此只完成了必须的部分。

相较于 iPhone 版本，iPad 版本除了为了利用更大的屏幕空间对布局做出了一定的调整外，还提供了多窗口运行的能力，使用者可以在每个窗口中独立进行操作。

![image-20230424090345471](https://cdn.fatbobman.com/image-20230424090345471.png)

mac 版本进行了更多符合 macOS 风格的适配，例如：使用了符合 mac 规范的设置视图、支持指针悬浮响应、菜单栏图标，并且支持创建新窗口并直接跳转到特定电影类别（基于数据驱动的 WindowGroup）。

![image-20230424090609933](https://cdn.fatbobman.com/image-20230424090609933.png)

受限于时间，本次交流中，我们不会对该应用的完整适配过程进行讨论，而是就两个我个人认为比较重要但又容易忽视的点进行交流。

```responser
id:1
```

## 兼容性

与不少跨平台框架所推崇的“Write once, run anywhere”不同，苹果对 SwiftUI 的定位是“Learn once, apply anywhere”。

个人理解，SwiftUI 更像是一种编程哲学，掌握了它，便具备了很长一段时间内在苹果生态的不同平台上进行开发的能力。从另一个角度来看，用 SwiftUI 编写的代码，尽管大部分可以运行在不同的平台上，但有一部分则只能运行在特定平台上，而且往往这部分有平台限定的功能，最能体现平台所具有的特点和优势。

SwiftUI 通过设定了某些兼容性的限制，促使开发者在做多平台适配时，不得不考虑平台特点的不同，并根据这些不同来做有针对性的调整。

但是，如果开发者不能理解 SwiftUI 的这个“限制”，并提前做一些准备工作，可能会为之后的多平台开发工作带来一些隐患和增加不必要的工作量。

以“电影猎手”的 iPad 版本为例。在 iPad 中，使用者可以调整应用的窗口尺寸。为了让布局更贴合当前的窗口状态，我们通常会在视图中使用环境值来进行判断：

```swift
@Environment(\.horizontalSizeClass) var sizeClass
```

根据 sizeClass 的当前状态，是 compact（紧凑）还是 regular（常规），来动态调整布局。

如果你的应用只打算适配 iPadOS，这样做是完全正确的。但是对于“电影猎手”这个应用来说，因为之后还需要适配 macOS 版本，使用这种方法便会出现问题。

因为 horizontalSizeClass 这个环境值无法在 macOS 中使用，UserInterfaceSizeClass 是 iOS（iPadOS）独有的概念。我们在视图代码中依赖这个环境值越多，将来需要做的调整也就越多。

![image-20230416170832640](https://cdn.fatbobman.com/image-20230416170832640.png)

为了避免在适配其他平台时重复调整代码，我们可以采用类似于 horizontalSizeClass 的方式（通过环境变量），创建一个可用于所有需要适配平台的自定义环境变量来解决这个问题。

首先创建一个 DeviceStatus 枚举类型：

```swift
public enum DeviceStatus: String {
  case macOS
  case compact
  case regular
}
```

在这个枚举类型中，除了 iOS 中出现的两种窗口状态外，我们还添加了 macOS 枚举项。

然后，创建类型为 DeviceStatus 的环境值：

```swift
struct DeviceStatusKey: EnvironmentKey {
  #if os(macOS)
    static var defaultValue: DeviceStatus = .macOS
  #else
    static var defaultValue: DeviceStatus = .compact
  #endif
}

public extension EnvironmentValues {
  var deviceStatus: DeviceStatus {
    get { self[DeviceStatusKey.self] }
    set { self[DeviceStatusKey.self] = newValue }
  }
}
```

通过条件编译语句 `#if os(macOS)` ，在 macOS 中，环境值被设置为对应的选项。我们还需要创建一个 View Modifier（ 视图修饰器 ），以便能够在 iOS 中及时了解当前的窗口状态：

```swift
#if os(iOS)
  struct GetSizeClassModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State var currentSizeClass: DeviceStatus = .compact
    func body(content: Content) -> some View {
      content
        .task(id: sizeClass) {
          if let sizeClass {
            switch sizeClass {
            case .compact:
              currentSizeClass = .compact
            case .regular:
              currentSizeClass = .regular
            default:
              currentSizeClass = .compact
            }
          }
        }
        .environment(\.deviceStatus, currentSizeClass)
    }
  }
#endif
```

当视图的 horizontalSizeClass 发生变化时，及时的更新我们自定义的 deviceStatus。最后再通过一个 View Extension，将不同平台的代码组合在一起：

```swift
public extension View {
  @ViewBuilder
  func setDeviceStatus() -> some View {
    self
    #if os(macOS)
    .environment(\.deviceStatus, .macOS)
    #else
    .modifier(GetSizeClassModifier())
    #endif
  }
}
```

将 setDeviceStatus 应用在根视图上：

```swift
ContentView:View {
    var body:some View {
      RootView()
          .setDeviceStatus()
    }
}
```

至此，我们便拥有了在 iPhone、iPad 以及 macOS 中了解当前窗口状态的能力。

```swift
@Environment(\.deviceStatus) private var deviceStatus
```

如果将来，我们需要适配更多的平台，只需要调整自定义环境值的设定便可以了。尽管仍需要调整视图代码，但相较于 horizontalSizeClass 来说，修改量将减少许多。

> setDeviceStatus 并非只能用于根视图，但至少应该使用在当前应用的最宽视图处。这是因为 horizontalSizeClass 只表示当前视图的横向尺寸类别，也就是说，如果在一个横向尺寸被限定的视图中（ 例如 NavigationSplitView 的 Sidebar 视图 ）获取 horizontalSizeClass ，无论应用的窗口尺寸如何，当前视图的 sizeClass 只能为 compact。 我们创建 deviceStatus 的目的是用来观察当前应用的窗口状态，故此必须应用于最宽处。

在 SwiftUI 中，除了环境值外，另一个具备较多平台“限制”的部分就是视图的 Modifier。

例如，在准备开始适配“电影猎手”的 macOS 版本时（已完成 iPad 版本的适配），当添加好 macOS 的 destination 并进行编译后，你会发现 Xcode 出现了不少类似下面这种错误：

![image-20230416172647039](https://cdn.fatbobman.com/image-20230416172647039.png)

这是因为某些 View Modifier 并不支持 macOS。对于上面的这个错误提示，我们可以简单地使用条件编译语句将其屏蔽掉。

```swift
#if !os(macOS)
    .navigationBarTitleDisplayMode(.inline)
#endif
```

不过，如果类似的问题很多，我们不妨采用一个一劳永逸的方案。

在“电影猎手”中，navigationBarTitleDisplayMode 是一个经常被使用到的 Modifier ，我们可以创建一个 View Extension 来处理不同平台下的兼容性问题：

```swift
enum MyTitleDisplayMode {
    case automatic
    case inline
    case large
    #if !os(macOS)
        var titleDisplayMode: NavigationBarItem.TitleDisplayMode {
            switch self {
            case .automatic:
                return .automatic
            case .inline:
                return .inline
            case .large:
                return .large
            }
        }
    #endif
}

extension View {
    @ViewBuilder
    func safeNavigationBarTitleDisplayMode(_ displayMode: MyTitleDisplayMode) -> some View {
        #if os(iOS)
            navigationBarTitleDisplayMode(displayMode.titleDisplayMode)
        #else
            self
        #endif
    }
}
```

在视图中直接使用：

```swift
.safeNavigationBarTitleDisplayMode(.inline)
```

如果你打算将应用引入更多的平台，提前准备一些解决兼容性的代码将会极大地改善之后的开发效率。这种做法不仅可以解决跨平台兼容性问题，还有其他好处：

- 可以改善视图中代码的整洁度（减少条件编译语句的使用）
- 可以改善 SwiftUI 在不同版本之间的兼容性

当然，要创建并使用这类代码，前提是开发者必须已经对 SwiftUI 在不同平台中的“限制”（ 每个平台的特点、优势、处理方式 ）有了比较清晰的认识。盲目地使用这些解决兼容性的代码可能会破坏 SwiftUI 创建者的苦心，让开发者无法准确地体现不同平台的特色。

```responser
id:1
```

## 数据源

聊完兼容性后，我们再聊另一个在构建多平台应用初期容易忽略的问题：数据源（数据依赖）。

当我们将“电影猎手”从 iPhone 移植到 iPad 或 Mac 上时，除了屏幕可用空间更大之外，另一个显着的变化是使用者可以同时打开多个窗口，并可以在不同的窗口中对“电影猎手”进行独立的操作。

然而，如果我们直接将尚未进行多屏适配的 iPhone 版本的“电影猎手”运行于 iPad 上，会发现尽管可以同时开启多个“电影猎手”窗口，但所有的操作都是同步的，也就是在一个窗口中进行的操作同时会体现在另一个窗口中。这样就失去了多窗口存在的意义。

![RocketSim_Recording_iPad_Pro_11'_2023-04-24_09.26.09.2023-04-24 09_27_40](https://cdn.fatbobman.com/RocketSim_Recording_iPad_Pro_11'_2023-04-24_09.26.09.2023-04-24%2009_27_40.gif)

为什么会出现这种情况呢？

我们都知道 SwiftUI 是一个声明式框架。这不仅意味着开发者可以通过声明的方式来构造视图，而且场景（对应着独立的窗口）甚至整个 App 都是基于声明式代码来创建的。

```swift
@main
struct MovieHunterApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            ContentView()
               .environmentObject(store)
        }
    }
}
```

在 Xcode 创建的 SwiftUI 项目模板中，WindowGroup 对应着一个场景声明。由于 iPhone 只支持单窗口模式，通常我们不会太注意它的存在，但在 iPadOS 以及 macOS 这些支持多窗口的系统中，则代表着，每次创建一个新窗口（在 macOS 中，通过菜单中的新建来创建新窗口），都将严格地按照 WindowGroup 的声明来进行。

在“电影猎手”中，我们在 App 的位置创建了 Store（保存应用状态以及主要处理逻辑的单元）的实例，并通过 `.environmentObject(store)` 注入到根视图中。这种通过 `environmentObject` 或 `environment` 来注入的信息，只能在为当前场景创建的视图树中被使用。

![image-20230424092927467](https://cdn.fatbobman.com/image-20230424092927467.png)

尽管系统在创建新场景（新窗口）时会为其创建一棵新的视图树，但由于为新场景的根视图注入的仍然是同一个 Store 实例，因此尽管场景不同，但在不同的窗口中获取的应用状态完全一致。

![image-20230424093006309](https://cdn.fatbobman.com/image-20230424093006309.png)

由于“电影猎手”采用了编程式导航，视图堆栈以及 TabView 的状态都保存在 Store 中，因此会出现操作同步的情况。

因此，如果我们打算将应用引入到一个支持多窗口平台的时候，最好能提前考虑到这种情况，想好如何组织应用的状态。

对于“电影猎手”当前的状态配置来说，我们可以通过将创建 Store 实例的位置移动到场景内来解决上述问题（将 MovieHunterApp 中与 Store 有关的代码移动到 ContentView 中）。

![image-20230424093127892](https://cdn.fatbobman.com/image-20230424093127892.png)

![image-20230424101327899](https://cdn.fatbobman.com/image-20230424101327899.png)

不过，这种在每个场景中创建独立的 Store 实例的方式并非适用于所有情况。在很多情况下，开发者只想在应用中保持一个 Store 实例。我将通过另一个简单的应用来展示这种场景。

> 我想很多读者此时都不会太赞同在每个场景中创建一个独立的 Store 实例这种做法。至于这种做法是否正确、是否符合当前流行的 Single source of truth 的理念，我们在之后还会继续探讨。

这是一个极为简单的 Demo —— [SingleStoreDemo](https://github.com/fatbobman/SingleStoreDemo)。它只有一个 Store 实例并支持多窗口，使用者在每个窗口中都可以独立地切换 TabView，并且 TabView 的状态由唯一的 Store 实例持有。通过点击任意窗口中任意 Tab 中的 “Hit Me” 按钮来增加点击次数。点击次数显示在窗口的上方。

![RocketSim_Screenshot_iPad_Pro_11'_2023-04-24_10.15.30](https://cdn.fatbobman.com/RocketSim_Screenshot_iPad_Pro_11'_2023-04-24_10.15.30.jpeg)

我们在设计这个 App 的状态时，就要考虑到哪些是应用全局的状态，哪些是仅限于当前场景（窗口）的状态。

```swift
struct AppReducer: ReducerProtocol {
    struct State: Equatable {
        var sceneStates: IdentifiedArrayOf<SceneReducer.State> = .init()
        var hitCount = 0
    }
}

struct SceneReducer: ReducerProtocol {
    struct State: Equatable, Identifiable {
        let id: UUID
        var tabSelection: Tab = .tab1
    }
}
```

在应用的总 State 中，除了服务于全局的 `hitCount` 外，我们还为可能的多场景需求将场景的 State 独立出来。并通过 [IdentifiedArray](https://github.com/pointfreeco/swift-identified-collections) 来管理不同场景的 State。

当一个场景被创建后，通过 onAppear 里的代码，在 App State 中创建属于它自己的 State 数据，并在场景被删除时，通过 onDisappear 里的代码，将当前场景的 State 清除掉。

```swift
.onAppear {
    viewStore.send(.createNewScene(sceneID)) // create new scene state
}
.onDisappear {
    viewStore.send(.deleteScene(sceneID)) // delete current scene state
}
```

如此一来，便实现了通过一个 Store 实例，支持多窗口独立操作的需求。

> 详情，请自行查看 [代码](https://github.com/fatbobman/SingleStoreDemo)

在这里需要特别注意的是，不知道出于什么原因（或许与随机数的种子有关），通过同一个场景声明创建的根视图，如果使用@State 创建的 UUID 或随机数，即使在不同的窗口中，即使窗口创建的时间不同，UUID 或随机数的值是完全一样的。如此一来，便无法为不同的场景创建不同的状态集（当前的场景状态使用 UUID 作为标识符）。为了避免这种情况，需要在 onAppear 中重新生成新的 UUID 或随机数。

```swift
.onAppear {
    sceneID = UUID()
    ...
}
```

> 这个问题，同样出现在“电影猎手”中创建 [overlayContainer](https://github.com/fatbobman/SwiftUIOverlayContainer) 的场景中（ 用于显示全屏电影剧照 ），也是采用上述的方法才得以解决。

虽然 SingleStoreDemo 使用 TCA 作为数据流框架，但这并不代表 TCA 在实现类似需求时有特别的优势。在 SwiftUI 中，只要理解了状态、声明和响应之间的关系，开发者就可以用任何想用的形式来组织数据。无论是将状态进行统一管理，还是分散在不同的视图中，都有各自的优势和意义。此外，SwiftUI 本身还为开发者提供了不少专门用于处理多场景模式下的属性包装器类型，例如：@AppStorage、@SceneStorage、@FocusedSceneValue、@FocusedSceneObject 等。

回过头来，我们再看一下“电影猎手”的多个 Store 实例的实现方式。难道“电影猎手”没有应用层面（全局）的状态需求吗？

当然不是。在“电影猎手”中，应用层面的大多数状态是由 @AppStorage 来管理的，而另外一些全局状态，则是通过 Core Data 来进行维护。也就是说，尽管“电影猎手”采用了为每个场景创建一个独立的 Store 实例的外在形式，但在底层逻辑上，与 SingleStore 的 TCA 实现本质上没有什么不同。

我认为，开发者应根据需要采用适宜的手段，而不必拘泥于某种特定的数据流理论或框架。

最后，我们来谈谈在将“电影猎手”适配到 macOS 时，碰到的另外一个与数据源有关的问题。

为了让“电影猎手”更符合 macOS 应用的规范，我们将视图移动到菜单项中，并在 mac 代码中取消了 TabView。

```swift
@main
struct MovieHunterApp: App {
    let stack = CoreDataStack.share
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
         ...
        }

        #if os(macOS)
            Settings {
                SettingContainer() // 声明设置视图
            }
        #endif
    }
}

// ContentView
VStack {
    #if !os(macOS)
        TabViewContainer()
    #else
        StackContainer()
    #endif
}
```

当做完这些改动后，您会发现，我们只能在设置中更改电影信息窗口的颜色模式和语言，而设置视图并不会像 iPhone 和 iPad 那样一并随之变化。

![iShot_2023-04-24_10.33.03.2023-04-24 10_34_15](https://cdn.fatbobman.com/iShot_2023-04-24_10.33.03.2023-04-24%2010_34_15.gif)

这是因为，在 macOS 中，使用 Settings 来声明 Settings 窗口同样是创建了一个新的场景，会创建一棵独立的视图树。在 iOS 中，我们通过在根视图（ ContentView ）中修改环境值的方式来更改颜色和语言，并不会对 macOS 的 Settings 场景产生影响。因此，在 macOS 中，我们需要单独为 Settings 视图来调整颜色和语言的环境值。

```swift
struct SettingContainer: View {
    @StateObject var configuration = AppConfiguration.share
    @State private var visibility: NavigationSplitViewVisibility = .doubleColumn
    var body: some View {
        NavigationSplitView(columnVisibility: $visibility) {
          ...
        } detail: {
           ...
        }
        #if os(macOS)
        .preferredColorScheme(configuration.colorScheme.colorScheme)
        .environment(\.locale, configuration.appLanguage.locale)
        #endif
    }
}
```

> 恰恰是由于采用了 @AppStorage 来管理全域状态，才能在不引入 Store 实例的情况下，轻松地完成设置窗口的适配工作。

## 总结

相较于为不同的平台调整视图布局，今天说到的问题并没那么起眼，容易忽视。

然而，只要了解这些要点的存在，并提前进行规划和准备，适配的过程就会更加顺利。开发者也就能够把更多精力投入到为用户打造不同平台的独特使用体验上。

以上就是今天交流的全部内容，谢谢大家的聆听，希望能对你有所帮助。
