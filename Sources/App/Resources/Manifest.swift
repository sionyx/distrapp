//
//  File.swift
//  
//
//  Created by Вадим Балашов on 28.04.2020.
//

import Foundation

extension R {

    static var manifest: String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>items</key>
            <array>
                <dict>
                    <key>assets</key>
                    <array>
                        <dict>
                            <key>kind</key>
                            <string>software-package</string>
                            <key>url</key>
                            <string>https://${DOMAIN}/download/${BRANCH_TAG}/${FILE_NAME}</string>
                        </dict>
                    </array>
                    <key>metadata</key>
                    <dict>
                        <key>bundle-identifier</key>
                        <string>${BUNDLE_IDENTIFIER}</string>
                        <key>bundle-version</key>
                        <string>${APPLICATION_VERSION}</string>
                        <key>kind</key>
                        <string>software</string>
                        <key>title</key>
                        <string>${DISPLAY_NAME}</string>
                    </dict>
                </dict>
            </array>
        </dict>
        </plist>
        """
    }
}
