//
//  File.swift
//
//
//  Created by Yang Xu on 2021/2/2.
//

import Foundation
import Plot
import Publish

extension Node where Context == HTML.DocumentContext {
    /// Add an HTML `<head>` tag within the current context, based
    /// on inferred information from the current location and `Website`
    /// implementation.
    /// - parameter location: The location to generate a `<head>` tag for.
    /// - parameter site: The website on which the location is located.
    /// - parameter titleSeparator: Any string to use to separate the location's
    ///   title from the name of the website. Default: `" | "`.
    /// - parameter stylesheetPaths: The paths to any stylesheets to add to
    ///   the resulting HTML page. Default: `styles.css`.
    /// - parameter rssFeedPath: The path to any RSS feed to associate with the
    ///   resulting HTML page. Default: `feed.rss`.
    /// - parameter rssFeedTitle: An optional title for the page's RSS feed.
    static func myhead<T: Website>(
        for location: Location, on site: T, titleSeparator: String = " | ",
        stylesheetPaths: [Path] = ["/styles.css"], rssFeedPath: Path? = .defaultForRSSFeed,
        rssFeedTitle: String? = nil,
        healthnotes: Bool = false
    ) -> Node {
        var title = location.title

        if title.isEmpty { title = site.name } else { title.append(titleSeparator + site.name) }

        var description = location.description

        if description.isEmpty { description = site.description }

        return .head(
            .encoding(.utf8),
            .siteName(site.name),
            .url(site.url(for: location)),
            .title(title),
            .description(description),
            .twitterCardType(location.imagePath == nil ? .summary : .summaryLargeImage),
            .meta(.name("twitter:site"), .content("@fatbobman")),
            .meta(.name("twitter:creator"), .content("@fatbobman")),
            .meta(.name("referrer"), .content("no-referrer")),
            .if(healthnotes,
                .meta(.name("apple-itunes-app"), .content("app-id=1534513553"))),
            .forEach(stylesheetPaths) { .stylesheet($0) }, .viewport(.accordingToDevice),
            .unwrap(site.favicon) { .favicon($0) },
            .unwrap(
                rssFeedPath) { path in let title = rssFeedTitle ?? "Subscribe to \(site.name)"
                    return .rssFeedLink(path.absoluteString, title: title)
            },
            .unwrap(
                location.imagePath ?? site.imagePath) { path in let url = site.url(for: path)
                    return .socialImageLink(url)
            },
            .script(.src("//cdn.bootcss.com/jquery/3.2.1/jquery.min.js"))
        )
    }
}
