// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import {Vm as vm} from "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";

import {TestCCIPSender} from "contracts/TestMessage/TestCCIPSender_f.sol";
import {TestCCIPReceiver} from "contracts/TestMessage/TestCCIPReceiver_f.sol";

contract Deploy is Test {
    //using UserOperationLib for UserOperation;
    address internal eoaAddress;

    uint256[2] internal publicKey;
    string internal constant SIGNER_1 = "1";

    TestCCIPReceiver testCCIPReceiver;
    address testCCIPReceiverAddress;
    TestCCIPSender testCCIPSender;
    address testCCIPSenderAddress;

    uint256 chainId_1 = 11155111; // origin (sepolia)
    uint256 chainId_2 = 80001; // execution (mubai)

    // UserOperation public userOpBase = UserOperation({
    //     sender: address(0),
    //     nonce: 0,
    //     initCode: new bytes(0),
    //     callData: new bytes(0),
    //     callGasLimit: 10000000,
    //     verificationGasLimit: 20000000,
    //     preVerificationGas: 20000000,
    //     maxFeePerGas: 2,
    //     maxPriorityFeePerGas: 1,
    //     paymasterAndData: new bytes(0),
    //     signature: new bytes(0)
    // });

    function setUp() public {}

    function run() public {
        string memory key = vm.readFile(".secret");
        bytes32 key_bytes = vm.parseBytes32(key);
        uint256 privateKey;
        assembly {
            privateKey := key_bytes
        }
        eoaAddress = vm.addr(privateKey);

        vm.startBroadcast(privateKey);
        testCCIPReceiver = new TestCCIPReceiver();
        testCCIPReceiverAddress = address(testCCIPReceiver);
   
        console.log("All Live EVM:");
        console.log("CCIP Receiver", testCCIPReceiverAddress);
        

        vm.stopBroadcast();
    }

}
