// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

// needs to recieve a message from ccip (UserOp, PaymasterAddress)
// then release locked funds
// deserialize PaymasterAndData (paymaster, chainid, target, owner, amount)
// chainid == block.chainid
// validateSignature == owner
// transfer amount to paymaster 

// contracts
// TestPaymaster(IEntryPoint(owner)) L1
//      call validateSignature
//      call validatePaymasterUserOp
/*
        uint256 gas = verificationGasLimit - gasUsedByValidateAccountPrepayment;
            address paymaster = mUserOp.paymaster;
            DepositInfo storage paymasterInfo = deposits[paymaster];
            uint256 deposit = paymasterInfo.deposit;
            if (deposit < requiredPreFund) {
                revert FailedOp(opIndex, "AA31 paymaster deposit too low");
            }
            paymasterInfo.deposit = uint112(deposit - requiredPreFund);
            try IPaymaster(paymaster).validatePaymasterUserOp{gas : gas}(op, opInfo.userOpHash, requiredPreFund) returns (bytes memory _context, uint256 _validationData){
                context = _context;
                validationData = _validationData;
            }
    the above implies verificationGasLimit - gasUsedByValidateAccountPrepayment = gas
    is the gas that will be used for the execution of the crosschain call

    Execution conditions:
    - paymasterAndData >= 20 bytes
    - enough gas
    - sufficent deposited ETH on the paymaster
        checked via _getValidationData(paymasterValidationData)
    - 
*/

// TestEscrow
// TestEntryPoint
// PrintUserOp
// Have TestEscrow print out userop
// Have TestEscrow call TestEntrypoint
//      which will call contract PrintUserOp