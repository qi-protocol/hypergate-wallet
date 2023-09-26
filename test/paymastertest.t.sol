// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

//import {IMailbox, IIGP, TestPaymaster, IEntryPoint} from "flat/TestPaymaster2_f.sol";
//import "contracts/interfaces/ITestEscrow.sol";

import {LoadKey} from "test/base/loadkey.t.sol";

import {IEntryPoint, EntryPoint, IAccount} from "@4337/core/EntryPoint.sol";
import {SimpleAccount, SimpleAccountFactory} from "@4337/samples/SimpleAccountFactory.sol";
import {TestPaymaster} from "contracts/TestPaymaster.sol";
import {TestEscrow} from "contracts/TestEscrow.sol";
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

 contract PaymasterTest is LoadKey {
    IEntryPoint entryPoint_;
    address entryPointAddress;
    SimpleAccountFactory simpleAccountFactory_;
    address simpleAccountFactoryAddress;
    SimpleAccount simpleAccount_;
    address simpleAccountAddress;
    TestPaymaster testPaymaster_;
    address testPaymasterAddress;
    TestEscrow testEscrow_;
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

    PaymasterAndData public paymasterAndDataBase = PaymasterAndData({ // need to fix paymasterAndData ordering
        paymaster: address(0),
        owner: address(0),
        chainId: uint256(0),
        asset: address(0),
        amount: uint256(0)
    });

    PaymasterAndData2 public paymasterAndDataBase2 = PaymasterAndData2({
        paymaster: address(0),
        owner: address(0),
        chainId: uint256(0),
        paymentAsset: address(0),
        paymentAmount: uint256(0),
        transferAsset: address(0),
        transferAmount: uint256(0)
    });

    function setup() public virtual override {
        super.setup();

        entryPoint_ = new EntryPoint();
        entryPointAddress = address(entryPoint_);

        simpleAccountFactory_ = new SimpleAccountFactory()


        //
    }

    function testPaymaster() public {}

    // test the execution of assets moving from paymaster to be used by the AA account
    function testPaymaster2() public {}
 }