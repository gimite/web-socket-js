package bridge {

import flash.external.ExternalInterface;
import flash.utils.setTimeout;

/**
 * This class provides a central location for ExternalInterface 
 * communication between flash and javascript.
 */
public class JSBridge {
  
  private var controller:WebSocketMain;
  /**
   * Class constructor.
   */
  public function JSBridge(controller:WebSocketMain)
  {
    ExternalInterface.addCallback("setCallerUrl", onSetCallerUrl);
    ExternalInterface.addCallback("setDebug", onSetDebug);
    ExternalInterface.addCallback("create", onCreate);
    ExternalInterface.addCallback("send", onSend);
    ExternalInterface.addCallback("close", onClose);
    ExternalInterface.addCallback("loadFlashPolicyFile", onLoadFlashPolicyFile);
    ExternalInterface.addCallback("receiveEvents", onReceiveEvents);
    
    this.controller = controller;
  }
  
  /******************
   * Inbound calls from javascript
   ******************/
  
  /**
   * Set the url that this websocket is being opened from.
   * @param callerUrl  The url that hosts the web socket request.
   */
  public function onSetCallerUrl(callerUrl:String):void {
    controller.setCallerUrl(callerUrl);
  }
  
  /**
   * Set the debugging state.
   * @param debug  True for debugging, false otherwise.
   */
  public function onSetDebug(debug:Boolean):void {
    controller.setDebug(debug);
  }
  
  /**
   * Create a new websocket.
   * @param webSocketId  Internal id for the new web socket.
   * @param url      URL of the new socket.
   * @param protocol    Protocol for the new socket.
   * @param proxyHost    Host for the new socket.
   * @param proxyPort    Port for the new socket.
   * @param headers    Headers to include in socket communications.
   */
  public function onCreate(
      webSocketId:Number, url:String, protocol:String,
      proxyHost:String, proxyPort:Number, headers:String):void {
    controller.create(webSocketId, url, protocol, proxyHost, proxyPort, headers);
  }
  
  /**
   * Send the passed data to through the identified socket.
   * @param webSocketId  Internal id for the target socket.
   * @param data      The data to send through the socket.
   */
  public function onSend(webSocketId:Number, data:String):int {
    return controller.send(webSocketId, data);
  }
  
  /**
   * Close the identified socket.
   * @param webSocketId  Internal id for the target socket.
   */
  public function onClose(webSocketId:Number):void {
    controller.close(webSocketId);
  }
  
  /**
   * Load a flash security policy file with the passed url.
   * @param policyUrl  The url for the policy file to load.
   */
  public function onLoadFlashPolicyFile(policyUrl:String):void {
    setTimeout(controller.loadManualPolicyFile, 1, policyUrl);
  }
  
  public function onReceiveEvents():Object {
    return controller.receiveEvents();
  }
  
  /******************
   * Outbound calls to javascript
   ******************/
  /**
   * Send a log message to javascript.
   * @param message  The log message.
   */
  public function log(message:String):void {
    ExternalInterface.call("WebSocket.__log", encodeURIComponent("[WebSocket] " + message));
  }
  
  /**
   * Send an error message to javascript.
   * @param message  The error message.
   */
  public function error(message:String):void {
    ExternalInterface.call("WebSocket.__error", encodeURIComponent("[WebSocket] " + message));
  }
  
  /**
   * Alert javascript that flash has been initialized and is ready
   * for communication.
   */
  public function flashInitialized():void {
    ExternalInterface.call("WebSocket.__onFlashInitialized");
  }
  
  /**
   * Notifies JavaScript that some event was fired.
   * @returns  True if javascript acknowledges receipt of the message, returns
   *       false if javascript is unresponsive.
   */
  public function fireEvent():Boolean {
    return ExternalInterface.call("WebSocket.__onFlashEvent") ? true : false;
  }
}

}