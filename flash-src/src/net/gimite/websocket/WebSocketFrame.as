// Copyright: Hiroshi Ichikawa <http://gimite.net/en/>
// License: New BSD License

package net.gimite.websocket {

public class WebSocketFrame {
  public var fin:int = -1;
  public var opcode:int = -1;
  public var hlength:uint = 0;
  public var plength:uint = 0;
  public var data:String;
}

}
