//
//  File.swift
//
//
//  Created by Yang Xu on 2021/10/9.
//

import Foundation
import Ink
import Plot
import Sweep

var responser = Modifier(target: .codeBlocks) { html, markdown in
    guard let content = markdown.firstSubstring(between: .prefix("```responser\n"), and: "\n```") else { return html }
    var id: String = "1"
    content.scan(using: [
        Matcher(identifier: "id: ", terminator: "\n", allowMultipleMatches: false) { match, _ in id = String(match) },
    ])

    let start = "<Div id='responser' class = \"responser\" onclick=\"window.location='http://www.fatbobman.com/healthnotes/';\">"

    let end = "</Div>"
    return start + getResponser(id) + end
}

func getResponser(_ id: String) -> String {
    switch id {
    // 健康笔记
    case "1":
        return responserHealthNotes
    default:
        return responserHealthNotes
    }
}

// 健康笔记
let responserHealthNotes: String =
    """
    <div class = "hstack">
    <img src = "https://cdn.fatbobman.com/healthnotesLogoRespnser.png"></img>
    <div class = "text">
    <p><span class = "title">健康笔记</span>是我开发的一个iOS app，主要服务于有长期健康管理需求的人士。健康笔记提供了强大的自定义数据类型功能，可以满足记录生活中绝大多数的健康项目数据的需要。你可以为每个家庭成员创建各自的健康数据记录笔记，或者针对某个特定项目、特定时期创建对应的笔记。</p>
    </div>
    </div>
    <div class="label">推广</div>
    """
