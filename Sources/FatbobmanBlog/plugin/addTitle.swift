//
//  File.swift
//  
//
//  Created by Yang Xu on 2021/1/22.
//

import Foundation
import Publish


extension PublishingStep where Site == FatbobmanBlog {
    static func addDefaultSctionTitle() -> Self {
        .step(named: "changeName" ){ content in
            content.mutateAllSections { section in
                switch section.id {
                case .index:
                    section.title = "首页"
                case .posts:
                    section.title = "文章"
                case .project:
                    section.title = "我的APP"
                case .about:
                    section.title = "关于"
                case .tags:
                    section.title = "标签"
                }
            }
        }
    }
}



extension PublishingContext{
    mutating func changeTitle(){

    }
}

//计算每个tag的数量
extension Plugin{
    static func countTag() -> Self{
        return Plugin(name: "countTag"){ content in
            CountTag.count(content: content)
        }
    }
}

struct CountTag{
    static var count:[Tag:Int] = [:]
    static func count<T:Website>(content:PublishingContext<T>){
        for tag in content.allTags{
            count[tag] =  content.items(taggedWith: tag).count
        }
    }
}

extension Tag{
    public var count:Int{
        CountTag.count[self] ?? 0
    }
}

extension PublishingContext{
    var itemCount:Int{
        allItems(sortedBy: \.date,order: .descending).count
    }
}


