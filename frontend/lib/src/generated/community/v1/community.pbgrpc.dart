// This is a generated file - do not edit.
//
// Generated from community/v1/community.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'community.pb.dart' as $0;

export 'community.pb.dart';

@$pb.GrpcServiceName('community.v1.CommunityService')
class CommunityServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  CommunityServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.User> createUser(
    $0.CreateUserRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createUser, request, options: options);
  }

  $grpc.ResponseFuture<$0.User> getUser(
    $0.GetUserRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getUser, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListUsersResponse> listUsers(
    $0.ListUsersRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listUsers, request, options: options);
  }

  $grpc.ResponseFuture<$0.Channel> createChannel(
    $0.CreateChannelRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createChannel, request, options: options);
  }

  $grpc.ResponseFuture<$0.Channel> getChannel(
    $0.GetChannelRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getChannel, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListChannelsResponse> listChannels(
    $0.ListChannelsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listChannels, request, options: options);
  }

  $grpc.ResponseFuture<$0.JoinChannelResponse> joinChannel(
    $0.JoinChannelRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$joinChannel, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListMyChannelsResponse> listMyChannels(
    $0.ListMyChannelsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listMyChannels, request, options: options);
  }

  /// Única llamada entre servicios: la usa message-service antes de guardar un mensaje.
  $grpc.ResponseFuture<$0.IsMemberResponse> isMember(
    $0.IsMemberRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$isMember, request, options: options);
  }

  // method descriptors

  static final _$createUser = $grpc.ClientMethod<$0.CreateUserRequest, $0.User>(
      '/community.v1.CommunityService/CreateUser',
      ($0.CreateUserRequest value) => value.writeToBuffer(),
      $0.User.fromBuffer);
  static final _$getUser = $grpc.ClientMethod<$0.GetUserRequest, $0.User>(
      '/community.v1.CommunityService/GetUser',
      ($0.GetUserRequest value) => value.writeToBuffer(),
      $0.User.fromBuffer);
  static final _$listUsers =
      $grpc.ClientMethod<$0.ListUsersRequest, $0.ListUsersResponse>(
          '/community.v1.CommunityService/ListUsers',
          ($0.ListUsersRequest value) => value.writeToBuffer(),
          $0.ListUsersResponse.fromBuffer);
  static final _$createChannel =
      $grpc.ClientMethod<$0.CreateChannelRequest, $0.Channel>(
          '/community.v1.CommunityService/CreateChannel',
          ($0.CreateChannelRequest value) => value.writeToBuffer(),
          $0.Channel.fromBuffer);
  static final _$getChannel =
      $grpc.ClientMethod<$0.GetChannelRequest, $0.Channel>(
          '/community.v1.CommunityService/GetChannel',
          ($0.GetChannelRequest value) => value.writeToBuffer(),
          $0.Channel.fromBuffer);
  static final _$listChannels =
      $grpc.ClientMethod<$0.ListChannelsRequest, $0.ListChannelsResponse>(
          '/community.v1.CommunityService/ListChannels',
          ($0.ListChannelsRequest value) => value.writeToBuffer(),
          $0.ListChannelsResponse.fromBuffer);
  static final _$joinChannel =
      $grpc.ClientMethod<$0.JoinChannelRequest, $0.JoinChannelResponse>(
          '/community.v1.CommunityService/JoinChannel',
          ($0.JoinChannelRequest value) => value.writeToBuffer(),
          $0.JoinChannelResponse.fromBuffer);
  static final _$listMyChannels =
      $grpc.ClientMethod<$0.ListMyChannelsRequest, $0.ListMyChannelsResponse>(
          '/community.v1.CommunityService/ListMyChannels',
          ($0.ListMyChannelsRequest value) => value.writeToBuffer(),
          $0.ListMyChannelsResponse.fromBuffer);
  static final _$isMember =
      $grpc.ClientMethod<$0.IsMemberRequest, $0.IsMemberResponse>(
          '/community.v1.CommunityService/IsMember',
          ($0.IsMemberRequest value) => value.writeToBuffer(),
          $0.IsMemberResponse.fromBuffer);
}

@$pb.GrpcServiceName('community.v1.CommunityService')
abstract class CommunityServiceBase extends $grpc.Service {
  $core.String get $name => 'community.v1.CommunityService';

  CommunityServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateUserRequest, $0.User>(
        'CreateUser',
        createUser_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CreateUserRequest.fromBuffer(value),
        ($0.User value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetUserRequest, $0.User>(
        'GetUser',
        getUser_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetUserRequest.fromBuffer(value),
        ($0.User value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListUsersRequest, $0.ListUsersResponse>(
        'ListUsers',
        listUsers_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListUsersRequest.fromBuffer(value),
        ($0.ListUsersResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CreateChannelRequest, $0.Channel>(
        'CreateChannel',
        createChannel_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CreateChannelRequest.fromBuffer(value),
        ($0.Channel value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetChannelRequest, $0.Channel>(
        'GetChannel',
        getChannel_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetChannelRequest.fromBuffer(value),
        ($0.Channel value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListChannelsRequest, $0.ListChannelsResponse>(
            'ListChannels',
            listChannels_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListChannelsRequest.fromBuffer(value),
            ($0.ListChannelsResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.JoinChannelRequest, $0.JoinChannelResponse>(
            'JoinChannel',
            joinChannel_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.JoinChannelRequest.fromBuffer(value),
            ($0.JoinChannelResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListMyChannelsRequest,
            $0.ListMyChannelsResponse>(
        'ListMyChannels',
        listMyChannels_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ListMyChannelsRequest.fromBuffer(value),
        ($0.ListMyChannelsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.IsMemberRequest, $0.IsMemberResponse>(
        'IsMember',
        isMember_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.IsMemberRequest.fromBuffer(value),
        ($0.IsMemberResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.User> createUser_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateUserRequest> $request) async {
    return createUser($call, await $request);
  }

  $async.Future<$0.User> createUser(
      $grpc.ServiceCall call, $0.CreateUserRequest request);

  $async.Future<$0.User> getUser_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetUserRequest> $request) async {
    return getUser($call, await $request);
  }

  $async.Future<$0.User> getUser(
      $grpc.ServiceCall call, $0.GetUserRequest request);

  $async.Future<$0.ListUsersResponse> listUsers_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListUsersRequest> $request) async {
    return listUsers($call, await $request);
  }

  $async.Future<$0.ListUsersResponse> listUsers(
      $grpc.ServiceCall call, $0.ListUsersRequest request);

  $async.Future<$0.Channel> createChannel_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateChannelRequest> $request) async {
    return createChannel($call, await $request);
  }

  $async.Future<$0.Channel> createChannel(
      $grpc.ServiceCall call, $0.CreateChannelRequest request);

  $async.Future<$0.Channel> getChannel_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetChannelRequest> $request) async {
    return getChannel($call, await $request);
  }

  $async.Future<$0.Channel> getChannel(
      $grpc.ServiceCall call, $0.GetChannelRequest request);

  $async.Future<$0.ListChannelsResponse> listChannels_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListChannelsRequest> $request) async {
    return listChannels($call, await $request);
  }

  $async.Future<$0.ListChannelsResponse> listChannels(
      $grpc.ServiceCall call, $0.ListChannelsRequest request);

  $async.Future<$0.JoinChannelResponse> joinChannel_Pre($grpc.ServiceCall $call,
      $async.Future<$0.JoinChannelRequest> $request) async {
    return joinChannel($call, await $request);
  }

  $async.Future<$0.JoinChannelResponse> joinChannel(
      $grpc.ServiceCall call, $0.JoinChannelRequest request);

  $async.Future<$0.ListMyChannelsResponse> listMyChannels_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListMyChannelsRequest> $request) async {
    return listMyChannels($call, await $request);
  }

  $async.Future<$0.ListMyChannelsResponse> listMyChannels(
      $grpc.ServiceCall call, $0.ListMyChannelsRequest request);

  $async.Future<$0.IsMemberResponse> isMember_Pre($grpc.ServiceCall $call,
      $async.Future<$0.IsMemberRequest> $request) async {
    return isMember($call, await $request);
  }

  $async.Future<$0.IsMemberResponse> isMember(
      $grpc.ServiceCall call, $0.IsMemberRequest request);
}
