// Copyright: Hiroshi Ichikawa <http://gimite.net/en/>
// License: New BSD License
// Reference: http://dev.w3.org/html5/websockets/
// Reference: http://tools.ietf.org/html/draft-ietf-hybi-thewebsocketprotocol-10

package net.gimite.websocket {

import com.adobe.net.proxies.RFC2817Socket;
import com.gsolo.encryption.SHA1;
import com.hurlant.crypto.tls.TLSConfig;
import com.hurlant.crypto.tls.TLSEngine;
import com.hurlant.crypto.tls.TLSSecurityParameters;
import com.hurlant.crypto.tls.TLSSocket;

import flash.display.*;
import flash.events.*;
import flash.external.*;
import flash.net.*;
import flash.system.*;
import flash.utils.*;

import mx.controls.*;
import mx.core.*;
import mx.events.*;
import mx.utils.*;

public class WebSocket extends EventDispatcher {
  
  private static var WEB_SOCKET_GUID:String = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
  
  private static var CONNECTING:int = 0;
  private static var OPEN:int = 1;
  private static var CLOSING:int = 2;
  private static var CLOSED:int = 3;
  
  private static var OPCODE_CONTINUATION:int = 0x00;
  private static var OPCODE_TEXT:int = 0x01;
  private static var OPCODE_BINARY:int = 0x02;
  private static var OPCODE_CLOSE:int = 0x08;
  private static var OPCODE_PING:int = 0x09;
  private static var OPCODE_PONG:int = 0x0a;
  
  private var id:int;
  private var url:String;
  private var scheme:String;
  private var host:String;
  private var port:uint;
  private var path:String;
  private var origin:String;
  private var requestedProtocols:Array;
  private var cookie:String;
  private var headers:String;
  
  private var rawSocket:Socket;
  private var tlsSocket:TLSSocket;
  private var tlsConfig:TLSConfig;
  private var socket:Socket;
  
  private var acceptedProtocol:String;
  private var expectedDigest:String;
  
  private var buffer:ByteArray = new ByteArray();
  private var headerState:int = 0;
  private var readyState:int = CONNECTING;
  
  private var logger:IWebSocketLogger;
  private var base64Encoder:Base64Encoder = new Base64Encoder();
  
  public function WebSocket(
      id:int, url:String, protocols:Array, origin:String,
      proxyHost:String, proxyPort:int,
      cookie:String, headers:String,
      logger:IWebSocketLogger) {
    this.logger = logger;
    this.id = id;
    this.url = url;
    var m:Array = url.match(/^(\w+):\/\/([^\/:]+)(:(\d+))?(\/.*)?(\?.*)?$/);
    if (!m) fatal("SYNTAX_ERR: invalid url: " + url);
    this.scheme = m[1];
    this.host = m[2];
    var defaultPort:int = scheme == "wss" ? 443 : 80;
    this.port = parseInt(m[4]) || defaultPort;
    this.path = (m[5] || "/") + (m[6] || "");
    this.origin = origin;
    this.requestedProtocols = protocols;
    this.cookie = cookie;
    // if present and not the empty string, headers MUST end with \r\n
    // headers should be zero or more complete lines, for example
    // "Header1: xxx\r\nHeader2: yyyy\r\n"
    this.headers = headers;
    
    if (proxyHost != null && proxyPort != 0){
      if (scheme == "wss") {
        fatal("wss with proxy is not supported");
      }
      var proxySocket:RFC2817Socket = new RFC2817Socket();
      proxySocket.setProxyInfo(proxyHost, proxyPort);
      proxySocket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
      rawSocket = socket = proxySocket;
    } else {
      rawSocket = new Socket();
      if (scheme == "wss") {
        tlsConfig= new TLSConfig(TLSEngine.CLIENT,
            null, null, null, null, null,
            TLSSecurityParameters.PROTOCOL_VERSION);
        tlsConfig.trustAllCertificates = true;
        tlsConfig.ignoreCommonNameMismatch = true;
        tlsSocket = new TLSSocket();
        tlsSocket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
        socket = tlsSocket;
      } else {
        rawSocket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
        socket = rawSocket;
      }
    }
    rawSocket.addEventListener(Event.CLOSE, onSocketClose);
    rawSocket.addEventListener(Event.CONNECT, onSocketConnect);
    rawSocket.addEventListener(IOErrorEvent.IO_ERROR, onSocketIoError);
    rawSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSocketSecurityError);
    rawSocket.connect(host, port);
  }
  
  /**
   * @return  This WebSocket's ID.
   */
  public function getId():int {
    return this.id;
  }
  
  /**
   * @return this WebSocket's readyState.
   */
  public function getReadyState():int {
    return this.readyState;
  }

  public function getAcceptedProtocol():String {
    return this.acceptedProtocol;
  }
  
  public function send(encData:String):int {
    var data:String = decodeURIComponent(encData);
    var dataBytes:ByteArray = new ByteArray();
    dataBytes.writeUTFBytes(data);
    if (readyState == OPEN) {
      // TODO: binary API support
      var frame:WebSocketFrame = new WebSocketFrame();
      frame.opcode = OPCODE_TEXT;
      frame.payload = dataBytes;
      sendFrame(frame);
      logger.log("send: " + data);
      return -1;
    } else if (readyState == CLOSING || readyState == CLOSED) {
      return dataBytes.length;
    } else {
      fatal("invalid state");
      return 0;
    }
  }
  
  public function close(isError:Boolean = false, byServer:Boolean = false):void {
    try {
      if (readyState == OPEN && !isError) {
        // TODO: send code and reason
        var frame:WebSocketFrame = new WebSocketFrame();
        frame.opcode = OPCODE_CLOSE;
        frame.payload = new ByteArray();
        sendFrame(frame);
      }
      if (byServer || isError) {
        socket.close();
      }
    } catch (ex:Error) { }
    if (byServer || isError) {
      logger.log("closed");
      readyState = CLOSED;
      this.dispatchEvent(new WebSocketEvent(isError ? "error" : "close"));
    } else {
      logger.log("closing");
      readyState = CLOSING;
    }
  }
  
  private function onSocketConnect(event:Event):void {
    logger.log("connected");

    if (scheme == "wss") {
      logger.log("starting SSL/TLS");
      tlsSocket.startTLS(rawSocket, host, tlsConfig);
    }
    
    var defaultPort:int = scheme == "wss" ? 443 : 80;
    var hostValue:String = host + (port == defaultPort ? "" : ":" + port);
    var key:String = generateKey();

    SHA1.b64pad = "=";
    expectedDigest = SHA1.b64_sha1(key + WEB_SOCKET_GUID);

    var opt:String = "";
    if (requestedProtocols.length > 0) {
      opt += "Sec-WebSocket-Protocol: " + requestedProtocols.join(",") + "\r\n";
    }
    // if caller passes additional headers they must end with "\r\n"
    if (headers) opt += headers;
    
    var req:String = StringUtil.substitute(
      "GET {0} HTTP/1.1\r\n" +
      "Host: {1}\r\n" +
      "Upgrade: websocket\r\n" +
      "Connection: Upgrade\r\n" +
      "Sec-WebSocket-Key: {2}\r\n" +
      "Sec-WebSocket-Origin: {3}\r\n" +
      "Sec-WebSocket-Version: 8\r\n" +
      "Cookie: {4}\r\n" +
      "{5}" +
      "\r\n",
      path, hostValue, key, origin, cookie, opt);
    logger.log("request header:\n" + req);
    socket.writeUTFBytes(req);
    socket.flush();
  }

  private function onSocketClose(event:Event):void {
    logger.log("closed");
    readyState = CLOSED;
    this.dispatchEvent(new WebSocketEvent("close"));
  }

  private function onSocketIoError(event:IOErrorEvent):void {
    var message:String;
    if (readyState == CONNECTING) {
      message = "cannot connect to Web Socket server at " + url + " (IoError: " + event.text + ")";
    } else {
      message =
          "error communicating with Web Socket server at " + url +
          " (IoError: " + event.text + ")";
    }
    onError(message);
  }

  private function onSocketSecurityError(event:SecurityErrorEvent):void {
    var message:String;
    if (readyState == CONNECTING) {
      message =
          "cannot connect to Web Socket server at " + url + " (SecurityError: " + event.text + ")\n" +
          "make sure the server is running and Flash socket policy file is correctly placed";
    } else {
      message =
          "error communicating with Web Socket server at " + url +
          " (SecurityError: " + event.text + ")";
    }
    onError(message);
  }
  
  private function onError(message:String):void {
    if (readyState == CLOSED) return;
    logger.error(message);
    close(readyState != CONNECTING);
  }

  private function onSocketData(event:ProgressEvent):void {
    var pos:int = buffer.length;
    socket.readBytes(buffer, pos);
    for (; pos < buffer.length; ++pos) {
      if (headerState < 4) {
        // try to find "\r\n\r\n"
        if ((headerState == 0 || headerState == 2) && buffer[pos] == 0x0d) {
          ++headerState;
        } else if ((headerState == 1 || headerState == 3) && buffer[pos] == 0x0a) {
          ++headerState;
        } else {
          headerState = 0;
        }
        if (headerState == 4) {
          var headerStr:String = readUTFBytes(buffer, 0, pos + 1);
          logger.log("response header:\n" + headerStr);
          if (!validateHandshake(headerStr)) return;
          removeBufferBefore(pos + 1);
          pos = -1;
          readyState = OPEN;
          this.dispatchEvent(new WebSocketEvent("open"));
        }
      } else {
        var frame:WebSocketFrame = parseFrame();
        if (frame) {
          removeBufferBefore(frame.length);
          pos = -1;
          switch (frame.opcode) {
            case OPCODE_CONTINUATION:
              fatal("Received continuation frame, which is not implemented.");
              break;
            case OPCODE_TEXT:
              var data:String = readUTFBytes(frame.payload, 0, frame.payload.length);
              this.dispatchEvent(new WebSocketEvent("message", encodeURIComponent(data)));
              break;
            case OPCODE_BINARY:
              fatal("Received binary data, which is not supported.");
              break;
            case OPCODE_CLOSE:
              // TODO: extract code and reason string
              logger.log("received closing frame");
              close(false, true);
              break;
            case OPCODE_PING:
              sendPong(frame.payload);
              break;
            case OPCODE_PONG:
              break;
            default:
              fatal("Received unknown opcode: " + frame.opcode);
              break;
          }
        }
      }
    }
  }
  
  private function validateHandshake(headerStr:String):Boolean {
    var lines:Array = headerStr.split(/\r\n/);
    if (!lines[0].match(/^HTTP\/1.1 101 /)) {
      onError("bad response: " + lines[0]);
      return false;
    }
    var header:Object = {};
    var lowerHeader:Object = {};
    for (var i:int = 1; i < lines.length; ++i) {
      if (lines[i].length == 0) continue;
      var m:Array = lines[i].match(/^(\S+): (.*)$/);
      if (!m) {
        onError("failed to parse response header line: " + lines[i]);
        return false;
      }
      header[m[1].toLowerCase()] = m[2];
      lowerHeader[m[1].toLowerCase()] = m[2].toLowerCase();
    }
    if (lowerHeader["upgrade"] != "websocket") {
      onError("invalid Upgrade: " + header["Upgrade"]);
      return false;
    }
    if (lowerHeader["connection"] != "upgrade") {
      onError("invalid Connection: " + header["Connection"]);
      return false;
    }
    if (!lowerHeader["sec-websocket-accept"]) {
      onError(
        "The WebSocket server speaks old WebSocket protocol, " +
        "which is not supported by web-socket-js. " +
        "It requires WebSocket protocol HyBi 10. " +
        "Try newer version of the server if available.");
      return false;
    }
    var replyDigest:String = header["sec-websocket-accept"]
    if (replyDigest != expectedDigest) {
      onError("digest doesn't match: " + replyDigest + " != " + expectedDigest);
      return false;
    }
    if (requestedProtocols.length > 0) {
      acceptedProtocol = header["sec-websocket-protocol"];
      if (requestedProtocols.indexOf(acceptedProtocol) < 0) {
        onError("protocol doesn't match: '" +
          acceptedProtocol + "' not in '" + requestedProtocols.join(",") + "'");
        return false;
      }
    }
    return true;
  }

  private function sendPong(payload:ByteArray):void {
    var frame:WebSocketFrame = new WebSocketFrame();
    frame.opcode = OPCODE_PONG;
    frame.payload = payload;
    sendFrame(frame);
  }
  
  private function sendFrame(frame:WebSocketFrame):void {
    
    var plength:uint = frame.payload.length;
    
    // Generates a mask.
    var mask:ByteArray = new ByteArray();
    for (var i:int = 0; i < 4; i++) {
      mask.writeByte(randomInt(0, 255));
    }
    
    var header:ByteArray = new ByteArray();
    header.writeByte((frame.fin ? 0x80 : 0x00) | frame.opcode);  // FIN + opcode
    if (plength <= 125) {
      header.writeByte(0x80 | plength);  // Masked + length
    } else if (plength > 125 && plength < 65536) {
      header.writeByte(0x80 | 126);  // Masked + 126
      header.writeShort(plength);
    } else if (plength >= 65536 && plength < 4294967296) {
      header.writeByte(0x80 | 127);  // Masked + 127
      header.writeUnsignedInt(0);  // zero high order bits
      header.writeUnsignedInt(plength);
    } else {
      fatal("Send frame size too large");
    }
    header.writeBytes(mask);
    
    var maskedPayload:ByteArray = new ByteArray();
    maskedPayload.length = frame.payload.length;
    for (i = 0; i < frame.payload.length; i++) {
      maskedPayload[i] = mask[i % 4] ^ frame.payload[i];
    }

    socket.writeBytes(header);
    socket.writeBytes(maskedPayload);
    socket.flush();
    
  }

  private function parseFrame():WebSocketFrame {
    
    var frame:WebSocketFrame = new WebSocketFrame();
    var hlength:uint = 0;
    var plength:uint = 0;
    
    hlength = 2;
    if (buffer.length < hlength) {
      return null;
    }

    frame.opcode  = buffer[0] & 0x0f;
    frame.fin     = (buffer[0] & 0x80) != 0;
    plength = buffer[1] & 0x7f;

    if (plength == 126) {
      
      hlength = 4;
      if (buffer.length < hlength) {
        return null;
      }
      buffer.endian = Endian.BIG_ENDIAN;
      buffer.position = 2;
      plength = buffer.readUnsignedShort();
      
    } else if (plength == 127) {
      
      hlength = 10;
      if (buffer.length < hlength) {
        return null;
      }
      buffer.endian = Endian.BIG_ENDIAN;
      buffer.position = 2;
      // Protocol allows 64-bit length, but we only handle 32-bit
      var big:uint = buffer.readUnsignedInt(); // Skip high 32-bits
      plength = buffer.readUnsignedInt(); // Low 32-bits
      if (big != 0) {
        fatal("Frame length exceeds 4294967295. Bailing out!");
        return null;
      }
      
    }

    if (buffer.length < hlength + plength) {
      return null;
    }
    
    frame.length = hlength + plength;
    frame.payload = new ByteArray();
    buffer.position = hlength;
    buffer.readBytes(frame.payload, 0, plength);
    return frame;
    
  }
  
  private function removeBufferBefore(pos:int):void {
    if (pos == 0) return;
    var nextBuffer:ByteArray = new ByteArray();
    buffer.position = pos;
    buffer.readBytes(nextBuffer);
    buffer = nextBuffer;
  }
  
  private function generateKey():String {
    var vals:ByteArray = new ByteArray();
    vals.length = 16;
    for (var i:int = 0; i < vals.length; ++i) {
        vals[i] = randomInt(0, 127);
    }
    base64Encoder.reset();
    base64Encoder.encodeBytes(vals);
    return base64Encoder.toString();
  }
  
  private function readUTFBytes(buffer:ByteArray, start:int, numBytes:int):String {
    buffer.position = start;
    var data:String = "";
    for(var i:int = start; i < start + numBytes; ++i) {
      // Workaround of a bug of ByteArray#readUTFBytes() that bytes after "\x00" is discarded.
      if (buffer[i] == 0x00) {
        data += buffer.readUTFBytes(i - buffer.position) + "\x00";
        buffer.position = i + 1;
      }
    }
    data += buffer.readUTFBytes(start + numBytes - buffer.position);
    return data;
  }
  
  private function randomInt(min:uint, max:uint):uint {
    return min + Math.floor(Math.random() * (Number(max) - min + 1));
  }
  
  private function fatal(message:String):void {
    logger.error(message);
    throw message;
  }

}

}
