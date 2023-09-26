// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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

    constructor() payable {}

    event print(bytes32 messageId, uint64 sourceChainSelector, bytes sender, bytes data);
    function handleMessage(Any2EVMMessage memory message) public payable {
        emit print(
            message.messageId,
            message.sourceChainSelector,
            message.sender,
            message.data
        );
    }

    receive() external payable {}
}
