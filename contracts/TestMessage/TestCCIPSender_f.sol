// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

struct EVMTokenAmount {
        address token; // token address on the local chain.
        uint256 amount; // Amount of tokens.
}

struct EVM2AnyMessage {
    bytes receiver; // abi.encode(receiver address) for dest EVM chains
    bytes data; // Data payload
    EVMTokenAmount[] tokenAmounts; // Token transfers
    address feeToken; // Address of feeToken. address(0) means you will send msg.value.
    bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV1)
}

interface IRouterClient {
  error UnsupportedDestinationChain(uint64 destChainSelector);
  error InsufficientFeeTokenAmount();
  error InvalidMsgValue();

  /// @notice Checks if the given chain ID is supported for sending/receiving.
  /// @param chainSelector The chain to check.
  /// @return supported is true if it is supported, false if not.
  function isChainSupported(uint64 chainSelector) external view returns (bool supported);

  /// @notice Gets a list of all supported tokens which can be sent or received
  /// to/from a given chain id.
  /// @param chainSelector The chainSelector.
  /// @return tokens The addresses of all tokens that are supported.
  function getSupportedTokens(uint64 chainSelector) external view returns (address[] memory tokens);

  /// @param destinationChainSelector The destination chainSelector
  /// @param message The cross-chain CCIP message including data and/or tokens
  /// @return fee returns guaranteed execution fee for the specified message
  /// delivery to destination chain
  /// @dev returns 0 fee on invalid message.
  function getFee(
    uint64 destinationChainSelector,
    EVM2AnyMessage memory message
  ) external view returns (uint256 fee);

  /// @notice Request a message to be sent to the destination chain
  /// @param destinationChainSelector The destination chain ID
  /// @param message The cross-chain CCIP message including data and/or tokens
  /// @return messageId The message ID
  /// @dev Note if msg.value is larger than the required fee (from getFee) we accept
  /// the overpayment with no refund.
  function ccipSend(
    uint64 destinationChainSelector,
    EVM2AnyMessage calldata message
  ) external payable returns (bytes32);
}

contract TestCCIPSender {
    function getFee(
        address receiver, 
        address ccip_router, 
        uint64 destinationChainSelector,
        bytes4 _selector
    ) public payable returns(uint256 fee_) {
        bytes memory userOp = abi.encode(bytes4(0x55555555));
        bytes memory data = abi.encode(userOp, receiver);

        EVM2AnyMessage memory message = EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(_selector, data),
            tokenAmounts: new EVMTokenAmount[](0), // no tokens
            extraArgs: "", // no extra
            feeToken: address(0) // always pay in ETH
        });

        fee_ = IRouterClient(ccip_router).getFee(
            destinationChainSelector,
            message
        );
    }

    function sendMessage(
        address receiver, 
        address ccip_router, 
        uint64 destinationChainSelector,
        bytes4 _selector
    ) public payable {
        bytes memory userOp = abi.encode(bytes4(0x55555555));
        bytes memory data = abi.encode(userOp, receiver);

        EVM2AnyMessage memory message = EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(_selector, data),
            tokenAmounts: new EVMTokenAmount[](0), // no tokens
            extraArgs: "", // no extra
            feeToken: address(0) // always pay in ETH
        });

        uint256 fee = IRouterClient(ccip_router).getFee(
            destinationChainSelector,
            message
        );

        bytes32 messageId = IRouterClient(ccip_router).ccipSend{value: fee+msg.value}(
            destinationChainSelector,
            message
        );

        emit MessageSent(messageId);
    } //16015286601757825753

    event MessageSent(bytes32 messageId);
}
