// This is a generated file - do not edit.
//
// Generated from community/v1/community.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use userDescriptor instead')
const User$json = {
  '1': 'User',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'username', '3': 2, '4': 1, '5': 9, '10': 'username'},
    {'1': 'email', '3': 3, '4': 1, '5': 9, '10': 'email'},
    {
      '1': 'created_at_unix_ms',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'createdAtUnixMs'
    },
  ],
};

/// Descriptor for `User`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userDescriptor = $convert.base64Decode(
    'CgRVc2VyEhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIaCgh1c2VybmFtZRgCIAEoCVIIdXNlcm'
    '5hbWUSFAoFZW1haWwYAyABKAlSBWVtYWlsEisKEmNyZWF0ZWRfYXRfdW5peF9tcxgEIAEoA1IP'
    'Y3JlYXRlZEF0VW5peE1z');

@$core.Deprecated('Use createUserRequestDescriptor instead')
const CreateUserRequest$json = {
  '1': 'CreateUserRequest',
  '2': [
    {'1': 'username', '3': 1, '4': 1, '5': 9, '10': 'username'},
    {'1': 'email', '3': 2, '4': 1, '5': 9, '10': 'email'},
  ],
};

/// Descriptor for `CreateUserRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createUserRequestDescriptor = $convert.base64Decode(
    'ChFDcmVhdGVVc2VyUmVxdWVzdBIaCgh1c2VybmFtZRgBIAEoCVIIdXNlcm5hbWUSFAoFZW1haW'
    'wYAiABKAlSBWVtYWls');

@$core.Deprecated('Use getUserRequestDescriptor instead')
const GetUserRequest$json = {
  '1': 'GetUserRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `GetUserRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getUserRequestDescriptor = $convert
    .base64Decode('Cg5HZXRVc2VyUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQ=');

@$core.Deprecated('Use listUsersRequestDescriptor instead')
const ListUsersRequest$json = {
  '1': 'ListUsersRequest',
};

/// Descriptor for `ListUsersRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listUsersRequestDescriptor =
    $convert.base64Decode('ChBMaXN0VXNlcnNSZXF1ZXN0');

@$core.Deprecated('Use listUsersResponseDescriptor instead')
const ListUsersResponse$json = {
  '1': 'ListUsersResponse',
  '2': [
    {
      '1': 'users',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.community.v1.User',
      '10': 'users'
    },
  ],
};

/// Descriptor for `ListUsersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listUsersResponseDescriptor = $convert.base64Decode(
    'ChFMaXN0VXNlcnNSZXNwb25zZRIoCgV1c2VycxgBIAMoCzISLmNvbW11bml0eS52MS5Vc2VyUg'
    'V1c2Vycw==');

@$core.Deprecated('Use channelDescriptor instead')
const Channel$json = {
  '1': 'Channel',
  '2': [
    {'1': 'channel_id', '3': 1, '4': 1, '5': 9, '10': 'channelId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'created_by', '3': 4, '4': 1, '5': 9, '10': 'createdBy'},
    {
      '1': 'created_at_unix_ms',
      '3': 5,
      '4': 1,
      '5': 3,
      '10': 'createdAtUnixMs'
    },
  ],
};

/// Descriptor for `Channel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List channelDescriptor = $convert.base64Decode(
    'CgdDaGFubmVsEh0KCmNoYW5uZWxfaWQYASABKAlSCWNoYW5uZWxJZBISCgRuYW1lGAIgASgJUg'
    'RuYW1lEiAKC2Rlc2NyaXB0aW9uGAMgASgJUgtkZXNjcmlwdGlvbhIdCgpjcmVhdGVkX2J5GAQg'
    'ASgJUgljcmVhdGVkQnkSKwoSY3JlYXRlZF9hdF91bml4X21zGAUgASgDUg9jcmVhdGVkQXRVbm'
    'l4TXM=');

@$core.Deprecated('Use createChannelRequestDescriptor instead')
const CreateChannelRequest$json = {
  '1': 'CreateChannelRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 2, '4': 1, '5': 9, '10': 'description'},
    {'1': 'created_by', '3': 3, '4': 1, '5': 9, '10': 'createdBy'},
  ],
};

/// Descriptor for `CreateChannelRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createChannelRequestDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVDaGFubmVsUmVxdWVzdBISCgRuYW1lGAEgASgJUgRuYW1lEiAKC2Rlc2NyaXB0aW'
    '9uGAIgASgJUgtkZXNjcmlwdGlvbhIdCgpjcmVhdGVkX2J5GAMgASgJUgljcmVhdGVkQnk=');

@$core.Deprecated('Use getChannelRequestDescriptor instead')
const GetChannelRequest$json = {
  '1': 'GetChannelRequest',
  '2': [
    {'1': 'channel_id', '3': 1, '4': 1, '5': 9, '10': 'channelId'},
  ],
};

/// Descriptor for `GetChannelRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getChannelRequestDescriptor = $convert.base64Decode(
    'ChFHZXRDaGFubmVsUmVxdWVzdBIdCgpjaGFubmVsX2lkGAEgASgJUgljaGFubmVsSWQ=');

@$core.Deprecated('Use listChannelsRequestDescriptor instead')
const ListChannelsRequest$json = {
  '1': 'ListChannelsRequest',
};

/// Descriptor for `ListChannelsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listChannelsRequestDescriptor =
    $convert.base64Decode('ChNMaXN0Q2hhbm5lbHNSZXF1ZXN0');

@$core.Deprecated('Use listChannelsResponseDescriptor instead')
const ListChannelsResponse$json = {
  '1': 'ListChannelsResponse',
  '2': [
    {
      '1': 'channels',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.community.v1.Channel',
      '10': 'channels'
    },
  ],
};

/// Descriptor for `ListChannelsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listChannelsResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0Q2hhbm5lbHNSZXNwb25zZRIxCghjaGFubmVscxgBIAMoCzIVLmNvbW11bml0eS52MS'
    '5DaGFubmVsUghjaGFubmVscw==');

@$core.Deprecated('Use joinChannelRequestDescriptor instead')
const JoinChannelRequest$json = {
  '1': 'JoinChannelRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'channel_id', '3': 2, '4': 1, '5': 9, '10': 'channelId'},
  ],
};

/// Descriptor for `JoinChannelRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinChannelRequestDescriptor = $convert.base64Decode(
    'ChJKb2luQ2hhbm5lbFJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEh0KCmNoYW5uZW'
    'xfaWQYAiABKAlSCWNoYW5uZWxJZA==');

@$core.Deprecated('Use joinChannelResponseDescriptor instead')
const JoinChannelResponse$json = {
  '1': 'JoinChannelResponse',
  '2': [
    {'1': 'joined', '3': 1, '4': 1, '5': 8, '10': 'joined'},
  ],
};

/// Descriptor for `JoinChannelResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinChannelResponseDescriptor =
    $convert.base64Decode(
        'ChNKb2luQ2hhbm5lbFJlc3BvbnNlEhYKBmpvaW5lZBgBIAEoCFIGam9pbmVk');

@$core.Deprecated('Use listMyChannelsRequestDescriptor instead')
const ListMyChannelsRequest$json = {
  '1': 'ListMyChannelsRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `ListMyChannelsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listMyChannelsRequestDescriptor =
    $convert.base64Decode(
        'ChVMaXN0TXlDaGFubmVsc1JlcXVlc3QSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklk');

@$core.Deprecated('Use listMyChannelsResponseDescriptor instead')
const ListMyChannelsResponse$json = {
  '1': 'ListMyChannelsResponse',
  '2': [
    {
      '1': 'channels',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.community.v1.Channel',
      '10': 'channels'
    },
  ],
};

/// Descriptor for `ListMyChannelsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listMyChannelsResponseDescriptor =
    $convert.base64Decode(
        'ChZMaXN0TXlDaGFubmVsc1Jlc3BvbnNlEjEKCGNoYW5uZWxzGAEgAygLMhUuY29tbXVuaXR5Ln'
        'YxLkNoYW5uZWxSCGNoYW5uZWxz');

@$core.Deprecated('Use isMemberRequestDescriptor instead')
const IsMemberRequest$json = {
  '1': 'IsMemberRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'channel_id', '3': 2, '4': 1, '5': 9, '10': 'channelId'},
  ],
};

/// Descriptor for `IsMemberRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List isMemberRequestDescriptor = $convert.base64Decode(
    'Cg9Jc01lbWJlclJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEh0KCmNoYW5uZWxfaW'
    'QYAiABKAlSCWNoYW5uZWxJZA==');

@$core.Deprecated('Use isMemberResponseDescriptor instead')
const IsMemberResponse$json = {
  '1': 'IsMemberResponse',
  '2': [
    {'1': 'is_member', '3': 1, '4': 1, '5': 8, '10': 'isMember'},
    {'1': 'username', '3': 2, '4': 1, '5': 9, '10': 'username'},
  ],
};

/// Descriptor for `IsMemberResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List isMemberResponseDescriptor = $convert.base64Decode(
    'ChBJc01lbWJlclJlc3BvbnNlEhsKCWlzX21lbWJlchgBIAEoCFIIaXNNZW1iZXISGgoIdXNlcm'
    '5hbWUYAiABKAlSCHVzZXJuYW1l');
