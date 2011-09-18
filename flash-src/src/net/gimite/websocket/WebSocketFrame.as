// Copyright: Hiroshi Ichikawa <http://gimite.net/en/>
// License: New BSD License

package net.gimite.websocket {

import flash.utils.ByteArray;

public class WebSocketFrame {
  public var fin:Boolean = true;
  public var opcode:int = -1;
  public var payload:ByteArray;
  // Not used when used as a parameter of sendFrame().
  public var length:uint = 0;
}

}
