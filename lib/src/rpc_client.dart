import 'dart:async';
import 'dart:typed_data';
import 'package:dart_secret_handshake/network.dart';
import 'package:libsodium/libsodium.dart';
import 'package:dart_secret_handshake/util.dart';
import 'rpc_message.dart';
import 'rpc_message_constructor.dart';
import 'package:collection/collection.dart';
import 'package:scuttlebutt_feed/scuttlebutt_feed.dart';

class RpcClient {
  late Client client;
  StreamController<Uint8List> controller = StreamController();
  int nextRequestNumber = 1;
  Map<int, StreamController<RpcMessage>> requestHandlerStreamControllers = {};
  Map<String, Function(RpcMessage)> asyncRequestHandlers = {};
  Map<String, Function(StreamController<RpcMessage>)> streamRequestHandlers = {};

  RpcClient(){
    client = Client("127.0.0.1", 4567, Sodium.cryptoSignSeedKeypair(defaultClientSeed), defaultServerLongtermKeys.pk, controller.sink);

    streamRequestHandlers["createHistoryStream"] = handleCreateHistoryStream;
  }

  Future<void> start() async {
    await client.start();
    _handleReceivedMessages();
  }

  void _handleReceivedMessages(){
    controller.stream.listen((encodedMessage) {
      RpcMessage message = decodeRpcMessage(encodedMessage);
      StreamController<RpcMessage>? handlerStreamController = requestHandlerStreamControllers[message.requestNum];

      _handleRpcMessage(message, handlerStreamController);
    });
  }

  void _handleRpcMessage(RpcMessage message, StreamController<RpcMessage>? controller){
    int requestNumber = message.requestNum;

    if(controller != null){
      controller.sink.add(message);
    }
    else{
      if(requestNumber > 0){
        if(message.isStream){
          _handleStreamRequest(message);
        }
        else{
          _handleAsyncRequest(message);
        }
      }
      else if(requestNumber < 0){
        _sendError(message);
      }
    }
  }

  void _handleAsyncRequest(RpcMessage message){
    String requestedProcedureName = List<String>.from(message.data["name"]).join(".");
    Function(RpcMessage)? handler;

    handler = asyncRequestHandlers[requestedProcedureName];

    if(handler != null){
      handler(message);
    }
    else{
      _sendError(message);
    }
  }

  void _handleStreamRequest(RpcMessage message){
    String requestedProcedureName = List<String>.from(message.data["name"]).join(".");
    Function(StreamController<RpcMessage>)? handler = streamRequestHandlers[requestedProcedureName];

    if(handler != null){
      StreamController<RpcMessage> controller = StreamController();

      handler(controller);
      requestHandlerStreamControllers[message.requestNum] = controller;
      controller.sink.add(message);
    }
    else{
      _sendError(message);
    }
  }

  void createHistoryStream({required String id, int? sequence, int? limit, bool live = false, bool old = true, bool keys = true}){
    void returnHandler (int returnNumber, StreamController<RpcMessage> controller) async {
      await for(RpcMessage message in controller.stream){
        if(message.isEndOrError){
          //We'll handle if it's an error, but for now let's just send back our end message
          _sendEndMessage(-returnNumber);
          break;
        }

        //Store the message
        FeedService.receiveMessage(message.data);
      }

      controller.close();
      _removeHandlerController(returnNumber);
    }

    Map<String, dynamic> args = {"id": id};
    if(sequence != null) args["sequence"] = sequence;
    if(limit != null) args["limit"] = limit;

    _rpcCall("createHistoryStream", args, returnHandler);
  }

  void handleCreateHistoryStream(StreamController<RpcMessage> controller) async {
    bool finished = false;

    await for(RpcMessage message in controller.stream){
      if(message.isEndOrError){
        if(finished){
          _removeHandlerController(message.requestNum);
          break;
        }
      }

      Map<String, dynamic> args = message.data["args"][0];
      List<FeedMessage> retrievedMessages = await FeedService.retrieveMessages(identity: args["id"], sequence: args["sequence"], limit: args["limit"]);

      for(FeedMessage retrievedMessage in retrievedMessages){
        RpcMessage returnMessage = rpcJsonReturn(retrievedMessage.toRpcReturnMap(), true, false, message.requestNum);
        client.send(encodeRpcMessage(returnMessage));
      }

      _sendEndMessage(-(message.requestNum));
      finished = true;
    }
  }

  void _rpcCall(String functionName, Map<String, dynamic> args, Function(int, StreamController<RpcMessage>) returnHandler){
    int requestNumber = nextRequestNumber++;
    int returnNumber = -requestNumber;
    RpcMessage request = rpcRequest(functionName, [args], "source", requestNumber);

    StreamController<RpcMessage> controller = StreamController<RpcMessage>();
    returnHandler(returnNumber, controller);
    requestHandlerStreamControllers[returnNumber] = controller;

    client.send(encodeRpcMessage(request));
  }

  void _sendError(RpcMessage message){
    RpcMessage errorMessage = rpcErrorMessage(message.isStream, message.requestNum);
    client.send(encodeRpcMessage(errorMessage));
  }

  void _sendEndMessage(int requestNumber){
    RpcMessage endMessage = RpcMessage.fromBoolData(true, true, true, requestNumber);
    client.send(encodeRpcMessage(endMessage));
  }

  void _removeHandlerController(int requestNumber){
    requestHandlerStreamControllers.remove(requestNumber);
  }

  //Eventually this will send a goodbye RPC message (I think)
  void finish(){
    client.finish();
  }
}