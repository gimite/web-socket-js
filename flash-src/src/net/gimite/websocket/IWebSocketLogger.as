// Copyright: Hiroshi Ichikawa <http://gimite.net/en/>
// License: New BSD License

package net.gimite.websocket {

public interface IWebSocketLogger {
  function log(message:String):void;
  function error(message:String):void;
}

}
