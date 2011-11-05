// Copyright: Hiroshi Ichikawa <http://gimite.net/en/>
// License: New BSD License

package net.gimite.websocket {

import flash.utils.ByteArray;

public class WebSocketFrame {
  
  public var fin:Boolean = true;
  public var rsv:int = 0;
  public var opcode:int = -1;
  public var payload:ByteArray;
  
  // Fields below are not used when used as a parameter of sendFrame().
  public var length:uint = 0;
  public var mask:Boolean = false;
  
}

}
