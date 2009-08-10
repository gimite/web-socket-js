package {

import flash.display.*;
import flash.events.*;
import flash.external.*;
import flash.net.*;
import flash.system.*;
import flash.utils.*;
import mx.core.*;
import mx.controls.*;
import mx.events.*;
import mx.utils.*;

public class WebSocketMessageEvent extends Event {
  
  public var data:String;
  
  public function WebSocketMessageEvent(type:String, data:String) {
    super(type);
    this.data = data;
  }
  
}

}
