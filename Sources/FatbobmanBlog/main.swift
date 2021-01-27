import Foundation
import Publish
import Plot
//import SplashPublishPlugin
import HighlightJSPublishPlugin

// This type acts as the configuration for your website.
struct FatbobmanBlog: Website {
    enum SectionID: String, WebsiteSectionID {
        // Add the sections that you want your website to contain here:
        case index
        case posts
        case project
        case tags
        case about
    }

    struct ItemMetadata: WebsiteItemMetadata {
        // Add any site-specific metadata that you want to use here.
    }

    // Update these properties to configure your website:
    var url = URL(string: "http://www.fatbobman.com")!
    var name = "Swift笔记本"
    var description = "徐杨的个人博客"
    var language: Language { .chinese }
    var imagePath: Path? { Path("images") }
}

// This will generate your website using the built-in Foundation theme:
try FatbobmanBlog().publish(
    using: [
        //使用ink modifier的plugins要在addMarkdonwFiles之前先加入.
        //modifier的执行顺序后添加的先执行
        //下面的顺序不能搞错
        .installPlugin(.highlightJS()), //语法高亮
        .installPlugin(.styleCodeBlocks()), //使用```style 添加临时的css style.
        .installPlugin(.imageAttributes()),
        .copyResources(),
        .addMarkdownFiles(),

        .addDefaultSctionTitle(), //修改section 标题
        .installPlugin(.setDateFormatter()), //设置时间显示格式
        .installPlugin(.countTag()), //计算tag的数量

        //tag必须在 addMarkDownFiles 之后,否则alltags没有值
        .installPlugin(.colorfulTags(defaultClass: "tag", variantPrefix: "variant", numberOfVariants: 8)), //给tag多种颜色
        .sortItems(by: \.date, order: .descending), //对所有文章排序
        .generateHTML(withTheme: .fatTheme),
        .generateRSSFeed(
            including: [.posts],
            itemPredicate: nil //{$0.sectionID != .special || $0.metadata.includeInRSSFeed == true}
        ),
        .generateSiteMap(),
        .unwrap(.gitHub("fatbobman/fatbobman.github.io", useSSH: true), PublishingStep.deploy)
    ]
)

extension Plugin{
    static func setDateFormatter() -> Self{
        Plugin(name: "setDateFormatter"){ context in
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            context.dateFormatter = formatter
        }
    }
}



