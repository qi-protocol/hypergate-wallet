//SPDX-License-Identifier: MIT
pragma solidity^0.8.19;

contract Handler {
    struct Escrow {
        address escrowAddress;
        bytes4 selector;
    } // really use mapping to bytes24
    mapping(address => bytes24) EscrowData;
    // if sender = messenger -> do selector
    function _hyperlane() {
        uint32 _origin,
    bytes32 _sender,
    bytes calldata _message
    }
    
    fallback() external payable {
        // for test print out 
        // print out origin and msg.sender
        address targetEscrow = 
        bytes memory payload_;
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0x4, sub(calldatasize(), 0x4))
            mstore(payload_, mload(ptr))
            pop(call(gas(), address(), 0, add(payload_, 0x20), mload(payload_), 0, 0))
        }
    }
}

// don't quote shit, just take bribe + gas