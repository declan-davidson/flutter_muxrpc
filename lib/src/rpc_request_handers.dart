import 'rpc_message.dart';
import 'rpc_message_constructor.dart';
import 'package:dart_secret_handshake/network.dart';

void blobHasRequestHandler(Peer peer, RpcMessage message, { int? clientNumber }) {
  RpcMessage returnMessage = rpcBoolReturn(true, message.isStream, message.isEndOrError, -message.requestNum);

  if(clientNumber != null){
    peer.send(encodeRpcMessage(returnMessage), clientNumber: clientNumber);
  }
  else{
    peer.send(encodeRpcMessage(returnMessage));
  } 
}