// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

/*
struct Any2EVMMessage {
    bytes32 messageId; // MessageId corresponding to ccipSend on source.
    uint64 sourceChainSelector; // Source chain selector.
    bytes sender; // abi.decode(sender) if coming from an EVM chain.
    bytes data; // payload sent in original message.
    EVMTokenAmount[] destTokenAmounts; // Tokens and their amounts in their destination chain representation.
  }

struct EVMTokenAmount {
    address token; // token address on the local chain.
    uint256 amount; // Amount of tokens.
  }
*/

contract TestCCIPReceiver {
    struct EVMTokenAmount {
        address token; // token address on the local chain.
        uint256 amount; // Amount of tokens.
    }

    struct Any2EVMMessage {
        bytes32 messageId; // MessageId corresponding to ccipSend on source.
        uint64 sourceChainSelector; // Source chain selector.
        bytes sender; // abi.decode(sender) if coming from an EVM chain.
        bytes data; // payload sent in original message.
        EVMTokenAmount[] destTokenAmounts; // Tokens and their amounts in their destination chain representation.
    }

    event print(bytes32 messageId, uint64 sourceChainSelector, bytes sender, bytes data, address token, uint256 amount);
    function handleMessage(Any2EVMMessage memory message) public payable {
        emit print(
            message.messageId,
            message.sourceChainSelector,
            message.sender,
            message.data,
            message.destTokenAmounts[0].token,
            message.destTokenAmounts[0].amount
        );
    }
}
