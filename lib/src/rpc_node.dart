import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';

import 'package:dart_secret_handshake/network.dart';
import 'package:libsodium/libsodium.dart';
import 'package:dart_secret_handshake/util.dart';
import 'rpc_message.dart';
import 'rpc_message_constructor.dart';
import 'package:collection/collection.dart';
import 'package:scuttlebutt_feed/scuttlebutt_feed.dart';

abstract class RpcNode{
  Map<String, Function(StreamController<RpcMessage>, PeerHelper)> rpcRequestHandlers = {
    "createHistoryStream": handleCreateHistoryStream
  };

  void _handleRpcMessage(RpcMessage message, PeerHelper peerHelper){
    int requestNumber = message.requestNum;
    StreamController<RpcMessage>? controller = peerHelper.getRequestHandlerController();

    if(controller != null){
      controller.add(message);
    }
    else{
      if(requestNumber > 0){
        String requestedFunctionName = List<String>.from(message.data["name"]).join(".");
        Function(StreamController<RpcMessage>, PeerHelper)? requestHandler = rpcRequestHandlers[requestedFunctionName];

        if(requestHandler != null){
          StreamController<RpcMessage> controller = StreamController<RpcMessage>();

          requestHandler(controller, peerHelper);
          peerHelper.addRequestHandlerController(controller);
          controller.sink.add(message);
        }
      }
      else if(requestNumber < 0){
        _sendError(message, peerHelper);
      }
    }
  }

  void createHistoryStream({required String id, int? sequence, int? limit, bool live = false, bool old = true, bool keys = true}){
    void returnHandler (PeerHelper peerHelper, StreamController<RpcMessage> controller) async {
      await for(RpcMessage message in controller.stream){
        if(message.isEndOrError){
          //We'll handle if it's an error, but for now let's just send back our end message
          _sendEndMessage(peerHelper);
          break;
        }

        //Store the message
        FeedService.receiveMessage(message.data);
      }

      controller.close();
      peerHelper.removeRequestHandlerController();
    }

    Map<String, dynamic> args = {"id": id};
    if(sequence != null) args["sequence"] = sequence;
    if(limit != null) args["limit"] = limit;

    _rpcCall("createHistoryStream", args, returnHandler);
  }

  static void handleCreateHistoryStream(StreamController<RpcMessage> controller, PeerHelper peerHelper) async {
    bool finished = false;
    List<Map<String, dynamic>> mappedMessages = [
      {
        "key": "oG1fULgG1qvqrrA6FocSVZps+PT1I04ITy+zI0HIjIY=.sha256",
        "value": {
          "previous": null,
          "author": "@+gSP6JVoo4+tFPnk5Sp3JDDWTQlTXFA4Ev0xfDjW69c=.ed25519",
          "sequence": 0,
          "timestamp": 1644927962115,
          "hash": "sha256",
          "content": {"type": "post", "content": "Test message! 😊"},
          "signature": "hWxxrW/MPLTBQddTZRX9fafLb6n6Om9Qv6nv4w+Lfv3/lJA0iANNtrbey2aiVWEaydJ1Qpn/DCjk5h3m5pctBA==.sig.ed25519",
        },
        "timestamp": 1644927962115
      },
      {
        "key": "rEQygr9kSbSlRGF+E8la/rRadIcN897HjG5zvwLjgpY=.sha256",
        "value": {
          "previous": "oG1fULgG1qvqrrA6FocSVZps+PT1I04ITy+zI0HIjIY=.sha256",
          "author": "@+gSP6JVoo4+tFPnk5Sp3JDDWTQlTXFA4Ev0xfDjW69c=.ed25519",
          "sequence": 1,
          "timestamp": 1645019366449,
          "hash": "sha256",
          "content": {"type": "post", "content": "Another message!! 😊😊"},
          "signature": "HYhbmyJjfJCBXjYPsr3c9V1jhLdKFfSqN2e9nCmOMJ4ry/IueYYbIY/UGVUrQLvqkFn/P4RvZhVlUeTZtKEiAQ==.sig.ed25519",
        },
        "timestamp": 1645019366449
      },
      {
        "key": "736XEbqQsxiD+1sCWrFj67RkEnBTTvrWw+6lUdO74M0=.sha256",
        "value": {
          "previous": "rEQygr9kSbSlRGF+E8la/rRadIcN897HjG5zvwLjgpY=.sha256",
          "author": "@+gSP6JVoo4+tFPnk5Sp3JDDWTQlTXFA4Ev0xfDjW69c=.ed25519",
          "sequence": 2,
          "timestamp": 1645019432739,
          "hash": "sha256",
          "content": {"type": "post", "content": "Message 3! 😊😊"},
          "signature": "0dTXrFcJJiTmrz/hZch9x1XT642NR9i1bMavKN1FeIEBuQ2f0ueneon3fZFzLWtp3xd3wygLX7w227n/HCe/DQ==.sig.ed25519",
        },
        "timestamp": 1645019432739
      },
      {
        "key": "2w18S/Vc56RjtVeqwuBPo8rTjixeCIOpxftnCvDnzcM=.sha256",
        "value": {
          "previous": "736XEbqQsxiD+1sCWrFj67RkEnBTTvrWw+6lUdO74M0=.sha256",
          "author": "@+gSP6JVoo4+tFPnk5Sp3JDDWTQlTXFA4Ev0xfDjW69c=.ed25519",
          "sequence": 3,
          "timestamp": 1645019478128,
          "hash": "sha256",
          "content": {"type": "post", "content": "Message 4"},
          "signature": "MYWlviyxkV0zAUH7pcNvGX7Xxsa69hYdGK04bubIj1D919+sLs+rb097WYFfffWlMWlojlfLL3SJEaYQu2u9DQ==.sig.ed25519",
        },
        "timestamp": 1645019478128
      },
      {
        "key": "bA43USLWcHMc6qYDp7m61jHN1kHlULx5w2xS+7Yq5js=.sha256",
        "value": {
          "previous": "2w18S/Vc56RjtVeqwuBPo8rTjixeCIOpxftnCvDnzcM=.sha256",
          "author": "@+gSP6JVoo4+tFPnk5Sp3JDDWTQlTXFA4Ev0xfDjW69c=.ed25519",
          "sequence": 4,
          "timestamp": 1645019535199,
          "hash": "sha256",
          "content": {"type": "post", "content": "Message 5! 😁"},
          "signature": "OvOG9fD64NPAp+d2O1CnOGC/jzKfb1mo0tQrKyAGfljAlwNlb/Jw0cDTz75tpWZVyAyN2/3UowAlGE7QIxIcBQ==.sig.ed25519",
        },
        "timestamp": 1645019535199,
      },
      {
        "key": "IJmjKq2nMyGGV1PKrqkBa4Kdns4TlwEtQ/fkK0vkJm4=.sha256",
        "value": {
          "previous": "bA43USLWcHMc6qYDp7m61jHN1kHlULx5w2xS+7Yq5js=.sha256",
          "author": "@+gSP6JVoo4+tFPnk5Sp3JDDWTQlTXFA4Ev0xfDjW69c=.ed25519",
          "sequence": 5,
          "timestamp": 1645019655834,
          "hash": "sha256",
          "content": {"type": "post", "content": "Message 6"},
          "signature": "r6QR9D0PzllxXthlZrL6s5e0WNre/C6BeHluDDGJAWpv5lKlW2kuuBfch3keFKHub2JzLNZAOtxYM/n2gDnoCg==.sig.ed25519",
        },
        "timestamp": 1645019655834,
      },
      {
        "key": "qXi+nMLrJt9H/768i1+kCSYyt7JzJRNwPB2HHVAZZ1k=.sha256",
        "value": {
          "previous": "IJmjKq2nMyGGV1PKrqkBa4Kdns4TlwEtQ/fkK0vkJm4=.sha256",
          "author": "@+gSP6JVoo4+tFPnk5Sp3JDDWTQlTXFA4Ev0xfDjW69c=.ed25519",
          "sequence": 6,
          "timestamp": 1645019687337,
          "hash": "sha256",
          "content": {"type": "post", "content": "Message 7!"},
          "signature": "z6cxa5hf/m/wpcneo1DK6j7+JrXdtwnb5lxLBH1gUdCFOQLkgjGGG0ciBE8SfH/1IM7W/VcZrTb0Gglj+A6PAQ==.sig.ed25519",
        },
        "timestamp": 1645019687337,
      }
    ];

    await for(RpcMessage message in controller.stream){
      if(message.isEndOrError){
        if(finished){
          peerHelper.removeRequestHandlerController();
          break;
        }
      }
      
      Map<String, dynamic> args = message.data["args"][0];

      for(Map<String, dynamic> mappedMessage in mappedMessages){
        peerHelper.send(rpcJsonReturn(mappedMessage, true, false, message.requestNum));
      }

      peerHelper.send(rpcStreamEndMessage(message.requestNum));
      finished = true;
    }
  }

  void _rpcCall(String functionName, Map<String, dynamic> args, Function(PeerHelper, StreamController<RpcMessage>) returnHandler);

  void _sendEndMessage(PeerHelper peerHelper){
    RpcMessage endMessage = RpcMessage.fromBoolData(true, true, true, peerHelper.requestNumber);
    peerHelper.send(endMessage);
  }

  void _sendError(RpcMessage message, PeerHelper peerHelper){
    RpcMessage errorMessage = rpcErrorMessage(message.isStream, message.requestNum);
    peerHelper.send(errorMessage);
  }
}

abstract class PeerHelper{
  int requestNumber;

  PeerHelper(this.requestNumber);

  void send(RpcMessage message);

  StreamController<RpcMessage>? getRequestHandlerController();

  void addRequestHandlerController(StreamController<RpcMessage> controller);

  void removeRequestHandlerController();
}

/* abstract class RpcNode{
  late Peer peer;
  int requestNumber = 1;
  StreamController<List<dynamic>> controller = StreamController();
  //Map<int, StreamSink<Uint8List>> outgoingHandlerSinks = {};

  Map<List<String>, Function(StreamController<RpcMessage>)> requestHandlers = {
    ["blob", "has"]: (StreamController<RpcMessage> controller) {}
  };
  Map<List<String>, Function> rpcReturnHandlers = {};

  void handleReceivedMessages();

  bool _handleRpcMessage(Map<int, StreamSink<RpcMessage>> handlerSinkMap, RpcMessage message){
    ListEquality listEquality = ListEquality();
    bool errorOccurred = false;
    //Our map looks like:
    //{ 1: sink1,
    //  2: sink2,
    //  -1: sink-1 }

    //Our message has information about the message, so we can obtain the correct sink to send the message to for further processing

    //First, do we have a sink available for the given request number? If so, let's just get it and add the message, job done
    int requestNumber = message.requestNum;
    StreamSink<RpcMessage>? handlerSink = handlerSinkMap[requestNumber];
    //But what if we don't have a sink available? That might be because it's a request that we haven't seen before, so we haven't started handling it. If it's a return, and we don't have a sink available, then we shouldn't have gotten the message in the first place! So we'll need to send an error
    //back
    if(handlerSink == null){
      if(requestNumber > 0){
        //Our message is a request, and we don't have a sink so we haven't started handling it! So let's first get a handler to use it with
        Function(StreamController<RpcMessage>)? handler;
        List<String> requestedProcedureName = message.data["name"];
        requestHandlers.forEach((procedureName, procedureHandler) { 
          if(listEquality.equals(requestedProcedureName, procedureName)){
            handler = procedureHandler;
          }
        });

        //Hopefully, we've got a handler! If not, we're unable to handle the request and we'll need to send back an error
        if(handler != null){
          //We have a handler! Now we need to create a streamcontroller, add the sink to the map, and call the handler with the controller (so it can close the stream). we can then assign the sink to handlerSink to give the message to our  
          StreamController<RpcMessage> controller = StreamController();
          handlerSink = controller.sink;

          handler!(controller);
          handlerSinkMap[requestNumber] = handlerSink;
        }
        else{
          errorOccurred = true;
          //Send an error message back
          //For the server, we'll need a way of being able to choose the client! Probably a map or something like that. We'll need to add a "send" func to the Peer abstract class as well
        }
      }
      else if(requestNumber < 0){
        errorOccurred = true;
        //Our message is a return. We SHOULD have a sink, because we'll have set it up when sending the request! So, we'll have to send an error too
      }
    }

    //The sink might still be null after the above, if there's no handler or we didn't expect the return. If it's not though, we're ready to add the message to the sink for the handler to process
    if((handlerSink != null)){
      handlerSink.add(message);
    }

    return errorOccurred;
  }
}



class _ReturnHandlerEntry{
  String functionType;
  Function(int, StreamController<RpcMessage>) function;

  _ReturnHandlerEntry(this.function, this.functionType);
} */