import Foundation
import Plot
import Publish

extension Node where Context == HTML.BodyContext {
    static func spacer() -> Node {
        .group(
            .div(
                .class("spacer")
            ),
            .raw("""
                <script>
                $(function(){
                    var wrapperHeight = $('.wrapper').get(0).offsetHeight + $('footer').get(0).offsetHeight + $('header').get(0).offsetHeight;
                    if (wrapperHeight < window.innerHeight) { 
                         $('.wrapper').height( window.innerHeight - 70 - $('footer').get(0).offsetHeight - $('header').get(0).offsetHeight  );
                      }
                    })
                </script>
                """
            )
        )
    }
}
