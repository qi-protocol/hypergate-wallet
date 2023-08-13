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

    function PrintOp(UserOperation calldata userOp) payable external {
        PaymasterAndData paymasterAndData = PaymasterAndData(op.paymasterAndData);
        emit PrintUserOp(userOp, paymasterAndData);
    }

    event PrintUserOp(UserOperation userOp, PaymasterAndData paymasterAndData);

    fallback() external payable {}
}