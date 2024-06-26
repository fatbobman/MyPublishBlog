//
//  Responser.swift
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
    var id = "1"
    content.scan(using: [
        Matcher(identifier: "id: ", terminator: "\n", allowMultipleMatches: false) { match, _ in id = String(match) },
    ])

    let start = "<Div id = \"responser\" class = \"responser\" ><div class = \"adsContent\">"
    let end = "</div><div class='label'>推荐</div></Div>"
    let ads = healthAds1
    return start + ads + end + adsScript
}

func getResponser(_ id: String) -> String {
    switch id {
    // 健康笔记
    case "1":
        return healthAds1
    default:
        return " Hello world "
    }
}

// let adsScript = """
// <script type="text/javascript">
// $(document).ready(function() {
//    var banners = [];
//    var index = 0;
//    $("#responser").on("click",function(){
//     window.location.href = "https://fatbobman.com/healthnotes/"
// });
//   });
// </script>
// """

let adsScript = """
<script type="text/javascript">
document.querySelectorAll('.responser').forEach(function(div) {
  div.addEventListener('click', function() {
    var url = 'https://apps.apple.com/us/app/health-notes-fresh-start/id1534513553'; // 替换为你要访问的特定 URL
    window.open(url, '_blank');
  });
});
</script>
"""

// MARK: - 广告数据

// <div class = "discount">50% OFF</div>
// 健康笔记
let healthAds1 =
    """
    <style>
    .adsImage {
       content:url("https://cdn.fatbobman.com/healthNotes-ads1.png")
    }
    @media (prefers-color-scheme: dark) {
      .adsImage {
           content:url("https://cdn.fatbobman.com/healthNotes-ads1.png")
      }
    }
    </style>
    <div class = "HStack">
    <img class = "adsImage"></img>
    <div class = "textContainer">
    <div class = "title">健康笔记 - 新生活从记录开始</div>
    <div class = "document"><p>健康笔记是一款智能的数据管理和分析工具，让您完全掌控自己和全家人的健康信息。作为慢性病患者，肘子深知健康管理的重要与难度。创建健康笔记的初心，就是要为您提供一款轻松高效的健康信息记录与分析工具</p>
    </div>
    </div>
    </div>
    """.replacingOccurrences(of: "\n", with: "")

let healthAds2 =
    """
    <style>
    .adsImage {
       content:url("https://cdn.fatbobman.com/healthNotes-ads1.png")
    }
    @media (prefers-color-scheme: dark) {
      .adsImage {
           content:url("https://cdn.fatbobman.com/healthNotes-ads1.png")
      }
    }
    </style>
    <div class = "HStack">
    <img class = "adsImage"></img>
    <div class = "textContainer">
    <div class = "title">Health Notes - Fresh Start</div>
    <div class = "documentEN"><p>Health Notes is a smart tool created by fatbobman, a chronic disease patient, for managing and analyzing health data. It provides an easy and efficient way to record and analyze your family's health information</p>
    </div>
    </div>
    </div>
    """.replacingOccurrences(of: "\n", with: "")

let healthAds =
    """
    <div><img src = "https://cdn.fatbobman.com/healthnotesPromotion3.png"></img>
    </div>
    """.replacingOccurrences(of: "\n", with: "")

let healthURL = "https://fatbobman.com/healthnotes/"

let style =
    """
    <style type="text/css">
    .responser .subtitle {

    }

    .responser .title {
    }

    .responser .discount {
        color: #FF0000;
    }

    .responser .document {
    }

    .responser .content {
    }
    </style>
    """

let healthNotesContent =
    """
    <div class = "hstack">
    <img src = "https://cdn.fatbobman.com/healthnotesLogoRespnser.png"></img>
    <div class = "content">
    <div class = "subtitle">欢迎使用肘子开发的作品</div>
    <div class = "title">健康笔记 - 全家人的健康助手</div>
    <div class = "document">健康笔记提供了强大的自定义数据类型功能，可以满足记录生活中绝大多数的健康项目数据的需要。</div>
    </div>
    </div>
    """
