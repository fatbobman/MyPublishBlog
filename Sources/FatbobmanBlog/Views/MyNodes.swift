import Foundation
import Plot
import Publish

extension Node where Context == HTML.BodyContext {
    // static func tagslist(context: PublishingContext<Website>) -> Node {

    // }

    static func viewContainer(_ nodes: Node...) -> Node {
        .div(
            .class("viewContainer"),
            .group(nodes)
        )
    }

    // 文章列表Spacer
    static func itemListSpacer() -> Node {
        .group(
            // 窗口变化
            .script(
                .raw(
                    """
                        $(window).resize(function(){
                            setHeight();
                        })
                    """
                )
            ),
            // 设置search-result height
            .script(
                .raw("""
                    var setHeight = function(){
                        var totalHeight = $('.item-list').get(0).offsetHeight + $('footer').get(0).offsetHeight + $('header').get(0).offsetHeight + 50
                        if (totalHeight < window.innerHeight) {
                            $('.wrapper').height( window.innerHeight - 50 - $('footer').get(0).offsetHeight - $('header').get(0).offsetHeight );
                        }
                        else {
                            $('.wrapper').height( $('.item-list').height );
                        }
                     }
                    """
                )
            ),
            .script(
                .raw(
                    """
                    $(document).ready(function(){
                        setHeight();
                    })
                    """
                )
            )
        )
    }

    static func tagDetailSpacer() -> Node {
        .group(
            // 窗口变化
            .script(
                .raw(
                    """
                        $(window).resize(function(){
                            setHeight();
                        })
                    """
                )
            ),
            // 设置search-result height
            .script(
                .raw("""
                    var setHeight = function(){
                        var totalHeight = $('.item-list').get(0).offsetHeight + $('footer').get(0).offsetHeight + $('header').get(0).offsetHeight + 50
                        if (totalHeight < window.innerHeight) {
                            $('.wrapper').height( window.innerHeight - 50 - $('footer').get(0).offsetHeight - $('header').get(0).offsetHeight );
                        }
                        else {
                            $('.wrapper').height( $('.item-list').height );
                        }
                     }
                    """
                )
            ),
            .script(
                .raw(
                    """
                    $(document).ready(function(){
                        setHeight();
                    })
                    """
                )
            )
        )
    }

    static func headerIcons() -> Node {
        .div(
            .class("headerIcons"),
            .a(
                .class("icon headIconWeixin"),
                .script(
                    .raw(
                        """
                        var weixinHeadButton = $('.headIconWeixin');
                        weixinHeadButton.hover(
                        function(){
                            $('.weixinHeadQcode').css('display','block');
                        },
                        function(){
                            $('.weixinHeadQcode').css('display','none');
                        })
                        """
                    )
                ),
                .div(
                    .class("weixinHeadQcode")
                )
            ),
            .a(
                .class("icon headIconTwitter"),
                .href("https://www.twitter.com/fatbobman")
            ),
            .a(
                .class("icon headIconEmail"),
                .href("mailto:xuyang@me.com")
            ),
            .a(
                .class("icon headIconGithub"),
                .href("https://github.com/fatbobman/")
            ),
            .a(
                .class("icon headIconZhihu"),
                .href("https://www.zhihu.com/people/fatbobman3000")
            ),
            .a(
                .class("icon headIconRss"),
                .href("/feed.rss")
            )
        )
    }

    static func shareContainer(title: String, url: String) -> Node {
        .div(
            .class("post-actions"),
            .div(
                .class("actionButton"),
                .div(
                    .class("actionButton twitter"),
                    .onclick("window.open('https://twitter.com/intent/tweet?text=\(title)&url=\(url)&via=fatbobman','target','');")
                )
            ),
            // .div(
            //     .id("actionButtonWeibo"),
            //     .class("actionButton"),
            //     .div(
            //         .class("actionButton weibo"),
            //         .script(
            //             .raw(
            //                 """
            //                 var weiboButton = document.getElementById('actionButtonWeibo');
            //                 weiboButton.onmouseover = function(){
            //                     console.log('over');
            //                 }
            //                 weiboButton.onmouseout = function() {
            //                     console.log('out');
            //                 }
            //                 """
            //             )
            //         )
            //     )
            // ),
            .div(
                .class("actionButton"),
                .div(
                    .class("actionButton weixin"),
                    .script(
                        .raw(
                            """
                            var weixinButton = $('.actionButton .weixin');
                            weixinButton.hover(
                            function(){
                                $('.actionButton .weixinQcode').css('display','block');
                            },
                            function(){
                                $('.actionButton .weixinQcode').css('display','none');
                            })
                            """
                        )
                    ),
                    .div(
                        .class("actionButton weixinQcode")
                    )
                )
            ),
            .div(
                .class("actionButton"),
                .div(
                    .class("actionButton comment"),
                    .onclick("$('html,body').animate({scrollTop: $('#gitalk-container').offset().top }, {duration: 500,easing:'swing'})"
                    )
                )
            ),
            .div(
                .class("actionButton"),
                .div(
                    .class("actionButton donate"),
                    .script(
                        """
                        var donateButton = $('.actionButton .donate');
                        donateButton.hover(
                        function(){
                            $('.actionButton .donateQcode').css('display','block');
                        },
                        function(){
                            $('.actionButton .donateQcode').css('display','none');
                        })
                        """
                    ),
                    .div(
                        .class("actionButton donateQcode")
                    )
                )
            )
        )
    }

    static func twitterIntent(title: String, url: String) -> Node {
        .div(
            .class("post-actions"),
            .a(.img(.class("twitterIntent"), .src("/images/twitter.svg")),
               .href("https://twitter.com/intent/tweet?text=\(title)&url=\(url)&via=fatbobman"),
               .target(.blank),
               .rel(.nofollow),
               .rel(.noopener),
               .rel(.noreferrer))
        )
    }

    static func mobileToc(_ nodes: Node...) -> Node {
        .div(
            .class("mobileSidenav"),
            .div(
                .group(nodes)
            )
        )
    }
}
