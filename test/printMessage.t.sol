// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import {Vm as vm} from "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";

import {UserOperation, UserOperationLib} from "lib/account-abstraction/contracts/interfaces/UserOperation.sol";
import {Client} from "lib/ccip-starter-kit-foundry/src/BasicMessageSender.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import {TestEscrow} from "contracts/TestEscrow.sol";
import {TestPaymaster} from "contracts/TestPaymaster.sol";
import {TestPrint} from "contracts/TestPrint.sol";

contract PrintMessageTest is Test {
    using UserOperationLib for UserOperation;

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

    TestEscrow public testEscrow;
    address internal testEscrowAddress;
    TestPaymaster public testPaymaster;
    address internal testPaymasterAddress;
    TestPrint public testPrint;
    address internal testPrintAddress;

    function setUp() public {
        testEscrow = new TestEscrow();
        testEscrowAddress = address(testEscrow);
        testPaymaster = new TestPaymaster();
        testPaymasterAddress = address(testPaymaster);
        testPrint = new TestPrint();
        testPrintAddress = address(testPrint);
    }
}