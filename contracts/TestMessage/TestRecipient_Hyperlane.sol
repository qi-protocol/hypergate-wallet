// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

interface IMessageRecipient {
  function handle(
    uint32 _origin,
    bytes32 _sender,
    bytes calldata _message
  ) external;
}

contract TestRecipient is IMessageRecipient {
  bytes32 public sender;
  bytes public data;
  address public interchainSecurityModule;
  function handle(
    uint32,
    bytes32 _sender,
    bytes calldata _data
  ) external override {
    sender = _sender;
    data = _data;
  }
}