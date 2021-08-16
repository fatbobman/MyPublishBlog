import Foundation
import Plot
import Publish

extension Node where Context == HTML.BodyContext {
    // static func spacer() -> Node {
    //     .group(
    //         .div(
    //             .class("spacer")
    //         ),
    //         .raw("""
    //             <script>
    //             $(function(){
    //                 var wrapperHeight = $('.wrapper').get(0).offsetHeight + $('footer').get(0).offsetHeight + $('header').get(0).offsetHeight;
    //                 if (wrapperHeight < window.innerHeight) {
    //                      $('.wrapper').height( window.innerHeight - 70 - $('footer').get(0).offsetHeight - $('header').get(0).offsetHeight  );
    //                   }
    //                 })
    //             </script>
    //             """
    //         )
    //     )
    // }

    static func viewContainer(_ nodes: Node...) -> Node {
        .div(
            .class("viewContainer"),
            .group(nodes)
        )
    }

    // 头部的社交链接
    static func headIcon() -> Node {
        .text("icon")
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
}
