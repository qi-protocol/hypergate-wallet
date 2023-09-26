// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {IMailbox, IIGP, TestPaymaster, IEntryPoint} from "flat/TestPaymaster2_f.sol";
import "contracts/interfaces/ITestEscrow.sol";

/**
What I need
- Paymaster needs to be deployed
- The paymaster need to have BOTH deposited and staked funds in the EntryPoint
- Test is paymaster works locally with normal transactions
- Escrow test already works
- Test Hyperlane live transactions (easier since hyperlane Mumbai/sepolia doesn’t need payment)
- If all works, make it reproducible with instructions
- Make a video of stepping though the process
- Post video to my YouTube and share it (less than 3 mins)
 */

 contract PaymasterTest {
    IEntryPoint entryPoint;
    address entryPointAddress;
    ISimpleAccountFactory simpleAccountFactory;
    address simpleAccountFactoryAddress;
    ISimpleAccount simpleAccount;
    address simpleAccountAddress;
    TestPaymaster testPaymaster;
    address testPaymasterAddress;
    TestEscrow testEscrow;
    address testEscrowAddress;

    uint256 internal constant SALT = 0x55;

    UserOperation public userOpBase = UserOperation({
        sender: address(0),
        nonce: 0,
        initCode: new bytes(0),
        callData: new bytes(0),
        callGasLimit: 10000000,
        verificationGasLimit: 20000000,
        preVerificationGas: 20000000,
        maxFeePerGas: 2,
        maxPriorityFeePerGas: 1,
        paymasterAndData: new bytes(0),
        signature: new bytes(0)
    });

    PaymasterAndData public paymasterAndDataBase = PaymasterAndData({
        paymaster: address(0),
        chainId: uint256(0),
        asset: address(0),
        owner: address(0),
        amount: uint256(0)
    });

    PaymasterAndData public paymasterAndDataBase2 = PaymasterAndData2({
        paymaster: address(0),
        chainId: uint256(0),
        asset: address(0),
        owner: address(0),
        amount: uint256(0)
    });

    function setup() public {
        // needs to create entrypoint
        //
    }

    function testPaymaster() public {}
 }