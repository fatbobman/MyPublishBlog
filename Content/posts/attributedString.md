---
date: 2021-10-08 08:20
description: 在WWDC 2021上，苹果为开发者带来了有一个期待已久的功能——AttributedString，这意味着Swift开发人员不再需要使用基于Objective-C的NSAttributedString来创建样式化文本。本文将对其做全面的介绍并演示如何创建自定义属性。
tags: SwiftUI,Foundation
title:  AttributedString——不仅仅让文字更漂亮
image: images/attributedString.png
---
在WWDC 2021上，苹果为开发者带来了有一个期待已久的功能——AttributedString，这意味着Swift开发人员不再需要使用基于Objective-C的NSAttributedString来创建样式化文本。本文将对其做全面的介绍并演示如何创建自定义属性。

## 初步印象 ##

AttributedString是具有单个字符或字符范围的属性的字符串。属性提供了一些特征，如用于显示的视觉风格、用于无障碍引导以及用于在数据源之间进行链接的超链接数据等。

下面的代码将生成一个包含粗体以及超链接的属性字符串。

```swift
var attributedString = AttributedString("请访问肘子的博客")
let zhouzi = attributedString.range(of: "肘子")!  // 获取肘子二字的范围（Range）
attributedString[zhouzi].inlinePresentationIntent = .stronglyEmphasized // 设置属性——粗体
let blog = attributedString.range(of: "博客")! 
attributedString[blog].link = URL(string: "https://www.fatbobman.com")! // 设置属性——超链接
```

![image-20211007165456612](https://cdn.fatbobman.com/image-20211007165456612.png)

在WWDC 2021之前，SwiftUI没有提供对属性字符串的支持，如果我们希望显示具有丰富样式的文本，通常会采用以下三种方式：

* 将UIKit或AppKit控件包装成SwiftUI控件，在其中显示NSAttributedString
* 通过代码将NSAttributedString转换成对应的SwiftUI布局代码
* 使用SwiftUI的原生控件组合显示

下面的文字随着SwiftUI版本的变化，可采取的手段也在不断地增加（不使用NSAttributedString）：

![image-20211006163659029](https://cdn.fatbobman.com/image-20211006163659029.png)

***SwiftUI 1.0***

```swift
    @ViewBuilder
    var helloView:some View{
        HStack(alignment:.lastTextBaseline, spacing:0){
            Text("Hello").font(.title).foregroundColor(.red)
            Text(" world").font(.callout).foregroundColor(.cyan)
        }
    }
```

***SwiftUI 2.0***

SwiftUI 2.0增强了Text的功能，我们可以将不同的Text通过`+`合并显示

```swift
    var helloText:Text {
        Text("Hello").font(.title).foregroundColor(.red) + Text(" world").font(.callout).foregroundColor(.cyan)
    }
```

***SwiftUI 3.0***

除了上述的方法外，Text添加了对AttributedString的原生支持

```swift
    var helloAttributedString:AttributedString {
        var hello = AttributedString("Hello")
        hello.font = .title.bold()
        hello.foregroundColor = .red
        var world = AttributedString(" world")
        world.font = .callout
        world.foregroundColor = .cyan
        return hello + world
    }

    Text(helloAttributedString)
```

> 单纯看上面的例子，并不能看到AttributedString有什么优势。相信随着继续阅读本文，你会发现AttributedString可以实现太多以前想做而无法做到的功能和效果。

## AttributedString vs NSAttributedString ##

AttributedString基本上可以看作是NSAttributedString的Swift实现，两者在功能和内在逻辑上差别不大。但由于形成年代、核心代码语言等，两者之间仍有不少的区别。本节将从多个方面对它们进行比较。

### 类型 ###

AttributedString是值类型的，这也是它同由Objective-C构建的NSAttributedString（引用类型）之间最大的区别。这意味着它可以通过Swift的值语义，像其他值一样被传递、复制和改变。

NSAttributedString 可变或不可变需不同的定义

```swift
let hello = NSMutableAttributedString("hello")
let world = NSAttributedString(" world")
hello.append(world)
```

AttributedString

```swift
var hello = AttributedString("hello")
let world = AttributedString(" world")
hello.append(world)
```

### 安全性 ###

在AttributedString中需要使用Swift的点或键语法按名称访问属性，不仅可以保证类型安全，而且可以获得编译时检查的优势。

AttributedString中基本不采用NSAttributedString如下的属性访问方式，极大的减少出错几率

```swift
// 可能出现类型不匹配
let attributes: [NSAttributedString.Key: Any] = [
    .font: UIFont.systemFont(ofSize: 72),
    .foregroundColor: UIColor.white,
]
```

### 本地化支持 ###

Attributed提供了原生的本地化字符串支持，并可为本地化字符串添加了特定属性。

```swift
var localizableString = AttributedString(localized: "Hello \(Date.now,format: .dateTime) world",locale: Locale(identifier: "zh-cn"),option:.applyReplacementIndexAttribute)
```

### Formatter支持 ###

同为WWDC 2021中推出的新Formatter API全面支持了AttributedString类型的格式化输出。我们可以轻松实现过去无法完成的工作。

```swift
var dateString: AttributedString {
        var attributedString = Date.now.formatted(.dateTime
            .hour()
            .minute()
            .weekday()
            .attributed
        )
        let weekContainer = AttributeContainer()
            .dateField(.weekday)
        let colorContainer = AttributeContainer()
            .foregroundColor(.red)
        attributedString.replaceAttributes(weekContainer, with: colorContainer)
        return attributedString
}

Text(dateString)
```

![image-20211006183053713](https://cdn.fatbobman.com/image-20211006183053713.png)

> 更多关于新Formatter API同AttributedString配合范例，请参阅[WWDC 2021新Formatter API：新老比较及如何自定义](https://www.fatbobman.com/posts/newFormatter/)

### SwiftUI集成 ###

SwiftUI的Text组件提供了对AttributedString的原生支持，改善了一个SwiftUI的长期痛点（不过TextField、TextEdit仍不支持）。

AttributedString同时提供了SwiftUI、UIKit、AppKit三种框架的可用属性。UIKit或AppKit的控件同样可以渲染AttributedString（需经过转换）。

### 支持的文件格式 ###

AttributedString目前仅具备对Markdown格式文本进行解析的能力。同NSAttributedString支持Markdown、rtf、doc、HTML相比仍有很大差距。

### 转换 ###

苹果为AttributedString和NSAttributedString提供了相互转换的能力。

```swift
// AttributedString -> NSAttributedString
let nsString = NSMutableAttributedString("hello")
var attributedString = AttributedString(nsString)

// NSAttribuedString -> AttributedString
var attString = AttributedString("hello")
attString.uiKit.foregroundColor = .red
let nsString1 = NSAttributedString(attString)
```

开发者可以充分利用两者各自的优势进行开发。比如：

* 用NSAttributedString解析HTML，然后转换成AttributedString调用
* 用AttributedString创建类型安全的字符串，在显示时转换成NSAttributedString

## 基础 ##

本节中，我们将对AttributedString中的一些重要概念做介绍，并通过代码片段展示AttributedString更多的用法。

### AttributedStringKey ###

AttributedStringKey定义了AttributedString属性名称和类型。通过点语法或KeyPath，在保证类型安全的前提进行快捷访问。

```swift
var string = AttributedString("hello world")
// 使用点语法
string.font = .callout
let font = string.font 

// 使用KeyPath
let font = string[keyPath:\.font] 
```

除了使用系统预置的大量属性外，我们也可以创建自己的属性。例如：

```swift
enum OutlineColorAttribute : AttributedStringKey {
    typealias Value = Color // 属性类型
    static let name = "OutlineColor" // 属性名称
}

string.outlineColor = .blue
```

> 我们可以使用点语法或KeyPath对 AttributedString、AttributedSubString、AttributeContainer以及AttributedString.Runs.Run的属性进行访问。更多用法参照本文其他的代码片段。

### AttributeContainer ###

AttributeContainer是属性容器。通过配置container，我们可以一次性地为属性字符串（或片段）设置、替换、合并大量的属性。

***设置属性***

```swift
var attributedString = AttributedString("Swift")
string.foregroundColor = .red 

var container = AttributeContainer()
container.inlinePresentationIntent = .strikethrough
container.font = .caption
container.backgroundColor = .pink
container.foregroundColor = .green //将覆盖原来的red

attributedString.setAttributes(container) // attributdString此时拥有四个属性内容
```

***替换属性***

```swift
var container = AttributeContainer()
container.inlinePresentationIntent = .strikethrough
container.font = .caption
container.backgroundColor = .pink
container.foregroundColor = .green
attributedString.setAttributes(container)
// 此时attributedString有四个属性内容 font、backgroundColor、foregroundColor、inlinePresentationIntent

// 被替换的属性
var container1 = AttributeContainer()
container1.foregroundColor = .green
container1.font = .caption

// 将要替换的属性
var container2 = AttributeContainer()
container2.link = URL(string: "https://www.swift.org")

// 被替换属性contianer1的属性键值内容全部符合才可替换，比如continaer1的foregroundColor为.red将不进行替换
attributedString.replaceAttributes(container1, with: container2)
// 替换后attributedString有三个属性内容 backgroundColor、inlinePresentationIntent、link
```

***合并属性***

```swift
var container = AttributeContainer()
container.inlinePresentationIntent = .strikethrough
container.font = .caption
container.backgroundColor = .pink
container.foregroundColor = .green
attributedString.setAttributes(container)
// 此时attributedString有四个属性内容 font、backgroundColor、foregroundColor、inlinePresentationIntent

var container2 = AttributeContainer()
container2.foregroundColor = .red
container2.link = URL(string: "www.swift.org")

attributedString.mergeAttributes(container2,mergePolicy: .keepNew)
// 合并后attributedString有五个属性 ，font、backgroundColor、foregroundColor、inlinePresentationIntent及link 
// foreground为.red
// 属性冲突时，通过mergePolicy选择合并策略 .keepNew(默认) 或 .keepCurrent
```

### AttributeScope ###

属性范围是系统框架定义的属性集合，将适合某个特定域中的属性定义在一个范围内，一方面便于管理，另一方面也解决了不同框架下相同属性名称对应类型不一致的问题。

目前，AttributedString提供了5个预置的Scope，分别为

* foundation

  包含有关Formatter、Markdown、URL以及语言变形方面的属性

* swiftUI

  可以在SwiftUI下被渲染的属性，例如foregroundColor、backgroundColor、font等。目前支持的属性明显少于uiKit和appKit。估计待日后SwiftUI提供更多的显示支持后会逐步补上其他暂不支持的属性。

* uiKit

  可以在UIKit下被渲染的属性。

* appKit

  可以在AppKit下被渲染的属性

* accessibility

  适用于无障碍的属性，用于提高引导访问的可用性。

在swiftUI、uiKit和appKit三个scope中存在很多的同名属性（比如foregroundColor），在访问时需注意以下几点：

* 当Xcode无法正确推断该适用哪个Scope中的属性时，请显式标明对应的AttributeScope

```swift
uiKitString.uiKit.foregroundColor = .red //UIColor
appKitString.appKit.backgroundColor = .yellow //NSColor
```

* 三个框架的同名属性并不能互转，如想字符串同时支持多框架显示（代码复用），请分别为不同Scope的同名属性赋值

```swift
attributedString.swiftUI.foregroundColor = .red
attributedString.uiKit.foregroundColor = .red
attributedString.appKit.foregroundColor = .red

// 转换成NSAttributedString，可以只转换指定的Scope属性
let nsString = try! NSAttributedString(attributedString, including: \.uiKit)
```

* 为了提高兼容性，部分功能相同的属性，可以在foundation中设置。

```swift
attributedString.inlinePresentationIntent = .stronglyEmphasized //相当于 bold
```

* swiftUI、uiKit和appKit三个Scope在定义时，都已经分别包含了foundation和accessibility。因此在转换时即使只指定单一框架，foundation和accessibility的属性也均可正常转换。我们在自定义Scope时，最好也遵守该原则。

```swift
let nsString = try! NSAttributedString(attributedString, including: \.appKit)
// attributedString中属于foundation和accessibility的属性也将一并被转换
```

### 视图 ###

在属性字符串中，属性和文本可以被独立访问，AttributedString提供了三种视图方便开发者从另一个维度访问所需的内容。

#### Character和unicodeScalar视图 ####

这两个视图提供了类似NSAttributedString的string属性的功能，让开发者可以在纯文本的维度操作数据。两个视图的唯一区别是类型不同，简单来说，你可以把ChareacterView看作是Charecter集合，而UnicodeScalarView看作是Unicode标量合集。

字符串长度

```swift
var attributedString = AttributedString("Swift")
attributedString.characters.count // 5
```

长度2

```swift
let attributedString = AttributedString("hello 👩🏽‍🦳")
attributedString.characters.count // 7
attributedString.unicodeScalars.count // 10
```

转换成字符串

```swift
String(attributedString.characters) // "Swift"
```

替换字符串

```swift
var attributedString = AttributedString("hello world")
let range = attributedString.range(of: "hello")!
attributedString.characters.replaceSubrange(range, with: "good")
// good world ,替换后的good仍会保留hello所在位置的所有属性
```

#### Runs视图 ####

AttributedString的属性视图。每个Run对应一个属性完全一致的字符串片段。用for-in语法来迭代AttributedString的runs属性。

***只有一个Run***

整个属性字符串中所有的字符属性都一致

```swift
let attributedString = AttribuedString("Core Data")
print(attributedString)
// Core Data {}
print(attributedString.runs.count) // 1
```

***两个Run***

属性字符串`coreData`，`Core`和` Data`两个片段的属性不相同，因此产生了两个Run

```swift
var coreData = AttributedString("Core")
coreData.font = .title
coreData.foregroundColor = .green
coreData.append(AttributedString(" Data"))

for run in coreData.runs { //runs.count = 2
    print(run)
}

// Core { 
//      SwiftUI.Font = Font(provider: SwiftUI.(unknown context at $7fff5cd3a0a0).FontBox<SwiftUI.Font.(unknown context at $7fff5cd66db0).TextStyleProvider>)
//      SwiftUI.ForegroundColor = green
//      }
// Data {}
```

***多个Run***

```swift
var multiRunString = AttributedString("The attributed runs of the attributed string, as a view into the underlying string.")
while let range = multiRunString.range(of: "attributed") {
    multiRunString.characters.replaceSubrange(range, with: "attributed".uppercased())
    multiRunString[range].inlinePresentationIntent = .stronglyEmphasized
}
var n = 0
for run in multiRunString.runs {
    n += 1
}
// n = 5
```

最终结果：The **ATTRIBUTED** runs of the **ATTRIBUTED** string, as a view into the underlying string.

***利用Run的range进行属性设置***

```swift
// 继续使用上文的multiRunString
// 将所有非强调字符设置为黄色
for run in multiRunString.runs {
    guard run.inlinePresentationIntent != .stronglyEmphasized else {continue}
    multiRunString[run.range].foregroundColor = .yellow
}
```

***通过Runs获取指定的属性***

```swift
// 将颜色为黄色且为粗体的文字改成红色
for (color,intent,range) in multiRunString.runs[\.foregroundColor,\.inlinePresentationIntent] {
    if color == .yellow && intent == .stronglyEmphasized {
        multiRunString[range].foregroundColor = .red
    }
}
```

***通过Run的attributes收集所有使用到的属性***

```swift
var totalKeysContainer = AttributeContainer()
for run in multiRunString.runs{
    let container = run.attributes
    totalKeysContainer.merge(container)
}
```

> 使用Runs视图可以方便的从众多属性中获取到需要的信息

***不使用Runs视图，达到类似的效果***

```swift
multiRunString.transformingAttributes(\.foregroundColor,\.font){ color,font in
    if color.value == .yellow && font.value == .title {
        multiRunString[color.range].backgroundColor = .green
    }
}
```

> 尽管没有直接调用Runs视图，不过transformingAttributes闭包的调用时机同Runs的时机是一致的。transformingAttributes最多支持获取5个属性。

### Range ###

在本文之前的代码中，已经多次使用过Range来对属性字符串的内容进行访问或修改。

对属性字符串中局部内容的属性进行修改可以使用两种方式：

* 通过Range
* 通过AttributedContainer

***通过关键字获取Range***

```swift
// 从属性字符串的结尾向前查找，返回第一个满足关键字的range(忽略大小写)
if let range = multiRunString.range(of: "Attributed", options: [.backwards, .caseInsensitive]) {
    multiRunString[range].link = URL(string: "https://www.apple.com")
}
```

***使用Runs或transformingAttributes获取Range***

之前的例子中已反复使用

***通过本文视图获取Range***

```swift
if let lowBound = multiRunString.characters.firstIndex(of: "r"),
   let upperBound = multiRunString.characters.firstIndex(of: ","),
   lowBound < upperBound
{
    multiRunString[lowBound...upperBound].foregroundColor = .brown
}
```

## 本地化 ##

### 创建本地化属性字符串 ###

```swift
// Localizable Chinese
"hello" = "你好";
// Localizable English
"hello" = "hello";

let attributedString = AttributedString(localized: "hello")
```

在英文和中文环境中，将分别显示为`hello` 和 `你好`

> 目前本地化的AttributedString只能显示为当前系统设置的语言，并不能指定成某个特定的语言

```swift
var hello = AttributedString(localized: "hello")
if let range = hello.range(of: "h") {
    hello[range].foregroundColor = .red
}
```

本地化字符串的文字内容将随系统语言而变化，上面的代码在中文环境下将无法获取到range。需针对不同的语言做调整。

### replacementIndex ###

可以为本地化字符串的插值内容设定index（通过`applyReplacementIndexAttribute`）,方便在本地化内容中查找

```swift
// Localizable Chinese
"world %@ %@" = "%@ 世界 %@";
// Localizable English
"world %@ %@" = "world %@ %@";

var world = AttributedString(localized: "world \("👍") \("🥩")",options: .applyReplacementIndexAttribute) // 创建属性字符串时，将按照插值顺序设定index ，👍 index == 1 🥩 index == 2

for (index,range) in world.runs[\.replacementIndex] {
    switch index {
        case 1:
            world[range].baselineOffset = 20
            world[range].font = .title
        case 2:
            world[range].backgroundColor = .blue
        default:
            world[range].inlinePresentationIntent = .strikethrough
    }
}
```

在中文和英文环境中，分别为：

![image-20211007083048701](https://cdn.fatbobman.com/image-20211007083048701-3566650.png)

![image-20211007083115822](https://cdn.fatbobman.com/image-20211007083115822.png)

### 使用locale设定字符串插值中的Formatter ###

```swift
 AttributedString(localized: "\(Date.now, format: Date.FormatStyle(date: .long))", locale: Locale(identifier: "zh-cn"))
// 即使在英文环境中也会显示 2021年10月7日
```

### 用Formatter生成属性字符串 ###

```swift
        var dateString = Date.now.formatted(.dateTime.year().month().day().attributed)
        dateString.transformingAttributes(\.dateField) { dateField in
            switch dateField.value {
            case .month:
                dateString[dateField.range].foregroundColor = .red
            case .day:
                dateString[dateField.range].foregroundColor = .green
            case .year:
                dateString[dateField.range].foregroundColor = .blue
            default:
                break
            }
        }
```

![image-20211007084630319](https://cdn.fatbobman.com/image-20211007084630319.png)

### Markdown符号 ###

从SwiftUI 3.0开始，Text已经对部分Markdown标签提供了支持。在本地化的属性字符串中，也提供了类似的功能，并且会在字符串中设置对应的属性。提供了更高的灵活性。

```swift
var markdownString = AttributedString(localized: "**Hello** ~world~ _!_")
for (inlineIntent,range) in markdownString.runs[\.inlinePresentationIntent] {
    guard let inlineIntent = inlineIntent else {continue}
    switch inlineIntent{
        case .stronglyEmphasized:
            markdownString[range].foregroundColor = .red
        case .emphasized:
            markdownString[range].foregroundColor = .green
        case .strikethrough:
            markdownString[range].foregroundColor = .blue
        default:
            break
    }
}
```

![image-20211007085859409](https://cdn.fatbobman.com/image-20211007085859409.png)

## Markdown解析 ##

AttributedString不仅可以在本地化字符串中支持部分的Markdown标签，并且提供了一个完整的Markdown解析器。

支持从String、Data或URL中解析Markdown文本内容。

比如:

```swift
let mdString = try! AttributedString(markdown: "# Title\n**hello**\n")
print(mdString)

// 解析结果
Title {
    NSPresentationIntent = [header 1 (id 1)]
}
hello {
    NSInlinePresentationIntent = NSInlinePresentationIntent(rawValue: 2)
    NSPresentationIntent = [paragraph (id 2)]
}
```

解析后会将文字风格和标签设置在`inlinePresentationIntent`和`presentationIntent`中。

* inlinePresentationIntent

  字符性质：比如粗体、斜体、代码、引用等

* presentationIntent

  段落属性：比如段落、表格、列表等。一个Run中，presentationIntent可能会有多个内容，用component来获取。

README.md

```swift
#  Hello 

## Header2

hello **world**

* first
* second

> test `print("hello world")`

| row1 | row2 |
| ---- | ---- |
| 34   | 135  |

[新Formatter介绍](/posts/newFormatter/)
```

解析代码：

```swift
let url = Bundle.main.url(forResource: "README", withExtension: "md")!
var markdownString = try! AttributedString(contentsOf: url,baseURL: URL(string: "https://www.fatbobman.com"))
```

解析后结果（节选）：

```swift
Hello {
    NSPresentationIntent = [header 1 (id 1)]
}
Header2 {
    NSPresentationIntent = [header 2 (id 2)]
}
first {
    NSPresentationIntent = [paragraph (id 6), listItem 1 (id 5), unorderedList (id 4)]
}

test  {
    NSPresentationIntent = [paragraph (id 10), blockQuote (id 9)]
}
print("hello world") {
    NSPresentationIntent = [paragraph (id 10), blockQuote (id 9)]
    NSInlinePresentationIntent = NSInlinePresentationIntent(rawValue: 4)
}
row1 {
    NSPresentationIntent = [tableCell 0 (id 13), tableHeaderRow (id 12), table [Foundation.PresentationIntent.TableColumn(alignment: Foundation.PresentationIntent.TableColumn.Alignment.left), Foundation.PresentationIntent.TableColumn(alignment: Foundation.PresentationIntent.TableColumn.Alignment.left)] (id 11)]
}
row2 {
    NSPresentationIntent = [tableCell 1 (id 14), tableHeaderRow (id 12), table [Foundation.PresentationIntent.TableColumn(alignment: Foundation.PresentationIntent.TableColumn.Alignment.left), Foundation.PresentationIntent.TableColumn(alignment: Foundation.PresentationIntent.TableColumn.Alignment.left)] (id 11)]
}
新Formatter介绍 {
    NSPresentationIntent = [paragraph (id 18)]
    NSLink = /posts/newFormatter/ -- https://www.fatbobman.com
}
```

解析后的内容包括段落属性、标题号、表格列数、行数、对齐方式等。缩紧、标号等其他信息可以在代码中可以通过枚举关联值来处理。

大致的代码如下：

```swift
for run in markdownString.runs {
    if let inlinePresentationIntent = run.inlinePresentationIntent {
        switch inlinePresentationIntent {
        case .strikethrough:
            print("删除线")
        case .stronglyEmphasized:
            print("粗体")
        default:
            break
        }
    }
    if let presentationIntent = run.presentationIntent {
        for component in presentationIntent.components {
            switch component.kind{
                case .codeBlock(let languageHint):
                    print(languageHint)
                case .header(let level):
                    print(level)
                case .paragraph:
                    let paragraphID = component.identity
                default:
                    break
            }
        }
    }
}
```

> SwiftUI并不支持presentationIntent附加信息的渲染。如果想获得理想的显示效果，请自行编写视觉风格设置代码。

## 自定义属性 ##

使用自定义属性，不仅有利于开发者创建更符合自身要求的属性字符串，而且通过在Markdown文本中添加自定义属性信息，进一步降低信息和代码的耦合度，提高灵活度。

自定义属性的基本流程为：

* 创建自定义AttributedStringKey

  为每个需要添加的属性创建一个符合Attributed协议的数据类型。

* 创建自定义AttributeScope并扩展AttributeScopes

  创建自己的Scope，并在其中添加所有的自定义属性。为了方便自定义属性集被用于需要指定Scope的场合，在自定义Scope中推荐嵌套入需要的系统框架Scope（swiftUI、uiKit、appKit）。并在AttributeScopes中添加上自定义的Scope。

* 扩展AttributeDynamicLookup（支持点语法）

  在AttributeDynamicLookup中创建符合自定义Scope的下标方法。为点语法、KeyPath提供动态支持。

### 实例1：创建id属性 ###

本例中我们将创建一个名称为id的属性。

```swift
struct MyIDKey:AttributedStringKey {
    typealias Value = Int // 属性内容的类型。类型需要符合Hashable
    static var name: String = "id" // 属性字符串内部保存的名称
}

extension AttributeScopes{
    public struct MyScope:AttributeScope{
        let id:MyIDKey  // 点语法调用的名称
        let swiftUI:SwiftUIAttributes // 在我的Scope中将系统框架swiftUI也添加进来
    }

    var myScope:MyScope.Type{
        MyScope.self
    }
}

extension AttributeDynamicLookup{
    subscript<T>(dynamicMember keyPath:KeyPath<AttributeScopes.MyScope,T>) -> T where T:AttributedStringKey {
        self[T.self]
    }
}
```

调用

```swift
var attribtedString = AttributedString("hello world")
attribtedString.id = 34
print(attribtedString)


// Output
hello world {
    id = 34
}
```

### 实例2：创建枚举属性，并支持Markdown解析 ###

如果我们希望自己创建的属性可以在Markdown文本中被解析，需要让自定义的属性符合`CodeableAttributedStringKey`以及`MarkdownDecodableAttributedStringKye`

```swift
// 自定义属性的数据类型不限，只要满足需要的协议即可
enum PriorityKey:CodableAttributedStringKey,MarkdownDecodableAttributedStringKey{
    public enum Priority:String,Codable{ //如需在Markdown中解析，需要将raw类型设置为String,并符合Codable
        case low
        case normal
        case high
    }

    static var name: String = "priority"
    typealias Value = Priority
}

extension AttributeScopes{
    public struct MyScope:AttributeScope{
        let id:MyIDKey
        let priority:PriorityKey // 将新创建的Key也添加到自定义的Scope中
        let swiftUI:SwiftUIAttributes
    }

    var myScope:MyScope.Type{
        MyScope.self
    }
}
```

> 在Markdown中使用`^[text](属性名称：属性值)`来标记自定义属性

调用

```swift
// 在Markdown文本中解析自定义属性时，需指明Scope。
var attributedString = AttributedString(localized: "^[hello world](priority:'low')",including: \.myScope)
print(attributedString)

// Output
hello world {
    priority = low
    NSLanguage = en
}
```

### 实例3：创建多参数的属性 ###

```swift
enum SizeKey:CodableAttributedStringKey,MarkdownDecodableAttributedStringKey{
    public struct Size:Codable,Hashable{
        let width:Double
        let height:Double
    }

    static var name: String = "size"
    typealias Value = Size
}

// 在Scope中添加
let size:SizeKey
```

调用

```swift
// 多参数在{}内添加
let attributedString = AttributedString(localized: "^[hello world](size:{width:343.3,height:200.3},priority:'high')",including: \.myScope)
print(attributedString)

// Output
ello world {
    priority = high
    size = Size(width: 343.3, height: 200.3)
    NSLanguage = en
}
```

> 在[WWDC 2021新Formatter API](https://www.fatbobman.com/posts/newFormatter/)一文中，还有在Formatter中使用自定义属性的案例

## 总结 ##

在AttributedString之前，多数开发者将属性字符串主要用于文本的显示样式描述，随着可以在Markdown文本中添加自定义属性，相信很快就会有开发者扩展AttributedString的用途，将其应用到更多的场景中。

希望本文能够对你有所帮助。
