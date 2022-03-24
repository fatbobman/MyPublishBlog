import Foundation
import HighlightJSPublishPlugin
import Plot
import Publish

// This type acts as the configuration for your website.
struct FatbobmanBlog: Website {
    enum SectionID: String, WebsiteSectionID {
        // Add the sections that you want your website to contain here:
        case index
        case posts
        case healthNotes
        case about
        case tags
    }

    struct ItemMetadata: WebsiteItemMetadata {
        // Add any site-specific metadata that you want to use here.
    }

    // Update these properties to configure your website:
    var url = URL(string: "https://www.fatbobman.com")!
    var name = "肘子的Swift记事本"
    var description =
        "徐杨的个人博客,Core Data,Swift,Swift UI,Combine,健康笔记,iOS APP,Health Note,HealthNotes"
    var language: Language { .chinese }
    var imagePath: Path? { Path("images") }
}

// This will generate your website using the built-in Foundation theme:
try FatbobmanBlog().publish(
    using: [
        // 使用ink modifier的plugins要在addMarkdownFiles之前先加入.
        // 需要注意modifier的添加顺序
        .installPlugin(.highlightJS()), // 语法高亮
        .addModifier(modifier: bilibili, modifierName: "bilibili"), // bilibili视频
        .addModifier(modifier: hrefOpenNewTab, modifierName: "hrefOpenNewTab"),
        .addModifier(modifier: responser, modifierName: "Responser"),
        .copyResources(),
        .setSectionTitle(), // 修改section 标题
        .addMarkdownFiles(),
        .makeDateArchive(),
        .installPlugin(.setDateFormatter()), // 设置时间显示格式
        .installPlugin(.countTag()), // 计算tag的数量,tag必须在 addMarkDownFiles 之后,否则alltags没有值
        .installPlugin(
            .colorfulTags(defaultClass: "tag", variantPrefix: "variant", numberOfVariants: 8)
        ), // 给tag多种颜色
        .sortItems(by: \.date, order: .descending), // 对所有文章排序
        .generateShortRSSFeed(
            including: [.posts],
            itemPredicate: nil
        ),
        .generateHTML(withTheme: .fatTheme),
        //        .installPlugin(.rssSetting(including:[.posts,.project])),
        .makeSearchIndex(includeCode: false),
        .generateSiteMap(),
        .unwrap(.gitHub("fatbobman/fatbobman.github.io", useSSH: true), PublishingStep.deploy),
    ]
)
