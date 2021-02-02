//
//  File.swift
//  
//
//  Created by Yang Xu on 2021/2/1.
//

import Foundation
import Publish
import Plot

extension PublishingStep{
    static func makeSearchIndex() -> PublishingStep{
        step(named: "make search index file"){ content in
            let items = content.allItems(sortedBy: \.date)

            let xml = XML(
                .forEach(items.enumerated()){ index,item in
                    .element(named: "entry",nodes: [
                        .element(named: "title", text: item.title),
                        .selfClosedElement(named: "link", attributes: [.init(name: "href", value: "/" + item.path.string)] ),
                        .element(named: "url", text: "/" + item.path.string),
                        .element(named: "content", nodes: [
                            .attribute(named: "type", value: "html"),
                            .raw("<![CDATA[" + item.htmlForSearch + "]]>")
                        ]),
                        .forEach(item.tags){ tag in
                            .element(named:"tag",text:tag.string)
                        }
                    ])
                }
            )
            let result = xml.render()
            do {
                try content.createFile(at: Path("/Output/search.xml")).write(result)
            }
            catch {
                print("Failed to make search index file error:\(error)")
            }
        }
    }
}

extension Item{
    var htmlForSearch:String{
        return body.html.replacingOccurrences(of: "]]>", with: "]>")
    }
}

