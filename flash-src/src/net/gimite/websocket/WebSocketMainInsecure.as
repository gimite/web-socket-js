// Copyright: Hiroshi Ichikawa <http://gimite.net/en/>
// License: New BSD License

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
