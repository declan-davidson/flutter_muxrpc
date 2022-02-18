import 'rpc_message.dart';

const streamTypes = ["source", "sink", "duplex"];

RpcMessage rpcErrorMessage(bool isStream, int requestNum){
  Map<String, dynamic> data = {"name": "Error"};

  return RpcMessage.fromMapData(data, isStream, true, -requestNum);
}

RpcMessage rpcRequest(String function, List<dynamic> args, String functionType, int requestNum){
  Map<String, dynamic> data = {"name": function.split("."), "type": functionType, "args": args};

  return RpcMessage.fromMapData(data, streamTypes.contains(functionType), false, requestNum);
}

RpcMessage rpcBoolReturn(bool data, bool isStream, bool isEndOrError, int requestNum){
  return RpcMessage.fromBoolData(data, isStream, isEndOrError, -requestNum);
}

RpcMessage rpcJsonReturn(Map<String, dynamic> data, bool isStream, bool isEndOrError, int requestNum){
  return RpcMessage.fromMapData(data, isStream, isEndOrError, -requestNum);
}

RpcMessage rpcStreamEndMessage(int requestNum){
  return RpcMessage.fromBoolData(true, true, true, -requestNum);
}