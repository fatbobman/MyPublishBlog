---
date: 2021-09-22 15:00
description: 本文将讲解如何通过NSCoreDataSpotlightDelegate（WWDC 2021版本）实现将应用程序中的Core Data数据添加到Spotlight索引，方便用户查找并提高App的曝光率。
tags: Core Data,SwiftUI,Spotlight
title:  在Spotlight中展示应用中的Core Data数据
image: images/spotlight.png
---

本文将讲解如何通过NSCoreDataSpotlightDelegate（WWDC 2021版本）实现将应用程序中的Core Data数据添加到Spotlight索引，方便用户查找并提高App的曝光率。

## 基础 ##

### Spotlight ###

自2009年登陆iOS以来，经过10多年的发展，Spotlight（聚焦）已经从苹果系统的官方应用搜索变成了一个包罗万象的功能入口，用户对Spotligh的使用率及依赖程度也在不断地提升。

在Spotlight中展示应用程序中的数据可以显著地提高应用的曝光率。

### Core Spotlight ###

从iOS 9开始，苹果推出了Core Spotlight框架，让开发者可以将自己应用的内容添加到Spotlight的索引中，方便用户统一查找。

为应用中的项目建立Spotlight索引，需要以下步骤：

* 创建一个CSSearchableItemAttributeSet（属性集）对象，为你要索引的项目设置适合的元数据（属性）。
* 创建一个CSSearchableItem（可搜索项）对象来表示该项目。每个CSSearchableItem对象均设有唯一标识符，方便之后引用（更新、删除、重建）
* 如果有需要，可以为项目指定一个域标识符，这样就可以将多个项目组织在一起，便于统一管理
* 将上面创建的属性集（CSSearchableItemAttributeSet）关联到可搜索项（CSSearchableItem）中
* 将可搜索项添加到系统的Spotlight索引中

开发者还需要在应用中的项目发生修改或删除时及时更新Spotlight索引，让使用者始终获得有效的搜索结果。

### NSUserActivity ###

NSUserActivity对象提供了一种轻量级的方式来描述你的应用程序状态，并将其用于以后。创建这个对象来捕获关于用户正在做什么的信息，如查看应用程序内容、编辑文档、查看网页或观看视频等。

当使用者从Spotlight中搜索到你的应用程序内容数据（可搜索项）并点击后，系统将启动应用程序，并向其传递一个同可搜索项对应的NSUserActivity对象（activityType为CSSearchableItemActionType），应用程序可以通过该对象中的信息，将自己恢复到一个适当的状态。

比如，用户在Spotlight中通过关键字查询邮件，点击搜索结果后，应用将直接定位到该邮件并显示其详细信息。

### 流程 ###

结合上面对于Core Spotlight和NSUserActivity的介绍，我们用代码段简单地梳理一下流程：

#### 创建可搜索项 ####

```swift
import CoreSpotlight

let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
attributeSet.displayName = "星球大战"
attributeSet.contentDescription = "在很久以前，一个遥远的银河系，肩负正义使命的绝地武士与帝国邪恶黑暗势力作战的故事。"

let searchableItem = CSSearchableItem(uniqueIdentifier: "starWar", domainIdentifier: "com.fatbobman.Movies.Sci-fi", attributeSet: attributeSet)
```

#### 添加至Spotlight索引 ####

```swift
        CSSearchableIndex.default().indexSearchableItems([searchableItem]){ error in
            if let error = error {
                print(error.localizedDescription)
            }
        }
```

![image-20210922084725675](https://cdn.fatbobman.com/image-20210922084725675-2271647.png)

#### 应用程序从Spotlight接收NSUserActivity ####

SwiftUI life cycle

```swift
        .onContinueUserActivity(CSSearchableItemActionType){ userActivity in
            if let userinfo = userActivity.userInfo as? [String:Any] {
                let identifier = userinfo["kCSSearchableItemActivityIdentifier"] as? String ?? ""
                let queryString = userinfo["kCSSearchQueryString"] as? String ?? ""
                print(identifier,queryString)
            }
        }

// Output : starWar 星球大战
```

UIKit life cycle

```swift
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if userActivity.activityType == CSSearchableItemActionType {
            if let userinfo = userActivity.userInfo as? [String:Any] {
                let identifier = userinfo["kCSSearchableItemActivityIdentifier"] as? String ?? ""
                let queryString = userinfo["kCSSearchQueryString"] as? String ?? ""
                print(identifier,queryString)
            }
        }
    }
```

#### 更新Spotlight索引 ####

方式同新增索引完全一样，必须保证`uniqueIdentifier`一致。

```swift
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.displayName = "星球大战(修改版)"
        attributeSet.contentDescription = "在很久以前，一个遥远的银河系，肩负正义使命的绝地武士与帝国邪恶黑暗势力作战的故事。"
        attributeSet.artist = "乔治·卢卡斯"

        let searchableItem = CSSearchableItem(uniqueIdentifier: "starWar", domainIdentifier: "com.fatbobman.Movies.Sci-fi", attributeSet: attributeSet)

        CSSearchableIndex.default().indexSearchableItems([searchableItem]){ error in
            if let error = error {
                print(error.localizedDescription)
            }
        }
```

![image-20210922091534038](https://cdn.fatbobman.com/image-20210922091534038.png)

#### 删除Spotlight索引 ####

* 删除指定`uniqueIdentifier`的项目

```swift
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["starWar"]){ error in
            if let error = error {
                print(error.localizedDescription)
            }
        }
```

* 删除指定域标识符的项目

```swift
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.fatbobman.Movies.Sci-fi"]){_ in }
```

删除域标识符的操作是递归的。上面的代码只会删除所有`Sci-fi`组别，而下面的代码将删除应用程序中全部的电影数据

```swift
CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.fatbobman.Movies"]){_ in }
```

* 删除应用程序中的全部索引数据

```swift
        CSSearchableIndex.default().deleteAllSearchableItems{ error in
            if let error = error {
                print(error.localizedDescription)
            }
        }
```

## NSCoreDataCoreSpotlightDelegate实现 ##

NSCoreDataCoreSpotlightDelegate提供了一组支持Core Data同Core Spotlight集成的方法，极大地简化了开发者在Spotlight中创建并维护应用程序中Core Data数据的工作难度。

在WWDC 2021中，NSCoreDataCoreSpotlightDelegate得到进一步升级，通过持久化历史跟踪，开发者**将无需手动维护数据的更新、删除，Core Data数据的任何变化都将及时地反应在Spotlight中**。

### Data Model Editor ###

要在Spotlight中索引应用中的Core Data数据，首先需要在数据模型编辑器中对需要索引的实体（Entity）进行标记。

* 只有标记过的实体才能被索引
* 只有被标记过的实体属性发生变化，才会触发索引

![image-20210922101458785](https://cdn.fatbobman.com/image-20210922101458785-2276899.png)

比如说，你的应用中创建了若干的Entity，不过只想对其中的`Movie`进行索引，且只有当`Movie`的`title`和`description`发生变化时才会更新索引。那么只需要开启`Movie`实体中`title`和`dscription`的`Index in Spotlight`即可。

> Xcode 13中废弃了Store in External Record File并且删除了在Data Model Editor中设置DisplayName。

### NSCoreDataCoreSpotlightDelegate ###

当被标记的实体记录数据更新时（创建、修改），Core Data将调用NSCoreDataCoreSpotlightDelegate中的`attributeSet`方法，尝试获得对应的可搜索项，并更新索引。

```swift
public class DemoSpotlightDelegate: NSCoreDataCoreSpotlightDelegate {
    public override func domainIdentifier() -> String {
        return "com.fatbobman.CoreSpotlightDemo"
    }

    public override func attributeSet(for object: NSManagedObject) -> CSSearchableItemAttributeSet? {
        if let note = object as? Note {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.identifier = "note." + note.viewModel.id.uuidString
            attributeSet.displayName = note.viewModel.name
            return attributeSet
        } else if let item = object as? Item {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.identifier = "item." + item.viewModel.id.uuidString
            attributeSet.displayName = item.viewModel.name
            attributeSet.contentDescription = item.viewModel.descriptioinContent
            return attributeSet
        }
        return nil
    }
}
```

* 如果你的应用程序中需要索引多个Entity，在`attributeSet`中需首先判断托管对象的具体类型，然后为其创建对应的可搜索项数据。
* 对于特定的数据，即使被标记成可索引，也可以通过在attributeSet中返回nil将其排除在索引之外
* identifier中最好设置成可以同你的记录对应的标识（identifier是元数据，并非CSSearchableItem的`uniqueIdentifier`），方便你在之后的代码中直接利用它。
* 如不特别指定域标识符，默认系统会使用Core Data持久存储的标识符
* 应用中的数据记录被删除后，Core Data将自动从Spotlight中删除其对应的可搜索项。

> CSSearchableItemAttributeSet具有众多的可用元数据。比如，你可以添加缩略图（`thumbnailData`），或者让用户可以直接拨打记录中的电话号码（分别设置`phoneNUmbers`和`supportsPhoneCall`）。更多信息，请看[官方文档](https://developer.apple.com/documentation/corespotlight/cssearchableitemattributeset)

### CoreDataStack ###

在Core Data中启用NSCoreDataCoreSpotlightDelegate有两个先决条件：

* 持久化存储的类型为Sqlite
* 必须启用持久化历史跟踪（Persistent History Tracking）

因此在Core Data Stack中需要使用类似如下的代码：

```swift
class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer
    let spotlightDelegate:NSCoreDataCoreSpotlightDelegate

    init() {
        container = NSPersistentContainer(name: "CoreSpotlightDelegateDemo")
        guard let description = container.persistentStoreDescriptions.first else {
                    fatalError("###\(#function): Failed to retrieve a persistent store description.")
        }

        // 启用持久化历史跟踪
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })

        // 创建索引委托
        self.spotlightDelegate = NSCoreDataCoreSpotlightDelegate(forStoreWith: description, coordinator: container.persistentStoreCoordinator)

        // 启动自动索引
        spotlightDelegate.startSpotlightIndexing()
    }
}
```

对于已经上线的应用程序，在添加了NSCoreDataCoreSpotlightDelegate功能后， 首次启动时，Core Data会自动将满足条件（被标记）的数据添加到Spotlight索引中。

> 上述代码中，只开启了持久化历史跟踪，并没有对失效数据进行定期清理，长期运行下去会导致数据膨胀，影响执行效率。如想了解更多有关持久化历史跟踪信息，请阅读[在CoreData中使用持久化历史跟踪](https://www.fatbobman.com/posts/persistentHistoryTracking/)。

### 停止、删除索引 ###

如果想重建索引，应该首先停止索引，然后再删除索引。

```swift
       stack.spotlightDelegate.stopSpotlightIndexing()
       stack.spotlightDelegate.deleteSpotlightIndex{ error in
           if let error = error {
                  print(error)
           } 
       }
```

> 另外，也可以使用上面介绍的方法，直接使用CSSearchableIndex来更精细的删除索引内容。

### onContinueUserActivity ###

NSCoreDataCoreSpotlight在创建可搜索项（CSSearchableItem）时会使用托管对象的uri数据作为`uniqueIdentifier`，因此，当用户点击Spotlight中的搜索结果时，我们可以从传递给应用程序的NSUserActivity的userinfo中获取到这个uri。

由于传递给应用程序的NSUserActivity中仅提供有限的信息（`contentAttributeSet`为空），因此，我们只能依靠这个uri来确定对应的托管对象。

SwiftUI提供了一种便捷的方法`onConinueUserActivity`来处理系统传递的NSUserActivity。

```swift
import SwiftUI
import CoreSpotlight
@main
struct CoreSpotlightDelegateDemoApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onContinueUserActivity(CSSearchableItemActionType, perform: { na in
                    if let userinfo = na.userInfo as? [String:Any] {
                        if let identifier = userinfo["kCSSearchableItemActivityIdentifier"] as? String {
                            let uri = URL(string:identifier)!
                            let container = persistenceController.container
                            if let objectID = container.persistentStoreCoordinator.managedObjectID(forURIRepresentation: uri) {
                            if let note = container.viewContext.object(with: objectID) as? Note {
                                // 切换到note对应的状态
                            } else if let item = container.viewContext.object(with: objectID) as? Item {
                               // 切换到item对应的状态
                            }
                            }
                        }
                    }
                })
        }
    }
}
```

* 通过userinfo中的`kCSSearchableItemActivityIdentifier`键获取到`uniqueIdentifier`（Core Data数据的uri）
* 将uri转换成NSManagedObjectID
* 通过objectID获取到托管对象
* 根据托管对象，设置应用程序到对应的状态。

> 我个人不太喜欢这种将处理NSUserActivity的逻辑嵌入视图代码的做法，如果想在UIWindowSceneDelegate中处理NSUserActivity，请参阅[Core Data with CloudKit (六) —— 创建与多个iCloud用户共享数据的应用](https://www.fatbobman.com/posts/coreDataWithCloudKit-6/)中关于UIWindowSceneDelegate的用法。

### CSSearchQuery ###

CoreSpotlight中还提供了一种在应用程序中查询Spotlight的方案。通过创建CSSearchQuery，开发者可以在Spotlight中搜索当前应用已被索引的数据。

```swift
    func getSearchResult(_ keyword: String) {
        let escapedString = keyword.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let queryString = "(displayName == \"*" + escapedString + "*\"cd)"
        let searchQuery = CSSearchQuery(queryString: queryString, attributes: ["displayName", "contentDescription"])
        var spotlightFoundItems = [CSSearchableItem]()
        searchQuery.foundItemsHandler = { items in
            spotlightFoundItems.append(contentsOf: items)
        }

        searchQuery.completionHandler = { error in
            if let error = error {
                print(error.localizedDescription)
            }
            spotlightFoundItems.forEach { item in
                //  do something
            }
        }

        searchQuery.start()
    }
```

* 首先需要对搜索关键字进行安全处理，对`\`进行转义
* `queryString`的查询形式同NSPredicate很类似，比如上面代码中就是查询所有`displayName`中含有keyword的数据（忽视大小写、音标字符），详细信息请查阅[官方文档](https://developer.apple.com/documentation/corespotlight/cssearchquery)
* attributes中设置了返回的可搜索项（CSSearchableItem）中需要的属性（例如可搜索项中有十个元数据内容，只需返回设置中的两个）
* 当获得搜索结果时将调用`foundItemsHandler`闭包中的代码
* 配置好后用`searchQuery.start()`启动查询

> 对于使用Core Data的应用来说，直接通过Core Data查询或许是更好的方式。

## 注意事项 ##

### 失效日期 ###

默认情况下，CSSearchableItem的失效日期（`expirationDate`）为30天。也就是说，如果一个数据被添加到索引中，如果在30天内没有发生任何的变动（更新索引），那么30天后，我们将无法从Spotlight中搜索到这个数据。

解决的方案有两种：

* 定期重建Core Data数据的Spotlight索引

  方法为停止索引——删除索引——重新启动索引

* 为CSSearchableItemAttributeSet添加失效日期元数据

  正常情况下，我们可以为NSUserActivity设置失效日期，并将CSSearchableItemAttributeSet同其进行关联。但NSCoreDataCoreSpotlightDelegate中只能设置CSSearchableItemAttributeSet。

  官方并没有公开CSSearchableItemAttributeSet的失效日期属性，因此无法保证下面的方法一直有效

```swift
        if let note = object as? Note {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.identifier = "note." + note.viewModel.id.uuidString
            attributeSet.displayName = note.viewModel.name
            attributeSet.setValue(Date.distantFuture, forKey: "expirationDate")
            return attributeSet
        }
```

> setValue会自动将CSSearchableItemAttributeSet中的`_kMDItemExpirationDate`设置成`4001-01-01`，Spotlight会将`_kMDItemExpirationDate`的时间设置为NSUserActivity的`expirationDate`

### 模糊查询 ###

Spotlight支持模糊查询。比如输入`xingqiu`便可能在搜索结果中显示上图的“星球大战”。不过苹果并没有在CSSearchQuery中开放模糊查询的能力。如果希望用户在应用内获得同Spotlight类似的体验，还是通过创建自己的代码在Core Data中实现比较好。

另外，Spotlight的模糊查询只对`displayName`有效，对`contentDescription`没有效果

### 字数限制 ###

CSSearchableItemAttributeSet中的元数据是用来描述记录的，并不适合保存大量的数据。 `contentDescription`目前支持的最大字符数为300。如果你的内容较多，最好截取真正对用户有用的信息。

### 可搜索项数量 ###

应用的可搜索项需控制在几千条之内。超出这个量级，将严重影响查询性能

## 总结 ##

希望有更多的应用认识到Spotlight的重要性，尽早登陆这个设备应用的重要入口。

希望本文对你有所帮助。
