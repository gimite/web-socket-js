* How to try

- Download web_socket.rb from:
  http://github.com/gimite/web-socket-ruby/tree/master
- Run sample Web Socket server (echo server) with:
  $ ruby web_socket.rb server ws://localhost:10081
- Put Flash socket policy file to port 843, to allow access to port 10081.
- If you run your Web Socket server on remote host, change host name of ws://localhost:10081 in sample.html.
- Open sample.html in your browser.
- After "onopen" is shown, input something, click [Send] and confirm echo back.


* How to debug

If sample.html doesn't work, use Developer Tools (Chrome/Safari) or Firebug (Firefox) to see console.log output. It would be also useful to install debugger version of Flash Player:
http://www.adobe.com/support/flashplayer/downloads.html


* Supported environment

I confirmed it works on Chrome 3, Firefox 3.5 and IE 8. It may not work in other browsers.
It requires Flash Player 9 or later (probably).


* How to build WebSocketMain.swf

Install Flex SDK.

$ cd flash-src
$ mxmlc -output=../WebSocketMain.swf WebSocketMain.as


* License

New BSD License.
