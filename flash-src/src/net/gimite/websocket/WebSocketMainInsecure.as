// Copyright: Hiroshi Ichikawa <http://gimite.net/en/>
// License: New BSD License
// Reference: http://dev.w3.org/html5/websockets/
// Reference: http://tools.ietf.org/html/draft-ietf-hybi-thewebsocketprotocol-07

package net.gimite.websocket {

import flash.system.Security;

public class WebSocketMainInsecure extends WebSocketMain {

  public function WebSocketMainInsecure() {
    Security.allowDomain("*");
    // Also allows HTTP -> HTTPS call. Since we have already allowed arbitrary domains, allowing
    // HTTP -> HTTPS would not be more dangerous.
    Security.allowInsecureDomain("*");
    super();
  }
  
}

}
