// Copyright: Hiroshi Ichikawa <http://gimite.net/en/>
// License: New BSD License
// Reference: http://dev.w3.org/html5/websockets/
// Reference: http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol-76

package {

import bridge.JSBridge;

import flash.display.Sprite;
import flash.system.Security;
import flash.utils.setTimeout;

import mx.utils.URLUtil;

public class WebSocketMain extends Sprite {
  
  private var callerUrl:String;
  private var debug:Boolean = false;
  private var manualPolicyFileLoaded:Boolean = false;
  private var jsBridge:JSBridge;
  private var webSockets:Array;
  private var eventQueue:Array;
  
  public function WebSocketMain() {
    this.jsBridge = new JSBridge(this);
    webSockets = [];
    eventQueue = [];
    jsBridge.flashInitialized();
  }
  
  /*************
   * Initialization / Utility methods
   */
  
  public function setCallerUrl(url:String):void {
    callerUrl = url;
  }
  
  public function setDebug(val:Boolean):void {
    debug = val;
  }
  
  public function getOrigin():String {
    return (URLUtil.getProtocol(this.callerUrl) + "://" +
      URLUtil.getServerNameWithPort(this.callerUrl)).toLowerCase();
  }
  
  public function getCallerHost():String {
    return URLUtil.getServerName(this.callerUrl);
  }
  
  private function loadDefaultPolicyFile(wsUrl:String):void {
    var policyUrl:String = "xmlsocket://" + URLUtil.getServerName(wsUrl) + ":843";
    log("policy file: " + policyUrl);
    Security.loadPolicyFile(policyUrl);
  }
  
  public function loadManualPolicyFile(policyUrl:String):void {
    log("policy file: " + policyUrl);
    Security.loadPolicyFile(policyUrl);
    manualPolicyFileLoaded = true;
  }
  
  public function log(message:String):void {
    if (debug) {
      jsBridge.log(message);
    }
  }
  
  public function error(message:String):void {
    jsBridge.error(message);
  }
  
  public function fatal(message:String):void {
    jsBridge.error(message);
    throw message;
  }
  
  private function parseEvent(event:WebSocketEvent):Object {
    var webSocket:WebSocket = event.target as WebSocket;
    var eventObj:Object = {};
    eventObj.type = event.type;
    eventObj.webSocketId = webSocket.getId();
    eventObj.readyState = webSocket.getReadyState();
    if (event.message !== null) {
      eventObj.message = event.message;
    }
    return eventObj;
  }
  
  /**
   * Socket interface
   */
  public function create(
    webSocketId:int,
    url:String, protocol:String,
    proxyHost:String = null, proxyPort:int = 0,
    headers:String = null):void {
    if (!manualPolicyFileLoaded) {
      loadDefaultPolicyFile(url);
    }
    var newSocket:WebSocket = new WebSocket(
        this, webSocketId, url, protocol, proxyHost, proxyPort, headers);
    newSocket.addEventListener("open", onSocketEvent);
    newSocket.addEventListener("close", onSocketEvent);
    newSocket.addEventListener("error", onSocketEvent);
    newSocket.addEventListener("message", onSocketEvent);
    webSockets[webSocketId] = newSocket;
  }
  
  public function send(webSocketId:int, encData:String):int {
    var webSocket:WebSocket = webSockets[webSocketId];
    return webSocket.send(encData);
  }
  
  public function close(webSocketId:int):void {
    var webSocket:WebSocket = webSockets[webSocketId];
    webSocket.close();
  }
  
  public function receiveEvents():Object {
    var result:Object = eventQueue;
    eventQueue = [];
    return result;
  }
  
  /****************
   * Socket event handler
   */
  public function onSocketEvent(event:WebSocketEvent):void {
    var eventObj:Object = parseEvent(event);
    eventQueue.push(eventObj);
    processEvents();
  }
  
  /**
   * Process our event queue.  If javascript is unresponsive, set
   * a timeout and try again.
   */
  public function processEvents():void {
    if (eventQueue.length == 0) return;
    var success:Boolean = jsBridge.fireEvent();
    if (!success) {
      setTimeout(processEvents, 500);
    }
  }
  
}

}
