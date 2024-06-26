---
date: 2020-09-04 12:00
description: Sheet 是一个我比较喜欢的交互形式，它可以很好的控制用户的操作行为，让用户的交互逻辑单线条化。在 iOS14 上，SwiftUI 增加了 fullCover，支持了全屏的 Sheet 方式，让开发者又了更多的选择。
title: 在 SwiftUI 中，根据需求弹出不同的 Sheet
tags: SwiftUI
---

Sheet 是一个我比较喜欢的交互形式，它可以很好的控制用户的操作行为，让用户的交互逻辑单线条化。在 iOS14 上，SwiftUI 增加了 fullCover，支持了全屏的 Sheet 方式，让开发者又了更多的选择。

```responser
id:1
```

## 基本用法 ##

```swift
@State var showView1 = false
@State var showView2 = false

List{
    Button("View1"){
      showView1.toggle()
    }
  .sheet(isPresented:$showView1){
    Text("View1")
  }
  
  Button("View2"){
    showView2.toggle()
  }
  .sheet(isPresented:$showView2){
    Text("View2")
  }
}
```

上述代码，我们可以通过点击不同的按钮而弹出相对应的 View。

不过它有两个缺点：

1. 如果你的代码有多处需要使用不同 view 作为 sheet 的情况，你需要声明多个对应的开关值
2. 如果你的 View 结构比较复杂，在比较内部的地方，上述代码很可能无法激发 sheet 的显示（这个问题在 ios13 上就存在，在 ios14 上仍有这样的情况。我至今也没有完全总结出规律）

## 使用 Item 来对应不同的 View ##

好在 sheet 提供了另外一种激活方式

```swift
.sheet(item: Binding<Identifiable?>, content: (Identifiable) -> View)
```

我们可以使用它来完成只响应一个激活变量，而显示所需的不同 View

```swift
struct View1:View{
    @Environment(\.presentationMode) var presentationMode
    let text:String
    var body: some View{
        NavigationView{
            VStack{
            Text(text)
            Text("View1")
            }
                .toolbar{
                    ToolbarItem(placement: ToolbarItemPlacement.navigationBarLeading){
                        Button("cancel"){
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        }
    }
    
}

struct View2:View{
    @Environment(\.presentationMode) var presentationMode
    var body: some View{
        NavigationView{
            Text("View2")
                .toolbar{
                    ToolbarItem(placement: ToolbarItemPlacement.navigationBarLeading){
                        Button("cancel"){
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        }
    }
    
}

```

先准备两个需要显示的 View

```swift
struct SheetUsingAnyView: View {
    @State private var sheetView:AnyView?
    var body: some View {
        NavigationView{
            List{
                Button("View1"){
                    sheetView = AnyView(View1(text:"Hello world"))
                }
                Button("View2"){
                    sheetView = AnyView(View2())
                }
            }
            .listStyle(InsetGroupedListStyle())
            .sheet(item: $sheetView){ view in
               view
            }
            .navigationTitle("AnyView")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

extension AnyView:Identifiable{
    public var id:UUID{UUID()}
}
```

通过上述代码，我们便可以通过给 sheetView 赋予不同的值来实现弹出对应的 View。

这个解决方案非常的便捷，不过也存在两个问题：

1. 在极个别的情况下，当 app 进入后台（此时 app 的 sheet 处于显示状态），再从后台重新显示时会出现程序崩溃情况。这个问题在 ios13 和目前的 ios14（测试到 beta5）都可能出现。不过出现的前提是你的代码的显示层级要足够复杂，如果代码比较简单，通常是可以正常运行的。

   对于这个崩溃的情况，错误和调试代码给的信息都很不准确，估计应该和 View 的初始化冲突有关。

2. 指令不清晰。如果赋值给 sheetView 的 View 参数很多，你的代码的可读性会比较差

## 采用 Reducer 的思路解决问题 ##

其实对于每一个 View，我们也都可以按照 MVVM 的思路来构建它自己的 mini 状态机（我的另一篇关于 Form 的文章也是这样的思路）。

```swift
struct SheetUsingEnum: View {
    @State private var sheetAction:SheetAction?
    var body: some View {
        NavigationView{
            List{
                Button("view1"){
                    sheetAction = .view1(text:"Test")
                }
                Button("view2"){
                    sheetAction = .view2
                }
            }
            .listStyle(InsetGroupedListStyle())
            .sheet(item: $sheetAction){ action in
                getActionView(action)
            }
            .navigationTitle("Enum")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func getActionView(_ action:SheetAction) -> some View{
        switch action{
        case .view1(let text):
            return AnyView(View1(text: text))
        case .view2:
            return AnyView(View2())
        }
    }
}

enum SheetAction:Identifiable{
    case view1(text:String)
    case view2
    
    var id:UUID{
        UUID()
    }
}

```

比较直接使用 AnyView，代码量稍微增多了点，不过第一没有了崩溃的可能性，同时代码的易读性也得到了提高。

## 解决某些 View 无法激活 Sheet 的问题 ##

关于在某些 View 上无法激活 Sheet，我目前的解决方案是 bind 它的父 View 的 sheetAction，通过父 View 来激活 Sheet。通过枚举的相关值来传递所需的数据。

**更新**: 在 iOS14 下，使用 item 来激活 sheet, 在某些特殊场合可能会导致 app（打开 sheet 的情况下）从后台返回时会发生错误甚至崩溃。所以上述代码中对于 sheet 的激活，已经作出了更改。更改后的代码已经统一到了 [在 SwiftUI 中制作可以控制取消手势的 Sheet](/posts/swiftui-dismiss-sheet/)

[可以在此下载项目完整代码](https://github.com/fatbobman/DismissConfirmSheet)

