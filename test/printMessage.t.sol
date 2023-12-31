// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";

import {UserOperation, UserOperationLib} from "lib/account-abstraction/contracts/interfaces/UserOperation.sol";
//import {Client} from "lib/ccip-starter-kit-foundry/src/BasicMessageSender.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
//import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import {TestEscrow, Client} from "contracts/TestEscrow.sol";
import {TestPaymaster} from "contracts/TestPaymaster.sol";
import {TestPrint} from "contracts/TestPrint.sol";

import "./createWallet.t.sol";

contract PrintMessageTest is CreateWalletTest {
    using UserOperationLib for UserOperation;
    using ECDSA for bytes32;

    Client.EVM2AnyMessage public baseMessageSent = Client.EVM2AnyMessage({
        receiver: abi.encode(address(0)),
        data: abi.encode(bytes4(0), 0),
        tokenAmounts: new Client.EVMTokenAmount[](0), // no tokens
        extraArgs: "", // no extra
        feeToken: address(0) // always pay in ETH
    });

    Client.Any2EVMMessage public baseMessageReceived = Client.Any2EVMMessage({
        messageId: bytes32(0),
        sourceChainSelector: uint64(0),
        sender: bytes(abi.encode(bytes32(0))), // abi.decode(sender) if comming from an EVM chain
        data: abi.encode(bytes4(0), 0),
        destTokenAmounts: new Client.EVMTokenAmount[](0) // no tokens
    });

    TestEscrow public testEscrow;
    address internal testEscrowAddress;
    TestPaymaster public testPaymaster;
    address internal testPaymasterAddress;
    TestPrint public testPrint;
    address internal testPrintAddress;

    address ccipRouter = address(bytes20(keccak256(abi.encode("ccip router"))));
    address dummyPaymaster = address(bytes20(keccak256(abi.encode("dummy paymaster"))));
    address dummyReceiver = address(bytes20(keccak256(abi.encode("dummy receiver"))));

    uint256 chainId_1 = 123; // origin
    uint256 chainId_2 = 456; // execution

    TestEscrow.PaymasterAndData public basePaymasterAndData = TestEscrow.PaymasterAndData({
        paymaster: address(0),
        chainId: 0,
        asset: address(0),
        owner: address(0),
        amount: 0
    });

    function setUp() public virtual override {
        vm.chainId(chainId_1);
        super.setUp();
        testEscrow = new TestEscrow();
        testEscrowAddress = address(testEscrow);
        testEscrow.addEntryPoint(entryPointAddress, uint64(block.chainid));
        testEscrow.addCCIPAddress(ccipRouter, true);
        testPrint = new TestPrint();
        testPrintAddress = address(testPrint);

        vm.chainId(chainId_2);
        testPaymaster = new TestPaymaster(IEntryPoint(entryPointAddress), address(0), dummyReceiver);
        testPaymasterAddress = address(testPaymaster);
    }

// struct Any2EVMMessage {
//     bytes32 messageId; // MessageId corresponding to ccipSend on source.
//     uint64 sourceChainSelector; // Source chain selector.
//     bytes sender; // abi.decode(sender) if coming from an EVM chain.
//     bytes data; // payload sent in original message.
//     EVMTokenAmount[] destTokenAmounts; // Tokens and their amounts in their destination chain representation.
//   }
    /*
    function printOp(Client.Any2EVMMessage memory message) payable external locked {
        // validate msg.sender is ccip source
        // cast data into userop
        // ignore the rest
        if(!ccipAddress[msg.sender]) {
            revert InvalidCCIPAddress(msg.sender);
        }
        UserOperation calldata userOp = _calldataUserOperation(_decodeUserOperation(message.data));
        PaymasterAndData memory data = _decodePaymasterAndData(userOp.paymasterAndData);

        // authenticate the operation
        bytes32 userOpHash = userOp.hash();
        // need to check safe signature method (maybe ecdsa?)

        if(data.chainId != block.chainid) {
            revert InvalidChain(data.chainId);
        }
        if(data.amount < address(this).balance) {
            revert BalanceError(data.amount, address(this).balance);
        }

        emit PrintUserOp(userOp, data);
    }

    PaymasterAndData {
        address paymaster;
        uint64 chainId;
        address target;
        address owner;
        uint256 amount;
    }
    */

    function testEscrowDeposit() public {
        string memory key = vm.readFile(".secret");
        bytes32 key_bytes = vm.parseBytes32(key);
        uint256 privateKey;
        assembly {
            privateKey := key_bytes
        }

        bytes32 timeHash = testEscrow.hashSeconds(eoaAddress, 3600);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, timeHash.toEthSignedMessageHash());
        bytes memory timeSignature = abi.encodePacked(r, s, v);

        vm.deal(eoaAddress, 10 ether);

        vm.prank(eoaAddress);
        testEscrow.deposit{value: 5 ether}(eoaAddress, address(0), 5 ether);

        require(testEscrowAddress.balance == 5 ether);
        require(testEscrow.getBalance(eoaAddress, address(0)) == 5 ether);
    }

    function testEscrowWithdraw() public {
        vm.chainId(chainId_1);
        string memory key = vm.readFile(".secret");
        bytes32 key_bytes = vm.parseBytes32(key);
        uint256 privateKey;
        assembly {
            privateKey := key_bytes
        }

        vm.deal(eoaAddress, 10 ether);

        vm.prank(eoaAddress);
        testEscrow.deposit{value: 5 ether}(eoaAddress, address(0), 5 ether);

        require(testEscrowAddress.balance == 5 ether);
        require(testEscrow.getBalance(eoaAddress, address(0)) == 5 ether);

        // new withdraw
        testEscrow.withdraw(eoaAddress, address(0), 1 ether);
        require(testEscrowAddress.balance == 4 ether);
        require(testEscrow.getBalance(eoaAddress, address(0)) == 4 ether);
        require(eoaAddress.balance == 6 ether);

        // create lock
        uint256 oldDeadline = testEscrow.getDeadline(eoaAddress);
        bytes32 timeHash = testEscrow.hashSeconds(eoaAddress, 3600);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, timeHash.toEthSignedMessageHash());
        bytes memory timeSignature = abi.encodePacked(r, s, v);
        testEscrow.extendLock(eoaAddress, 3600, timeSignature);
        require(testEscrow.getDeadline(eoaAddress) > oldDeadline);
        
        vm.expectRevert();
        testEscrow.withdraw(eoaAddress, address(0), 1 ether);
    }

    // Implement Test: TestEscrow HandleMessage
    // Implement Test: TestEscrow PrintOp
    // Implement Test: TestEscrow CallPrintOp
    function testEscrowHandleMessage() public {
        vm.chainId(chainId_1);
        string memory key = vm.readFile(".secret");
        bytes32 key_bytes = vm.parseBytes32(key);
        uint256 privateKey;
        assembly {
            privateKey := key_bytes
        }

        vm.deal(eoaAddress, 10 ether);
        vm.prank(eoaAddress);
        testEscrow.deposit{value: 5 ether}(eoaAddress, address(0), 5 ether);
        uint256 oldDeadline = testEscrow.getDeadline(eoaAddress);
        bytes32 timeHash = testEscrow.hashSeconds(eoaAddress, 3600);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, timeHash.toEthSignedMessageHash());
        bytes memory timeSignature = abi.encodePacked(r, s, v);
        testEscrow.extendLock(eoaAddress, 3600, timeSignature);
        console.log("eoadAddress:", eoaAddress);
        console.log("lockTime:", 3600);
        console.log("timeSignature:", vm.toString(abi.encode(timeSignature)));
// 0x7fa9385be102ac3eac297483dd6233d62b3e1496
// 0x435bce917a3a93443ec01b71550afb00d4ecddef574fdb92663d1be122ea3656384b73617fb94788704697059f3405c07780dfefb04e967130c54df2a223db6c1c
// bytes32 hash_ = hashSeconds(account_, seconds_);
//         (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(hash_.toEthSignedMessageHash(), signature_);
//         if (error != ECDSA.RecoverError.NoError) {
//             revert BadSignature();
//         }

//         if(recovered != account_) {
//             revert InvalidSignature(account_, recovered);
//         }
        // baseMessage = Client.EVM2AnyMessage({
        //     receiver: abi.encode(receiver),
        //     data: abi.encode(_selector, data),
        //     tokenAmounts: new Client.EVMTokenAmount[](0), // no tokens
        //     extraArgs: "", // no extra
        //     feeToken: address(0) // always pay in ETH
        // });

        // baseMessageReceived = Client.Any2EVMMessage({
        //     messageId: bytes32(0),
        //     sourceChainSelectory: uint64(0),
        //     sender: bytes(bytes32(0)), // abi.decode(sender) if comming from an EVM chain
        //     data: abi.encode(bytes4(0), 0),
        //     destToknAmounts: new Client.EVMTokenAmount[](0) // no tokens
        // });

        Client.Any2EVMMessage memory messageReceived = baseMessageReceived;

        TestEscrow.PaymasterAndData memory paymasterAndData = basePaymasterAndData;
        paymasterAndData.chainId = uint64(block.chainid);
        paymasterAndData.paymaster = testPaymasterAddress;
        paymasterAndData.amount = 100000000000000;
                            //   5000000000000000000
        paymasterAndData.owner = eoaAddress;

        UserOperation memory userOp = userOpBase;
        userOp.nonce = 240;
        userOp.sender = hypergateWalletAddress;
        userOp.paymasterAndData = abi.encode(paymasterAndData);
        userOp.callData = abi.encodePacked(bytes4(0xb61d27f6),
            bytes32(0x000000000000000000000000c532a74256d3db42d0bf7a0400fefdbad7694008),
            bytes32(0x00000000000000000000000000000000000000000000000000038d7ea4c68000),
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000060),
            bytes32(0x00000000000000000000000000000000000000000000000000000000000000e4),
            bytes32(0x7ff36ab500000000000000000000000000000000000000000000000000000000),
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000000),
            bytes32(0x0000008000000000000000000000000052eb5d94da6146836b0a6c542b69545d),
            bytes32(0xd35fda6d00000000000000000000000000000000000000000000000000000000),
            bytes32(0x669e545500000000000000000000000000000000000000000000000000000000),
            bytes32(0x000000020000000000000000000000007b79995e5f793a07bc00c21412e50eca),
            bytes32(0xe098e7f9000000000000000000000000ae0086b0f700d6d7d4814c4ba1e55d3b),
            bytes32(0xc0dfee0200000000000000000000000000000000000000000000000000000000));
        console.log("data length", userOp.paymasterAndData.length);

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        //console.log("useropHash", vm.toString(userOpHash));
        (v, r, s) = vm.sign(privateKey, userOpHash.toEthSignedMessageHash());
        userOp.signature = abi.encodePacked(r, s, v);

        messageReceived.messageId = bytes32(uint256(1000));
        messageReceived.sourceChainSelector = uint64(bytes8(bytes4(0xb63e800d)));
        messageReceived.sender = abi.encode(bytes32(bytes20(address(this))));
        messageReceived.data = abi.encode(userOp);

        string memory out = vm.toString(abi.encode(messageReceived));
        //console.log(out);
        out = vm.toString(abi.encode(messageReceived.data));
        console.log("chainId", block.chainid);
        console.log("destTokenAmounts", vm.toString(abi.encode(messageReceived.destTokenAmounts)));
        console.log("sender", vm.toString(messageReceived.sender));
        console.log("eoa", eoaAddress);
        console.log("signature", vm.toString(userOp.signature));
        console.log("op length", vm.toString(abi.encode(userOp).length));
        // console.log("msgrop", out);
        // console.log("userop", vm.toString(abi.encode(userOp)));


        vm.prank(ccipRouter);
        testEscrow.printOp(messageReceived);
        // vm.expectEmit();


    }
    
    function testEscrowPrintOp() public {}
    function testEscrowCallPrintOp() public {}
}