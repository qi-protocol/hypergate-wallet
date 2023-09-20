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

    function testDo() public {
        string memory key = vm.readFile(".secret");
        bytes32 key_bytes = vm.parseBytes32(key);
        uint256 privateKey;
        assembly {
            privateKey := key_bytes
        }
        eoaAddress = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        // vm.chainId(chainId_2);
        // testCCIPSender = new TestCCIPSender();
        // testCCIPSenderAddress = address(testCCIPSender);

        // vm.chainId(chainId_1);
        // testCCIPReceiver = new TestCCIPReceiver();
        // testCCIPReceiverAddress = address(testCCIPReceiver);

        testCCIPReceiverAddress = 0x199A199B680E61980d3DFB0c6D46754CF23Efb6f;
        testCCIPSenderAddress = 0x8F82ece0Ee8242Ca9AC4Af8963cd5238E13eFa37;

        vm.chainId(chainId_2);
        address receiver = testCCIPReceiverAddress;
        address ccip_router = 0xD0daae2231E9CB96b94C8512223533293C3693Bf;
        uint64 destinationChainSelector = uint64(12532609583862916517);
        bytes4 _selector = bytes4(0x8509636d);

        console.log("All Live EVM:");
        console.log("ChainId execute:", chainId_1);
        console.log("ChainId origin:", chainId_2);
        console.log("EOA: ", eoaAddress);
        console.log("CCIP Sender:", testCCIPSenderAddress);
        console.log("CCIP Receiver", testCCIPReceiverAddress);

        console.log("CCIP Router:", 0xD0daae2231E9CB96b94C8512223533293C3693Bf);
        console.log("destinationChainSelector:", 12532609583862916517);
        console.log("_selector:", "0x8509636d");

        uint256 fee_ = testCCIPSender.getFee(
            receiver,
            ccip_router,
            destinationChainSelector,
            _selector
        );

        console.log("fee_:", fee_);

        testCCIPSender.sendMessage{value: fee_ + 10000}(receiver, ccip_router, destinationChainSelector, _selector);
        // destinationChainSelector (mumbai) = 12532609583862916517
        // send = 0xdab286fe
        // getFee = 0x9a7a7ed2
        // handleMessage = 0x8509636d
        // router (sepolia) = 0xD0daae2231E9CB96b94C8512223533293C3693Bf
        // router (mumbai) = ?
        //
/**
    function sendMessage(
        address receiver, 
        address ccip_router, 
        uint64 destinationChainSelector,
        bytes4 _selector
    ) public payable {
        bytes memory userOp = abi.encode(bytes4(0x55555555));
        bytes memory data = abi.encode(userOp, receiver);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(_selector, data),
            tokenAmounts: new Client.EVMTokenAmount[](0), // no tokens
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
    } 
 */
   
        
        
        

        vm.stopBroadcast();
    }

}

// TestCCIPReceiverAddress = 0x199A199B680E61980d3DFB0c6D46754CF23Efb6f
// TestCCIPSenderAddress = 0x8F82ece0Ee8242Ca9AC4Af8963cd5238E13eFa37

["0x000000000000000000000000199a199b680e61980d3dfb0c6d46754cf23efb6f","0x8509636d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000040000000000000000000000000199a199b680e61980d3dfb0c6d46754cf23efb6f00000000000000000000000000000000000000000000000000000000000000205555555500000000000000000000000000000000000000000000000000000000",[],"0x0000000000000000000000000000000000000000","0x"]