---
date: 2020-05-17 12:00
description: 本文主要研究在 SwiftUI 中，采用单一数据源 (Single Source of Truth) 的开发模式，ObservableObject 是否为最佳选择。是否可以在几乎不改变现有设计思路下进行新的尝试，以提高响应效率。最后提供了一个仍采用单一数据源设计思路但完全弃用 ObservableObject 的方式。
tags: SwiftUI,Architecture
title: ObservableObject 研究——想说爱你不容易
---

本文主要研究在 SwiftUI 中，采用单一数据源 (Single Source of Truth) 的开发模式，ObservableObject 是否为最佳选择。是否可以在几乎不改变现有设计思路下进行新的尝试，以提高响应效率。最后提供了一个仍采用单一数据源设计思路但完全弃用 ObservableObject 的方式。

```responser
id:1
```

## 单一数据源 ##

我是在去年阅读王巍写的 [《SwiftUI 与 Combine 编程》](https://objccn.io/products/swift-ui) 才第一次接触到**单一数据源**这一概念的。

* 将 app 当作一个状态机，状态决定用户界面。

* 这些状态都保存在一个 Store 对象中，被称为 State。

* View 不能直接操作 State，而只能通过发送 Action 的方式，间接改变存储在 Store 中的 State。

* Reducer 接受原有的 State 和发送过来的 Action，生成新的 State。

* 用新的 State 替换 Store 中原有的状态，并用新状态来驱动更新界面。

![Redux 架构](https://cdn.fatbobman.com/observableObject-study-reduximage.gif)

在该书中结合作者之前 Redux、RxSwift 等开发经验，提供了一个 SwiftUI 化的范例程序。之后我也继续学习了一些有关的资料，并通过阅读 Github 上不少的开源范例，基本对这一方式有所掌握，并在 [**健康笔记**](https://apps.apple.com/app/id1492861358) 中得以应用。总的来说，当前在 SwiftUI 框架下，大家的实现手段主要的不同都体现在细节上，大的方向、模式、代码构成基本都差不多：

* Store 对象遵守 ObservableObject 协议

* State 保存在 Store 对象中，并使用@Published 进行包装。从而在 State 发生变化时通知 Store

* Store 对象通过@ObservedObject 或 @EnvironmentObject 与 View 建立依赖

* Store 对象在 State 变化后通过 objectWillChange 的 Pbulisher 通知与其已建立依赖关系的 View 进行刷新

* View 发送 Action -> Recudcer(State,Action) -> newState 周而复始

* 由于 SwiftUI 的双向绑定机制，数据流并非完全单向的

* 在部分视图中可以结合 SwiftUI 通过的其他包装属性如@FetchRequest 等将状态局部化

后两项是利用 SwiftUI 的特性，也可以不采用，完全采用单向数据流的方式

基于以上方法，在 SwiftUI 中进行单一数据源开发是非常便利的，在多数情况下执行效率、响应速度都是有基本保证的。不过就像我在上一篇文章 [@State 研究](/posts/swiftUI-state/) 中提到过的，**当随着动态数据量的增大、与 Store 保有依赖关系的 View 数量提高到一定程度后，整个 app 的响应效率便会急剧恶化。**

恶化的原因主要有以下几点：

1. 对于遵循 ObservableObject 对象的依赖注入时机
2. View 的精细化
3. 依赖通知接口唯一性。State（状态集合）中任何的单一元素发生变化都将通知所有与 Store 有依赖的 View 进行重绘。

我就以上几点逐条进行分析。

## 对于遵循 ObservableObject 对象的依赖注入时机 ##

在 [@State 研究](/posts/swiftUI-state/) 中的 **什么时候建立的依赖？**章节中，我们通过了一段代码进行过@State 和@ObservedObject 对于依赖注入时机的推测。结果就是通过使用@ObservedObject 或@EnvironmentObject 进行的依赖注入，编译器没有办法根据当前 View 的具体内容来进行更精确的判断，只要你的 View 中进行了声明，依赖关系变建立了。

```swift
struct MainView: View {
    @ObservedObject var store = AppStore()

    var body: some View {
        print("mainView")
        return Form {
            SubView(date: $store.date)
            Button("修改日期") {
                self.store.date = Date().description
            }
        }
    }
}

struct SubView: View {
    @Binding var date: String
    var body: some View {
        print("subView")
        return Text(date)
    }
}

class AppStore:ObservableObject{
    @Published var date:String = Date().description
}
```

执行后输出如下：

```swift
mainView
subView
mainView
subView
...
```

更详细的分析请参见 [@State 研究](/posts/swiftUI-state/)

**即使你只在 View 中发送 action，并没有显示 State 中的数据或使用其做判断，该 View 也会被强制刷新。甚至，如果你像我一样，忘了移除在 View 中的声明，View 也同样会被更新。**

如果类似的 View 比较多，你的 app 将会出现大量的无效更新。

## View 的精细化 ##

这里所指的 View 是你自己构建的遵循 View 协议的结构体。

在 SwiftUI 下开发，无论是主观还是客观都需要你将 View 的表述精细化，用更多的子 View 来组成你的最终视图，而不是把所有的代码都尽量写在同一个 View 上。

### 主观方面 ###

* 更小的耦合性

* 更强的复用性

### 客观方面 ###

#### ViewBuilder 的设计限制 ####

  FunctionBuilder 作为 Swift5.1 的重要新增特性，成为了 SwiftUI 声明式编程的基础。它为在 Swift 代码中实现 DSL 带来了极大的便利。不过作为一个新生产物，它目前的能力还并不十分的强大。
  目前它仅提供非常有限的逻辑语句
  在编写代码中，为了能够实现更多逻辑和丰富的 UI，我们必须把代码分散到各个 View 中，再最终合成。否则你会经常获得无法使用过多逻辑等等的错误提示。

#### 以 Body 为单位的优化机制 ####

  SwiftUI 为了减少 View 的重绘其实做了大量的工作，它以 View 的 body 为单位进行非常深度的优化（body 是每个 View 的唯一入口；View 中使用 func -> some View 无法享受优化，只有独立的 View 才可以）。SwiftUI 在程序编译时便已将所有的 View 编译成 View 树，它尽可能的只对必须要响应状态变化的 View（@State 完美的支持）进行重绘工作。用户还可以通过自行设置 Equatable 的比对条件进一步优化 View 重绘策略。
  
#### Xcode 的代码实时解析能力限制 ####
  
  如果你在同一个 View 中写入了过多的代码，Xcode 的代码提示功能几乎就会变得不可用了。我估计应该是解析 DSL 本身的工作量非常大，我们在 View body 中写的看起来不多的描述语句，其实后面对应的是非常多的具体代码。Xcode 的代码提示总会超出了它合理的计算时间而导致故障。此时只需把 View 分解成几个 View，即使仍然在同一个文件中，Xcode 的工作也会立刻正常起来。

#### 预览的可靠性限制 ####
  
  新的预览功能本来会极大的提升布局及调试效率，但由于其对复杂代码的支持并不完美，将 View 分割后，通过使用合适的 Preview 控制语句可以高效、无错的对每个子 View 进行独立预览。

从上面几点看，无论从任何角度，更精细化的 View 描述都是十分合适的。

**但由于在单一数据源的情况下，我们将会有更多的 View 和 Store 建立依赖。众多的依赖将使我们无法享受到 SwiftUI 提供的 View 更新优化机制。**

有关 View 优化的问题大家可以参考 [《SwiftUI 编程思想》](https://objccn.io/products/thinking-in-swiftui) 一书中 View 更新机制的介绍，另外 [swiftui-lab](https://swiftui-lab.com/equatableview/) 上也有探讨 Equality 的文章。

## 依赖通知接口唯一性 ##

State（状态集合）中任何的单一元素的变化都将通知所有与 Store 有依赖的 View 进行重绘。

使用@Published 对 State 进行了包装。在 State 的值发生变化后，其会通过 Store（ObservableObject 协议）提供的 ObjectWillChangePublisher 发送通知，所有与其有依赖的 View 进行刷新。

```swift
class AppStore:ObservableObject{
    @Published var state = State()
      ...
}

struct State{
    var userName:String = ""
    var login:Bool = false
    var selection:Int = 0
}
```

对于一个并不复杂的 State 来说，尽管仍有无效动作，但整体效率影响并不大，但是如果你的 app 的 State 里面内容较多，更新较频繁，View 的更新压力会陡然增大。尤其 State 中本来很多数据的变化性是不高的，大量的 View 只需要使用变化性低的数据，但只要 State 发生任何改动，都将被迫重绘。

## 如何改善 ##

在发现了上述的问题后，开始逐步尝试找寻解决的途径。

### 第一步 减少注入依赖 ###

针对只要声明则就会形成依赖的的问题，我第一时间想到的就是减少注入依赖。首先不要在代码中添加不必要的依赖声明；对于那些只需要发送 Action 但并不使用 State 的 View，将 store 定义成全部变量，无需注入直接使用。

```swift
//AppDelegate 中
lazy var store = Store()

//
let store = (UIApplication.shared.delegate as! AppDelegate).store
struct ContentView:View{
  var body:some View{
    Button("直接使用 Action"){
      store.dispatch(.test)
    }
  }
}

//其他需要依赖注入的 View 则正常使用
struct OtherView:View{
  @EnvironmentObject var store:Store
  var boyd:some View{
    Text(store.state.name)
  }
}
```

#### 第二步 将无必要性的状态区域化 ####

听起来这条貌似背离了单一数据源的思想，不过其实在 app 中，有非常多的状态仅对当前 View 或小范围的 View 有效。如果能够合理的进行设计，这些状态信息在自己的小区域中完全可以很好地自我管理，自我维持。没有必要统统汇总到 State 中。

在区域范围内来创建被维持一个小的状态，主要可以使用以下几种手段：

* 善用@State
  在 [@State 研究](/posts/swiftUI-state/) 这篇文章中，我们讨论了 SwiftUI 对于@State 的优化问题。如果设计合理，我们可以将无关大局的信息，保存在局部 View。同时通过对@State 的二度包装，我们同样可以完成所需要的副作用。该 View 的子 View 如果使用了@Binding，也只对局部的 View 树产生影响。

  另外也可以将常用的 View 修饰通过 ViewModifier 进行包装。ViewModifier 可以维持自己的@State，可以自行管理状态。

* 创建自己的@EnviromentKey 或 PreferenceKey，仅注入需要的 View 树分支

  同 EnviromentObject 类似，注入 EnviromentKey 的依赖也是显性的

```swift
  @Environment(\.myKey) var currentPage
```

  我们可以通过以下方式，更改该 EnvironmentKey 的值，但作用范围仅针对当前 View 下面的子 View 分支

```swift
  Button("修改值"){
    self.currentPage = 3
  }
  SubView()
      .environment(\.myKey, currentPage)
```

  EnvironmentObject 也是可以在任意某个分支注入依赖的，不过由于其是引用类型，通常任何分支的改动，都仍然会对整个 View 树其他的使用者造成影响。

  同理，我们也可以使用 PreferenceKey，只将数据注入到当前 View 之上的层级。

  值类型无论如何都要比引用类型都更可控些。

* 在当前 View 使用 SwiftUI 提供的其他包装属性

  我现在最常使用的 SwiftUI 的其他包装属性就属@FetchRequest 了。除了必要的数据放置于 State 中，我对于 CoreDate 的大多数据需求都通过该属性包装器来完成。@FetchRequest 目前有不足之处，比如无法进行更精细的批量指定、明确惰性状态、获取限制等，不过相对于它带来的便利性，我还是完全可以接受的。FetchRequest 完全可以实现同其他 CoreData NSFetchRequest 一样的程序化 Request 设定，结合上面的方式同样可以将 Request 生成器放在 Store 中而不影响当前 View。

```swift
  struct SideView: View {
      @Environment(\.managedObjectContext)
      var context
  
      @State var search: Search?
  
      var body: some View {
          VStack(alignment: .leading) {
              SearchView(
                  onSearch: self.onSearch
              )
              InsideListView(fetchRequest: makeFetchRequest())  //根据上面的 search 来生成不同谓词对应的 fetchrequest.
          }
      }
  
      private func makeFetchRequest() -> FetchRequest<Book> {
          let predicate: NSPredicate?
          if let search = search {
              let textPredicate = NSPredicate(format: "string CONTAINS[cd] %@", search.text)
              let appPredicate = NSPredicate(format: "appName == %@", search.app)
              let typePredicate = NSPredicate(format: "type == %@", search.type)
  
              var predicates: [NSPredicate] = []
              if search.text.count >= 3 {
                  predicates.append(textPredicate)
              }
  
              if search.app != Constants.all {
                  predicates.append(appPredicate)
              }
  
              if search.type != Constants.all {
                  predicates.append(typePredicate)
              }
  
              predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
          } else {
              predicate = nil
          }
  
          return FetchRequest<Book>(
              entity: Book.entity(),
              sortDescriptors: [
                  NSSortDescriptor(keyPath: \Book.date, ascending: false)
              ],
              predicate: predicate
          )
      }
  
      private func onSearch(_ search: Search) {
          if search.text.count < 3 && search.type != Constants.all && search.app != Constants.all {
              self.search = nil
          } else {
              self.search = search
          }
      }
  }
  
  private struct InsideListView: View {
      @Environment(\.managedObjectContext)
      var context
  
      var fetchRequest: FetchRequest<Book>    //只声明，内容需要由调用者来设定
  
      var body: some View {
          List(items) {
              ForEach
         }
      }
  
      private var items: FetchedResults<Book> {
          fetchRequest.wrappedValue
      }
  }
```

  我相信，下一步 SwiftUI 应该还会提供更多的直接将状态控制在局部的包装器。

#### 第三步 和 ObservedObject 说再见 ####

只要我们的 View 还需要依赖单一数据源的 State，前面我们做努力就都付之东流了。但坚持单一数据源的设计思路又是十分明确的。由于任何状态的变化 ObservedObject 只有通过 ObjectWillChangePublisher 这一个途径来通知与其依赖的 View，因此我们如果要解决这个问题，只能放弃使用 ObservedObject，通过自己创建视图和 State 中每个独立元素的依赖关系，完成我们的优化目的。

Combine 当然是首选。我希望达到的效果如下：

* State 仍然以目前的形式保存在 Store 中，整个程序的结构基本和使用 ObservedObject 一样
* State 中每个元素可以自己通知与其依赖的 View 而不通过@Published
* 每个 View 可以根据自己的需要同 State 中的元素建立依赖关系，State 中其他无关的变化不会导致其被强制刷新
* State 中的数据仍然支持 Binding 等操作，而且能够支持各种形式的结构设定

基于以上几点，我最终采用了如下的解决方案：

1、Store 不变，只是去掉了 ObservedObject

```swift
class Store{
  var state = AppState()
  ...
}
```

2、State 结构如下

```swift
struct AppState{
  var name = CurrentValueSubject<String,Never>("肘子")
  var age = CurrentValueSubject<Int,Never>(100)
}
```

通过使用 CurrentValueSubject 来创建指定类型的 Publisher。

3、通过如下方式注入

```swift
//当前 View 只需要显示 name
struct ContentView:View{
  @State var name:String = ""
  var body:some View{
    Form{
      Text(name)
    }
    .onReceive(store.state.name, perform: { name in
                self.name = name
            })
  }
}
```

我们需要显式的在每个 View 中把需要依赖的元素单独通过。onReceive 获取并保存到本地。

4、修改 State 中的值

```swift
//基于 View-> Action 来修改 State 的机制
extension Store{
  //例程并非遵循 action，不过也是调用 Store，意会即可
  fune test{
     state.name.value = "大肘子"
  }
}

//在上面的 ContentView 中添加
Button("修改名字"){
  store.test()
}
```

5、支持 Binding

```swift
extension CurrentValueSubject{
    var binding:Binding<Output>{
        Binding<Output>(get: {self.value}, set: {self.value = $0})
    }
}
//使用 binding

TextField("姓名",text:store.state.name.binding)

```

6、对结构体支持 Binding

```swift
struct Student{
    var name = "fat"
    var age = 18
}

struct AppState{
      var student = CurrentValueSubject<Student,Never>(Student())
}

extension CurrentValueSubject{
    func binding<Value>(for keyPath:WritableKeyPath<Output,Value>)->Binding<Value>{
               Binding<Value>(get: {self.value[keyPath:keyPath]}, 
                              set: { self.value[keyPath:keyPath] = $0})
    }
}

//使用 Binding
TextField("studentName:",text: store.state.student.binding(for: \.name))
```

7、对于更复杂的 State 元素设计的 Binding 支持。如果你却有必要在 State 中创建以上 Binding 方式无法支持的格式可以通过使用我另一篇文章中 [@State 研究](/posts/swiftUI-state/) 最后创建的增强型@MyState 来完成特殊的需要，你对本地的 studentAge 做的任何改动都将自动的反馈到 State 中

```swift
struct ContentView:View{
  @MyState<String>(wrappedValue: String(store.state.student.value.age), toAction: {
        store.state.student.value.age = Int($0) ?? 0
    }) var studentAge
  var body:some View{
     TextField("student age:",text: $studentAge)   
  }
}
```

至此我们便达成了之前设定的全部目标。

* 只对原有的程序结构做微小的调整

* State 中每个元素都会在自改动时独立的发出通知

* 每个 View 可以只与自己有关的 State 中的元素创建依赖

* 对 Binding 的完美支持

#### 追加：减少代码量 ####

在实际的使用中，上述解决方案会导致每个 View 的代码量有了一定的增长。尤其是当你忘了写。onReceive 时，程序并不会报错，但同时数据不会实时响应，反倒增加排查错误的难度。通过使用属性包装器，我们可以将 Publisher 订阅和变量声明合二为一，进一步的优化上述的解决方案。

```swift
@propertyWrapper
struct ObservedPublisher<P:Publisher>:DynamicProperty where P.Failure == Never{
    private let publisher:P
    @State var cancellable:AnyCancellable? = nil
    
    @State public private(set) var wrappedValue:P.Output
    private var updateWrappedValue = MutableHeapWrapper<(P.Output)->Void>({ _ in })
    
    init(publisher:P,initial:P.Output) {
        self.publisher = publisher
        self._wrappedValue = .init(wrappedValue: initial)
        
        let updateWrappedValue = self.updateWrappedValue
        self._cancellable = .init(initialValue:  publisher
            .delay(for: .nanoseconds(1), scheduler: RunLoop.main)
            .sink(receiveValue: {
                updateWrappedValue.value($0)
            }))
    }
    
    public mutating func update() {
        let _wrappedValue = self._wrappedValue
        updateWrappedValue.value = {
            _wrappedValue.wrappedValue = $0}
    }
    
}

public final class MutableHeapWrapper<T> {
    public var value: T
    
    @inlinable
    public init(_ value: T) {
        self.value = value
    }
}
```

上面的代码来自于开源项目 SwiftUIX，我对其进行了很小修改使其能够适配 CurrentValueSubject

使用方法

```swift
@ObservedPublisher(publisher: store.state.title, initial: "") var title
```

至此，我们进一步的减少了代码量，并且基本消除了由于漏写。onReceive 而可能出现的问题。

上述代码我已经放到了 [Github](https://github.com/fatbobman/MySingleSoureOfTruthDemo)

## 总结 ##

之所以进行这方面的探讨是由于我的 app 出现了响应的粘滞（和我心目中 iOS 平台上该有的丝滑感有落差）。在研究学习的过程中也让我对 SwiftUI 的有了进一步的认识。无论我提出的思路是否正确，至少整个过程让我获益匪浅。

在我做这方面学习的过程中，恰好也发现了另外一位朋友提出了类似的观点，并提出了他的解决方案。由于他之前有 RxSwift 上开发大型项目的经验，他的解决方案使用了快照（SnapShot）的概念。注入方式采用 EnvironmetKey，对于 State 元素的无效修改（比如说和原值相同）做了比较好的过滤。可以到 [他的博客](https://nalexn.github.io/swiftui-observableobject/) 查看该文。

最后希望 Apple 能够在将来提供更原生的方式解决以上问题。

