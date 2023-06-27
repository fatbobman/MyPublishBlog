---
date: 2023-02-16 08:12
description: 通过 Style 改变组件的外观或行为是 SwiftUI 提供的一项非常强大的功能。本文将介绍如何通过创建符合 ButtonStyle 或 PrimitiveButtonStyle 协议的实现，自定义 Button 的外观以及交互行为。
tags: SwiftUI
title:  自定义 Button 的外观和交互行为
image: images/custom-button-style-in-SwiftUI.png
mediumURL: https://medium.com/p/a080fb4915c1
---
通过 Style 改变组件的外观或行为是 SwiftUI 提供的一项非常强大的功能。本文将介绍如何通过创建符合 ButtonStyle 或 PrimitiveButtonStyle 协议的实现，自定义 Button 的外观以及交互行为。

> 可在 [此处](https://github.com/fatbobman/BlogCodes/tree/main/ButtonStyle) 获取本文的范例代码

## 定制 Button 的外观

按钮是 UI 设计中经常会使用到的组件。相较于 UIKit ，SwiftUI 通过 Button 视图，让开发者以少量的代码便可完成按钮的创建工作。

```swift
Button(action: signIn) {
    Text("Sign In")
}
```

多数情况下，开发者通过为 Button 的 `label` 参数提供不同的视图来定制按钮的外观。

```swift
struct RoundedAndShadowButton<V>:View where V:View {
    let label:V
    let action: () -> Void
    init(label: V, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }
    var body: some View {
        Button {
            action()
        } label: {
            label
                .foregroundColor(.white)
                .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundColor(.blue)
                    )
                .compositingGroup()
                .shadow(radius: 5,x:0,y:3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

let label = Label("Press Me", systemImage: "digitalcrown.horizontal.press.fill")

RoundedAndShadowButton(label: label, action: { pressAction("button view") })
```

![buttonView_2023-02-15_17.36.59.2023-02-15 17_38_28](https://cdn.fatbobman.com/buttonView_2023-02-15_17.36.59.2023-02-15%2017_38_28.gif)

```responser
id:1
```

## 使用 ButtonStyle 定制交互动画

遗憾的是，上面的代码无法修改按钮在点击后的按压效果。幸好，SwiftUI 提供了 ButtonStyle 协议可以帮助我们定制交互动画。

```swift
public protocol ButtonStyle {
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
    typealias Configuration = ButtonStyleConfiguration
}

public struct ButtonStyleConfiguration {
    public let role: ButtonRole?
    public let label: ButtonStyleConfiguration.Label
    public let isPressed: Bool
}
```

ButtonStyle 协议的使用方式与 ViewModifier 十分类似。通过 `ButtonStyleConfiguration` 提供的信息，开发者只需实现 `makeBody` 方法，即可完成交互动画的定制工作。

* label：目标按钮的当前视图，通常对应着 Button 视图中的 label 参数内容
* role：iOS 15 后新增的参数，用于标识按钮的角色（ 取消或具备破坏性）
* isPressed：当前按钮的按压状态，该信息是多数人使用 ButtonStyle 的原动力

```swift
struct RoundedAndShadowButtonStyle:ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .foregroundColor(.blue)
                )
            .compositingGroup()
        	// 根据 isPressing 来调整交互动画
            .shadow(radius:configuration.isPressed ? 0 : 5,x:0,y: configuration.isPressed ? 0 :3)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}

// 快捷引用
extension ButtonStyle where Self == RoundedAndShadowButtonStyle {
    static var roundedAndShadow:RoundedAndShadowButtonStyle {
        RoundedAndShadowButtonStyle()
    }
}
```

通过 buttonStyle 修饰器应用于 Button 视图

```swift
Button(action: { pressAction("rounded and shadow") }, label: { label })
       .buttonStyle(.roundedAndShadow)
```

![buttonStyle1_2023-02-15_18.27.17.2023-02-15 18_28_25](https://cdn.fatbobman.com/buttonStyle1_2023-02-15_18.27.17.2023-02-15%2018_28_25.gif)

创建一个通用性好 ButtonStyle 实现需要考虑很多条件，例如：role、controlSize、动态字体尺寸、色彩模式等等方面。同 ViewModifier 一样，可以通过环境值获取更多信息：

```swift
struct RoundedAndShadowProButtonStyle:ButtonStyle {
    @Environment(\.controlSize) var controlSize
    func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundColor(.white)
                .padding(getPadding())
                .font(getFontSize())
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundColor( configuration.role == .destructive ? .red : .blue)
                )
                .compositingGroup()
                .overlay(
                    VStack {
                        if configuration.isPressed {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.5))
                                .blendMode(.hue)
                        }
                    }
                    )
                .shadow(radius:configuration.isPressed ? 0 : 5,x:0,y: configuration.isPressed ? 0 :3)
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .animation(.spring(), value: configuration.isPressed)
    }

    func getPadding() -> EdgeInsets {
        let unit:CGFloat = 4
        switch controlSize {
            case .regular:
                return EdgeInsets(top: unit * 2, leading: unit * 4, bottom: unit * 2, trailing: unit * 4)
            case .large:
                return EdgeInsets(top: unit * 3, leading: unit * 5, bottom: unit * 3, trailing: unit * 5)
            case .mini:
                return EdgeInsets(top: unit / 2, leading: unit * 2, bottom: unit/2, trailing: unit * 2)
            case .small:
                return EdgeInsets(top: unit, leading: unit * 3, bottom: unit, trailing: unit * 3)
            @unknown default:
                fatalError()
        }
    }

    func getFontSize() -> Font {
        switch controlSize {
            case .regular:
                return .body
            case .large:
                return .title3
            case .small:
                return .callout
            case .mini:
                return .caption2
            @unknown default:
                fatalError()
        }
    }
}

extension ButtonStyle where Self == RoundedAndShadowProButtonStyle {
    static var roundedAndShadowPro:RoundedAndShadowProButtonStyle {
        RoundedAndShadowProButtonStyle()
    }
}

// 使用
HStack {
    Button(role: .destructive, action: { pressAction("rounded and shadow pro") }, label: { label })
        .buttonStyle(.roundedAndShadowPro)
        .controlSize(.large)
    Button(action: { pressAction("rounded and shadow pro") }, label: { label })
        .buttonStyle(.roundedAndShadowPro)
        .controlSize(.small)
}
```

![image-20230215183940567](https://cdn.fatbobman.com/image-20230215183940567.png)

## 使用 PrimitiveButtonStyle 定制交互行为

在 SwiftUI 中，Button 默认的交互行为是在松开按钮的同时执行 Button 指定的操作。并且，在点击按钮后，只要手指（ 鼠标 ）不松开，无论移动到哪里（ 移动到 Button 视图之外 ），松开后仍会执行指定操作。

尽管 Button 的默认手势与 `TapGestur` 单击操作类似，~~但 Button 的手势是一种不可撤销的操作~~。而 TapGesture 在不松开手指的情况下，如果移动到可点击区域外，SwiftUI 将不会调用 onEnded 闭包中的操作。

> 经网友 [@Yoo_Das](https://twitter.com/Yoo_Das) 的反馈，上文中 “Button 的手势是一种不可撤销的操作” 的描述不够准确。Button 的手势可以被视为有条件的可撤销操作。在按下按钮后，当手指移动的距离超出了系统预设的距离余量（ 不清楚明确值 ）后再松开，按钮闭包并不会被调用。

假如，我们想达成与 TapGesture 类似的效果（ 可撤销按钮 ），则可以通过 SwiftUI 提供的另一个协议 PrimitiveButtonStyle 来实现。

```swift
public protocol PrimitiveButtonStyle {
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
    typealias Configuration = PrimitiveButtonStyleConfiguration
}

public struct PrimitiveButtonStyleConfiguration {
    public let role: ButtonRole?
    public let label: PrimitiveButtonStyleConfiguration.Label
    public func trigger()
}
```

PrimitiveButtonStyle 与 ButtonStyle 两者之间最大的不同是，PrimitiveButtonStyle 要求开发者必须通过自行完成交互操作逻辑，并在适当的时机调用 trigger 方法（ 可以理解为 Button 的 action 参数对应的闭包 ）。

```swift
struct CancellableButtonStyle:PrimitiveButtonStyle {
    @GestureState var isPressing = false

    func makeBody(configuration: Configuration) -> some View {
        let drag = DragGesture(minimumDistance: 0)
            .updating($isPressing, body: {_,pressing,_ in
                if !pressing { pressing = true}
            })

        configuration.label
            .foregroundColor(.white)
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .foregroundColor( configuration.role == .destructive ? .red : .blue)
            )
            .compositingGroup()
            .shadow(radius:isPressing ? 0 : 5,x:0,y: isPressing ? 0 :3)
            .scaleEffect(isPressing ? 0.95 : 1)
            .animation(.spring(), value: isPressing)
            // 获取点击状态
            .gesture(drag)
            .simultaneousGesture(TapGesture().onEnded{
                configuration.trigger() // 执行 Button 指定的操作
            })
    }
}

extension PrimitiveButtonStyle where Self == CancellableButtonStyle {
    static var cancellable:CancellableButtonStyle {
        CancellableButtonStyle()
    }
}
```

![cancallableStyle_2023-02-15_19.06.47.2023-02-15 19_08_00](https://cdn.fatbobman.com/cancallableStyle_2023-02-15_19.06.47.2023-02-15%2019_08_00.gif)

或许有人会说，既然上面的代码可以通过 DragGesture 模拟获取到点击状态，那么完全可以不使用 PrimitiveButtonStyle 实现同样的效果。如此一来**使用 Style 的优势在哪里呢**？

* ButtonStyle 和 PrimitiveButtonStyle 是专门针对按钮的样式 API ，它们不仅可以应用于 Button 视图，也可以应用于很多 SwiftUI 预置的系统按钮功能之上，例如：EditButton、Share、Link、NavigationLink（ 不在 List 中） 等。
* `keyboardShortcut` 修饰器也只能应用于 Button，视图 + TapGesture 无法设定快捷键。

无论是双击、长按、甚至通过体感触发，开发者均可以通过 PrimitiveButtonStyle 协议定制自己的按钮交互逻辑。

```responser
id:1
```

## 系统预置的 Style

从 iOS 15 开始，SwiftUI 在原有 PlainButtonStyle、DefaultButtonStyle 的基础上，提供了更加丰富的预置 Style。

* PlainButtonStyle：不对 Button 视图添加任何修饰
* BorderlessButtonStyle：多数情况下的默认样式，在未指定文字颜色的情况下，将文字修改为强调色
* BorderedButtonStyle：为按钮添加圆角矩形背景，使用 tint 颜色作为背景色
* BorderedProminentButtonStyle：为按钮添加圆角矩形背景，背景颜色为系统强调色

其中，PlainButtonStyle 除了可以应用于 Button 外，同时也会对 List 以及 Form 的单元格行为造成影响。默认情况下，即使单元格的视图中包含了多个按钮，SwiftUI 也只会将 List 的单元格视作一个按钮（ 点击后同时调用所有按钮的操作 ）。通过为 List 设置 PlainButtonStyle 风格，便可以调整这一行为，让一个单元格中的多个按钮可以被分别触发。

```swift
List {
    HStack {
        Button("11"){print("1")}
        Button("22"){print("2")}
    }
}
.buttonStyle(.plain)
```

## 注意事项

* 同 ViewModifier 不同，ButtonStyle 并不支持串联，Button 只会采用最靠近的 Style

```swift
VStack {
    Button("11"){print("1")} // plain
    Button("22"){print("2")} // borderless
        .buttonStyle(.borderless)
    Button("33"){print("3")} // borderedProminent
        .buttonStyle(.borderedProminent)
        .buttonStyle(.borderless)
}
.buttonStyle(.plain)
```

* 某些按钮样式在不同的上下文中的行为和外观会有较大差别，甚至不起作用。例如：无法为 List 中的 NavigationLink 设置样式
* 在 Button 的 label 视图或 ButtonStyle 实现中添加的手势操作（ 例如 TapGesture ）将导致 Button 不再调用其指定的闭包操作，附加手势需在 Button 之外添加（ 例如下文的 simultaneousGesture 实现 ）

## 为按钮添加 Trigger

在 SwiftUI 中，为了判断某个按钮是否被按下（ 尤其是系统按钮 ），我们通常会通过设置并行手势来添加 trigger ：

```swift
EditButton()
    .buttonStyle(.roundedAndShadowPro)
    .simultaneousGesture(TapGesture().onEnded{ print("pressed")}) // 设置并行手势
    .withTitle("edit button with simultaneous trigger")
```

不过，[上述方法在 macOS 下不起作用](https://twitter.com/fatbobman/status/1623643244994387968) 。通过 Style ，我们可以在设置按钮样式时为其添加触发器：

```swift
struct TriggerActionStyle:ButtonStyle {
    let trigger:() -> Void
    init(trigger: @escaping () -> Void) {
        self.trigger = trigger
    }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .foregroundColor(.blue)
                )
            .compositingGroup()
            .shadow(radius:configuration.isPressed ? 0 : 5,x:0,y: configuration.isPressed ? 0 :3)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(), value: configuration.isPressed)
            .onChange(of: configuration.isPressed){ isPressed in
                if !isPressed {
                    trigger()
                }
            }
    }
}

extension ButtonStyle where Self == TriggerActionStyle {
    static func triggerAction(trigger perform:@escaping () -> Void) -> TriggerActionStyle {
        .init(trigger: perform)
    }
}
```

![trigger1_2023-02-15_20.08.05.2023-02-15 20_09_17](https://cdn.fatbobman.com/trigger1_2023-02-15_20.08.05.2023-02-15%2020_09_17.gif)

当然，用 PrimitiveButtonStyle 也一样可以实现：

```swift
struct TriggerButton2: PrimitiveButtonStyle {
    var trigger: () -> Void

    func makeBody(configuration: PrimitiveButtonStyle.Configuration) -> some View {
        MyButton(trigger: trigger, configuration: configuration)
    }

    struct MyButton: View {
        @State private var pressed = false
        var trigger: () -> Void

        let configuration: PrimitiveButtonStyle.Configuration

        var body: some View {
            return configuration.label
                .foregroundColor(.white)
                .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundColor(.blue)
                )
                .compositingGroup()
                .shadow(radius: pressed ? 0 : 5, x: 0, y: pressed ? 0 : 3)
                .scaleEffect(pressed ? 0.95 : 1)
                .animation(.spring(), value: pressed)
                .onLongPressGesture(minimumDuration: 2.5, maximumDistance: .infinity, pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.pressed = pressing
                    }
                    if pressing {
                        configuration.trigger() // 原来的 action
                        trigger() // 新增的 action
                    } else {
                        print("release")
                    }
                }, perform: {})
        }
    }
}
```

![trigger2_2023-02-15_20.15.56.2023-02-15 20_16_30](https://cdn.fatbobman.com/trigger2_2023-02-15_20.15.56.2023-02-15%2020_16_30.gif)

## 总结

尽管自定义 Style 的效果显著，但遗憾的是，目前 SwiftUI 仅开放了少数的组件样式协议供开发者自定义使用，并且提供的属性也很有限。希望在未来的版本中，SwiftUI 可以为开发者提供更加强大的自定义组件能力。

希望本文能够对你有所帮助。同时也欢迎你通过 [Twitter](https://twitter.com/fatbobman)、 [Discord 频道](https://discord.gg/ApqXmy5pQJ) 或博客的留言板与我进行交流。

**订阅下方的 [邮件列表](https://artisanal-knitter-2544.ck.page/d3591dd1e7)，可以及时获得每周的 Tips 汇总。**
