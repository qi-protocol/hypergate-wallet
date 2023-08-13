// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import {UserOperation, UserOperationLib} from "lib/account-abstraction/contracts/interfaces/UserOperation.sol";

contract TestPrint {
    using UserOperationLib for UserOperation;

    struct PaymasterAndData {
        address paymaster;
        uint64 chainId;
        address target;
        address owner;
        uint256 amount;
    }

    function _decodePaymasterAndData(bytes memory data) internal pure returns (PaymasterAndData memory) {
        require(data.length == 104, "Invalid data length"); // 20 + 8 + 20 + 20 + 32 = 100 bytes

        PaymasterAndData memory result;
        address paymaster;
        uint64 chainId;
        address target;
        address owner;
        uint256 amount;

        uint256 len = data.length;
        bytes memory dataCopy = new bytes(len);
        assembly {
            calldatacopy(add(dataCopy, 0x20), 0, len) // Copy calldata to memory

            paymaster := mload(add(dataCopy, 0x20))
            chainId := mload(add(dataCopy, 0x34))
            target := mload(add(dataCopy, 0x40))
            owner := mload(add(dataCopy, 0x60))
            amount := mload(add(dataCopy, 0x80))
        }

        result.paymaster = paymaster;
        result.chainId = chainId;
        result.target = target;
        result.owner = owner;
        result.amount = amount;

        return result;
    }
    
    function printOp(UserOperation calldata userOp) payable external {
        PaymasterAndData memory paymasterAndData = _decodePaymasterAndData(userOp.paymasterAndData);
        emit PrintUserOp(userOp, paymasterAndData);
    }

    event PrintUserOp(UserOperation userOp, PaymasterAndData paymasterAndData);

    fallback() external payable {}
}