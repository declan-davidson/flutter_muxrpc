import "dart:convert";
import 'dart:typed_data';

enum RpcMessageType{
  binary,
  text,
  json
}

Uint8List encodeRpcMessage(RpcMessage message){
  Uint8List flags;
  Uint32List bodyLength = Uint32List(1);
  Int32List requestNum = Int32List(1);
  Uint8List body = _encodeData(message.type, message.data);

  flags = _generateFlags(message.type, message.isEndOrError, message.isStream);
  bodyLength[0] = body.length;
  requestNum[0] = message.requestNum;

  return _toBytes([flags, bodyLength.buffer.asUint8List(), requestNum.buffer.asUint8List(), body]);
}

Uint8List _encodeData(RpcMessageType type, dynamic data){
  Utf8Encoder utf8Encoder = Utf8Encoder();

  if(type == RpcMessageType.text){
    return utf8Encoder.convert(data);
  }
  else if(type == RpcMessageType.json){
    return utf8Encoder.convert(jsonEncode(data));
  }
  else{
    return data;
  }
}

Uint8List _generateFlags(RpcMessageType type, bool isEndOrError, bool isStream){
  Uint8List bytes = Uint8List(1);

  bytes[0] += type.index;
  if(isEndOrError) bytes[0] += 4;
  if(isStream) bytes[0] += 8;

  return bytes;
}

RpcMessage decodeRpcMessage(Uint8List message){
  RpcMessageType type;
  bool isStream = false;
  bool isEndOrError = false;

  int flags = message.sublist(0, 1)[0];
  int bodyLength = message.sublist(1, 5).buffer.asUint32List()[0];
  int requestNum = message.sublist(5, 9).buffer.asInt32List()[0];

  if(flags & 1 == 1){
    type = RpcMessageType.text;
  }
  else if(flags & 2 == 2){
    type = RpcMessageType.json;
  }
  else{
    type = RpcMessageType.binary;
  }

  if(flags & 4 == 4){
    isEndOrError = true;
  }

  if(flags & 8 == 8){
    isStream = true;
  }

  var data = _decodeBody(message.sublist(9), type);

  if(type == RpcMessageType.binary){
    return RpcMessage.fromBinaryData(data, isStream, isEndOrError, requestNum);
  }
  else if(type == RpcMessageType.json){
    if(data.runtimeType == bool){
      return RpcMessage.fromBoolData(data, isStream, isEndOrError, requestNum);
    }
    else{
      return RpcMessage.fromMapData(data, isStream, isEndOrError, requestNum);
    }
  }
  else{
    return RpcMessage.fromTextData(data, isStream, isEndOrError, requestNum);
  }
}

_decodeBody(Uint8List body, RpcMessageType type){
  if(type == RpcMessageType.text){
    return utf8.decode(body);
  }
  else if(type == RpcMessageType.json){
    return json.decode(utf8.decode(body));
  }
  else{
    return body;
  }
}

Uint8List _toBytes(List<Uint8List> elements){
  BytesBuilder bb = BytesBuilder();

  for(Uint8List element in elements){
    bb.add(element);
  }

  Uint8List bytes = bb.toBytes();
  bb.clear(); //This may be unnecessary
  return bytes;
}

//Encapsulates an Rpc message
class RpcMessage{
  late RpcMessageType type;
  var data;
  bool isStream;
  bool isEndOrError;
  int requestNum;

  //Data needs to be binary (Uint8) for binary type, String for text type, or serialisable for json type. Need to figure out how to make sure of this!
  RpcMessage.fromBinaryData(Uint8List data, this.isStream, this.isEndOrError, this.requestNum){
    this.data = data;
    type = RpcMessageType.binary;
  }

  RpcMessage.fromMapData(Map<String, dynamic> data, this.isStream, this.isEndOrError, this.requestNum){
    this.data = data;
    type = RpcMessageType.json;
  }

  RpcMessage.fromBoolData(bool data, this.isStream, this.isEndOrError, this.requestNum){
    this.data = data;
    type = RpcMessageType.json;
  }

  RpcMessage.fromTextData(String data, this.isStream, this.isEndOrError, this.requestNum){
    this.data = data;
    type = RpcMessageType.text;
  }

  @override
  String toString() {
    return "Type: ${type.toString()}, isStream: $isStream, isEndOrError: $isEndOrError, requestNum: $requestNum, data: ${data.toString()}";
  }
}