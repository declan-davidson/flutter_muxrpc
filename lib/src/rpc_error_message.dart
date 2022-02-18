import 'rpc_message.dart';

const streamTypes = ["source", "sink", "duplex"];

RpcMessage rpcErrorMessage(String functionType, int requestNum){
  Map<String, dynamic> data = {"name": "Error"};

  return RpcMessage.fromMapData(data, streamTypes.contains(functionType), true, -requestNum);
}