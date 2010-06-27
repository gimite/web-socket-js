#!/bin/sh

# You need Flex 4 SDK:
# http://opensource.adobe.com/wiki/display/flexsdk/Download+Flex+4

mxmlc -static-link-runtime-shared-libraries -output=../WebSocketMain.swf WebSocketMain.as
