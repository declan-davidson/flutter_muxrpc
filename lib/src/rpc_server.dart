import 'dart:async';
import 'package:dart_secret_handshake/network.dart';
import 'package:libsodium/libsodium.dart';
import 'package:dart_secret_handshake/util.dart';
import 'rpc_message.dart';
import 'rpc_message_constructor.dart';
import 'package:collection/collection.dart';
import 'package:scuttlebutt_feed/scuttlebutt_feed.dart';

class RpcServer{
  late Server server;
  int nextRequestNumber = 1;
  StreamController<ClientMessageTuple> controller = StreamController();
  Map<int, Map<int, StreamController<RpcMessage>>> activeClients = {};
  Map<String, Function(int, RpcMessage)> asyncRequestHandlers = {};
  Map<String, Function(int, StreamController<RpcMessage>)> streamRequestHandlers = {};

  RpcServer(){
    //This will eventually get the correct longterm keys from disk (or from being passed them)
    server = Server(Sodium.cryptoSignSeedKeypair(defaultServerSeed), controller.sink);
    
    streamRequestHandlers = {
      "createHistoryStream": handleCreateHistoryStream
    };
  }

  void start(){
    print("Starting RPC server");
    server.start();
    handleReceivedMessages();
  }
  
  void handleReceivedMessages(){
    controller.stream.listen((clientMessageTuple) {
      int clientNumber = clientMessageTuple.clientNumber;
      RpcMessage decodedMessage = decodeRpcMessage(clientMessageTuple.message);

      if(!(activeClients.containsKey(clientNumber))){
        activeClients[clientNumber] = {};
      }
      
      _handleRpcMessage(clientNumber, decodedMessage);
    });
  }

  void _handleRpcMessage(int clientNumber, RpcMessage message){
    int requestNumber = message.requestNum;
    StreamController<RpcMessage>? controller = activeClients[clientNumber]![requestNumber];

    if(controller != null){
      controller.add(message);
    }
    else{
      if(requestNumber > 0){
        if(message.isStream){
          _handleStreamRequest(clientNumber, message);
        }
        else{
          _handleAsyncRequest(clientNumber, message);
        }
      }
      else if(requestNumber < 0){
        _sendError(clientNumber, message);
      }
    }
  }

  void _handleAsyncRequest(int clientNumber, RpcMessage message){
    String requestedProcedureName = List<String>.from(message.data["name"]).join(".");
    Function(int, RpcMessage)? handler = asyncRequestHandlers[requestedProcedureName];

    if(handler != null){
      handler(clientNumber, message);
    }
    else{
      _sendError(clientNumber, message);
    }
  }

  void _handleStreamRequest(int clientNumber, RpcMessage message){
    String requestedProcedureName = List<String>.from(message.data["name"]).join(".");
    Function(int, StreamController<RpcMessage>)? handler = streamRequestHandlers[requestedProcedureName];

    if(handler != null){
      StreamController<RpcMessage> controller = StreamController();

      handler(clientNumber, controller);
      activeClients[clientNumber]![message.requestNum] = controller;
      controller.sink.add(message);
    }
    else{
      _sendError(clientNumber, message);
    }
  }

  void handleCreateHistoryStream(int clientNumber, StreamController<RpcMessage> controller) async {
    bool finished = false;

    await for(RpcMessage message in controller.stream){
      if(message.isEndOrError){
        if(finished){
          _removeHandlerController(clientNumber, message.requestNum);
          break;
        }
      }

      Map<String, dynamic> args = message.data["args"][0];
      List<FeedMessage> retrievedMessages = await FeedService.retrieveMessages(identity: args["id"], sequence: args["sequence"], limit: args["limit"]);

      for(FeedMessage retrievedMessage in retrievedMessages){
        RpcMessage returnMessage = rpcJsonReturn(retrievedMessage.toRpcReturnMap(), true, false, message.requestNum);
        server.send(clientNumber, encodeRpcMessage(returnMessage));
      }

      _sendEndMessage(clientNumber, -(message.requestNum));
      finished = true;
    }
  }

  void _rpcCall(int clientNumber, String functionName, Map<String, dynamic> args, Function(int, StreamController<RpcMessage>) returnHandler){
    int requestNumber = nextRequestNumber++;
    int returnNumber = -requestNumber;
    RpcMessage request = rpcRequest(functionName, [args], "source", requestNumber);

    StreamController<RpcMessage> controller = StreamController<RpcMessage>();
    returnHandler(returnNumber, controller);
    activeClients[clientNumber]![returnNumber] = controller;

    server.send(clientNumber, encodeRpcMessage(request));
  }

  void _sendEndMessage(int clientNumber, int requestNumber){
    RpcMessage endMessage = RpcMessage.fromBoolData(true, true, true, requestNumber);
    server.send(clientNumber, encodeRpcMessage(endMessage));
  }

  void _sendError(int clientNumber, RpcMessage message){
    print("error");
    RpcMessage errorMessage = rpcErrorMessage(message.isStream, message.requestNum);
    server.send(clientNumber, encodeRpcMessage(errorMessage));
  }

  void _removeHandlerController(int clientNumber, int requestNumber){
    activeClients[clientNumber]!.remove(requestNumber);
  }

  void createHistoryStream(){
    RpcMessage request = rpcRequest("createHistoryStream", [{"id": "@+gSP6JVoo4+tFPnk5Sp3JDDWTQlTXFA4Ev0xfDjW69c=.ed25519", "sequence": 4, "limit": 1}], "source", 1);
    server.send(1, encodeRpcMessage(request));
  }
}