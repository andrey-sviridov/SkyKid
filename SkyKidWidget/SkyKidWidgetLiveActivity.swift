//
//  SkyKidWidgetLiveActivity.swift
//  SkyKidWidget
//
//  Created by Northarion on 05.06.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SkyKidWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct SkyKidWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SkyKidWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension SkyKidWidgetAttributes {
    fileprivate static var preview: SkyKidWidgetAttributes {
        SkyKidWidgetAttributes(name: "World")
    }
}

extension SkyKidWidgetAttributes.ContentState {
    fileprivate static var smiley: SkyKidWidgetAttributes.ContentState {
        SkyKidWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: SkyKidWidgetAttributes.ContentState {
         SkyKidWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: SkyKidWidgetAttributes.preview) {
   SkyKidWidgetLiveActivity()
} contentStates: {
    SkyKidWidgetAttributes.ContentState.smiley
    SkyKidWidgetAttributes.ContentState.starEyes
}
