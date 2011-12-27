- 2011-12-27
    - web-socket-js now speaks WebSocket defined in RFC 6455, which is
      equivalent to hybi-13 to hybi-17. It no longer supports old draft
      protocols.

- 2011-12-17
    - web-socket-js now uses MozWebSocket when available. i.e. When you load
      web_socket.js, WebSocket is defined as alias of MozWebSocket when
      available.

- 2011-09-18
    - web-socket-js now speaks WebSocket version hybi-10. Old versions spoke
      hixie-76. If you really need web-socket-js which speaks hixie-76, you can
      get it from
      [hixie-76 branch](https://github.com/gimite/web-socket-js/tree/hixie-76),
      but the branch is no longer maintained. Implementation of hybi-10 is
      mostly done by Joel Martin (kanaka).
