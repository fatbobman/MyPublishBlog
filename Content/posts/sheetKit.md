---
date: 2021-09-16 19:50
description: SheetKit是一个SwiftUI模态视图的扩展库。提供了数个用于模态视图的便捷展示、取消方法，以及几个用于模态视图的View Extension
tags: SwiftUI
title: SheetKit——SwiftUI模态视图扩展库
image: images/sheetKit.png
---

## SheetKit是什么 ##

[SheetKit](https://github.com/fatbobman/SheetKit)是一个SwiftUI模态视图的扩展库。提供了数个用于模态视图的便捷展示、取消方法，以及几个用于模态视图的View Extension。

开发SheetKit的主要原因：

* 便于Deep link的调用

  SwiftUI提供了`onOpenURL`方法让应用程序可以非常轻松的响应Deep Link。但在实际使用中，情况并不如预期。主要因为SwiftUI中重要的视图展示模式：NavigationView、Sheet等都没有迅捷、简便的重置能力。很难通过一两句代码将应用程序立即设置成我们想要的视图状态。

* 模态视图的集中管理

  SwiftUI通常采用`.sheet`来创建模态视图，对于简单的应用来说，这种形式非常直观，但如果应用程序的逻辑比较复杂、需要的模态视图众多，则上述方式就会让代码显得十分混乱，不易整理。因此，在此种情况下，通常我们会将所有的模态视图集中管理起来，统一调用。请参阅我之前的文章——[在SwiftUI中,根据需求弹出不同的Sheet](https://www.fatbobman.com/posts/swiftui-multiSheet/)。

* 新的半高模态视图

  在WWDC 2021中，苹果为大家带来了期待已久的半高模态视图。或许推出的比较仓促，这种很受欢迎的交互方式并没有提供SwiftUI版本，仅支持UIKit。SheetKit暂时弥补了这个遗憾。无论sheet、fullScreenCover还是bottomSheet（半高模态视图）都得到充分的支持和统一的管理。


```responser
id:1
```

## 系统要求 ##

* iOS 15
* Swift 5.5
* XCode 13.0 +

> 只需剥离模态视图的支持，SheetKit将支持iOS 14。

## 安装 ##

SheetKit支持SPM安装。

[源地址](https://github.com/fatbobman/SheetKit.git)

SheetKit中每个功能的代码都集中在一到两个文件中。如果只需要其中部分的功能，直接在项目中添加对应的文件或许是不错的选择。

## SheetKit功能详解 ##

### present ###

#### SheetKit调用 ####

![image-20210916185555507](https://cdn.fatbobman.com/image-20210916185555507.png)

在代码中使用SheetKit十分容易。支持两种方式：直接使用SheetKit的实例、在视图中使用环境值。比如下面的两段代码都将显示一个标准Sheet：

```swift
Button("show sheet"){
   SheetKit().present{
     Text("Hello world")
   }
}
```

或者

```swift
@Environment(\.sheetKit) var sheetKit

Button("show sheet"){
   sheetKit.present{
     Text("Hello world")
   }
}
```

SheetKit支持多层次的Sheet展示，下面代码将展示两层Sheet

```swift
@Environment(\.sheetKit) var sheetKit

Button("show sheet"){
   sheetKit.present{
     Button("show full sheet"){
       sheetKit.present(with:.fullScreenCover){
         Text("Hello world")
       }
     }
   }
}
```

#### 动画 ####

SheetKit中present和dismiss的动画都是可以关闭的（尤其适合于Deep link场景）。使用下面语句将关闭显示动画

```swift
SheetKit().present(animated: false)
```

#### Sheet类型 ####

目前SheetKit支持三种模态视图类型：sheet、fullScreenCover、bottomSheet。

![image-20210916190606032](https://cdn.fatbobman.com/image-20210916190606032.png)

下面的代码将展示一个预设的bottomSheet视图：

```swift
sheetKit.present(with: .bottomSheet){
  Text("Hello world")
}
```

![bottomSheet1](https://cdn.fatbobman.com/bottomSheet1-1778528.gif)

bottomSheet可以自定义配置。

![image-20210916190453672](https://cdn.fatbobman.com/image-20210916190453672.png)

下面的代码将创建一个自定义的bottomSheet

```swift
let configuration = SheetKit.BottomSheetConfiguration(  detents: [.medium(),.large()],
                                                        largestUndimmedDetentIdentifier: .medium,
                                                        prefersGrabberVisible: true,
                                                        prefersScrollingExpandsWhenScrolledToEdge: false,
                                                        prefersEdgeAttachedInCompactHeight: false,
                                                        widthFollowsPreferredContentSizeWhenEdgeAttached: true,
                                                        preferredCornerRadius: 100)

sheetKit.present(with: .customBottomSheet,configuration: configuration) {
  Text("Hello world")
}
```

![Simulator Screen Shot - iPhone 13 Pro Max - 2021-09-16 at 16.15.08](https://cdn.fatbobman.com/Simulator%20Screen%20Shot%20-%20iPhone%2013%20Pro%20Max%20-%202021-09-16%20at%2016.15.08.png)

#### 模态视图高度变化提醒 ####

当bottomSheet在不同高度变化时，有两种方式可以获得提醒。

方法1：

```swift
@State var detent:UISheetPresentationController.Detent.Identifier = .medium

Button("Show"){
  sheetKit.present(with: .bottomSheet,detentIdentifier: $detent){
    Text("Hello worl")
  }
}
.onChange(of: detent){ value in
    print(value)
}
```

方法2：

```swift
@State var publisher = NotificationCenter.default.publisher(for: .bottomSheetDetentIdentifierDidChanged, object: nil)

.onReceive(publisher){ notification in
       guard let obj = notification.object else {return}
       print(obj)
}
```

> 当采用方法2时，如果需要展示多层bottomSheet，请为不同层次的视图定义不同名称的Notification.Name

### dismissAllSheets ###

![image-20210916190651604](https://cdn.fatbobman.com/image-20210916190651604.png)

SheetKit支持快速取消全部正在显示的模态视图（无论该模态视图是否由SheetKit展示）。使用下面的代码

```swift
SheetKit().dismissAllSheets()
```

支持动画控制及onDisappear

```swift
    SheetKit().dismissAllSheets(animated: false, completion: {
        print("sheet has dismiss")
    })
```

### dismiss ###

如果只想取消最上层的模态视图，可以使用dismiss

```swift
    SheetKit().dismiss()
```

同样支持动画控制

> 如果在视图外执行SheetKit方法，请务必保证代码运行在主线程上。可以使用例如DispatchQueue.main.async或者MainActor.run等形式。

### interactiveDismissDisabled ###

SwiftUI 3.0的interactiveDismissDisabled加强版，在通过代码控制是否允许手势取消的基础上，增加了当用户使用手势取消时可以获得通知的能力。

更多信息请参阅[如何在SwiftUI中实现interactiveDismissDisabled](https://www.fatbobman.com/posts/newInteractiveDismissDiabled/)

> SheetKit中的interactiveDismissDisabled为了兼容bottomSheet做了一定的改动，具体改动请参见源代码。

```swift
struct ContentView: View {
    @State var sheet = false
    var body: some View {
        VStack {
            Button("show sheet") {
                sheet.toggle()
            }
        }
        .sheet(isPresented: $sheet) {
            SheetView()
        }
    }
}

struct SheetView: View {
    @State var disable = false
    @State var attempToDismiss = UUID()
    var body: some View {
        VStack {
            Button("disable: \(disable ? "true" : "false")") {
                disable.toggle()
            }
            .interactiveDismissDisabled(disable, attempToDismiss: $attempToDismiss)
        }
        .onChange(of: attempToDismiss) { _ in
            print("try to dismiss sheet")
        }
    }
}
```

![dismissSheet](https://cdn.fatbobman.com/dismissSheet.gif)

### clearBackground ###

将模态视图的背景设置为透明。在SwiftUI3.0中，已经可以使用原生API生成各种毛玻璃效果了。但只有将模态视图的背景设置为透明，毛玻璃效果才能显现出来。

在模态视图中：

```swift
.clearBackground()
```

例如：

```swift
        ZStack {
            Rectangle().fill(LinearGradient(colors: [.red, .green, .pink, .blue, .yellow, .cyan, .gray], startPoint: .topLeading, endPoint: .bottomTrailing))
            Button("Show bottomSheet") {
                sheetKit.present(with: .bottomSheet, afterPresent: { print("presented") }, onDisappear: { print("disappear") }, detentIdentifier: $detent) {
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                        VStack {
                            Text("Hello world")
                            Button("dismiss all") {
                                SheetKit().dismissAllSheets(animated: true, completion: {
                                    print("sheet has dismiss")
                                })
                            }
                        }
                    }
                    .clearBackground()
                    .ignoresSafeArea()
                }
            }
            .foregroundColor(.white)
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.green)
        }
        .ignoresSafeArea()
```

![Simulator Screen Shot - iPhone 13 Pro Max - 2021-09-16 at 19.19.34](https://cdn.fatbobman.com/Simulator%20Screen%20Shot%20-%20iPhone%2013%20Pro%20Max%20-%202021-09-16%20at%2019.19.34-1791208.png)

## 总结 ##

无论是[SheetKit](https://github.com/fatbobman/SheetKit)还是[NavigationViewKit](https://www.fatbobman.com/posts/NavigationViewKit/)都是我为开发新版的[健康笔记](https://www.fatbobman.com/healthnotes/)准备的扩展库。功能都是以我个人的需求为主。如果有什么其他的功能要求，请通过[twitter](https://www.twitter.com/fatbobman)、博客留言或者Issues等方式告诉我。

希望本文能够对你有所帮助。
