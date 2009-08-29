* How to try

- Download web_socket.rb from:
  http://github.com/gimite/web-socket-ruby/tree/master
- Run sample Web Socket server (echo server) with:
  $ ruby web-socket-ruby/lib/web_socket.rb server ws://localhost:10081
- If your server already provides socket policy file at port 843, modify the file to allow access to port 10081. Otherwise you can skip this step. See below for details.
- If you run your Web Socket server on remote host, change host name of ws://localhost:10081 in sample.html.
- Open sample.html in your browser.
- After "onopen" is shown, input something, click [Send] and confirm echo back.


* How to debug

If sample.html doesn't work, use Developer Tools (Chrome/Safari) or Firebug (Firefox) to see console.log output. It would be also useful to install debugger version of Flash Player from:
http://www.adobe.com/support/flashplayer/downloads.html


* Supported environment

I confirmed it works on Chrome 3, Firefox 3.5 and IE 8. It may not work in other browsers.
It requires Flash Player 9 or later (probably).


* Flash socket policy file

This implementation uses Flash's socket, which means that your server must provide Flash socket policy file to declare the server accepts connections from Flash.

If you use web-socket-ruby available at
http://github.com/gimite/web-socket-ruby/tree/master
, you don't need anything special, because web-socket-ruby handles Flash socket policy file request. But if you already provide socket policy file at port 843, you need to modify the file to allow access to Web Socket port, because it precedes what web-socket-ruby provides.

If you use other Web Socket server implementation, you need to provide socket policy file yourself. See
http://www.lightsphere.com/dev/articles/flash_socket_policy.html
for details and sample script to run socket policy file server.

Actually, it's still better to provide socket policy file at port 843 even if you use web-socket-ruby. Flash always try to connect to port 843 first, so providing the file at port 843 makes startup faster.


* How to build WebSocketMain.swf

Install Flex SDK.

$ cd flash-src
$ mxmlc -output=../WebSocketMain.swf WebSocketMain.as


* License

New BSD License.
