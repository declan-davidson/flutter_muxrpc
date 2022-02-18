//An RPC request is a specific RPC message which is json, has a positive request num, isn't end or error, and may or may not be streaming

import 'rpc_message.dart';

const streamTypes = ["source", "sink", "duplex"];

RpcMessage rpcRequest(String function, List<dynamic> args, String functionType, int requestNum){
  Map<String, dynamic> data = {"name": function.split("."), "type": functionType, "args": args};

  return RpcMessage.fromMapData(data, streamTypes.contains(functionType), false, requestNum);
}