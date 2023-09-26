// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

//import {IMailbox, IIGP, TestPaymaster, IEntryPoint} from "flat/TestPaymaster2_f.sol";
//import "contracts/interfaces/ITestEscrow.sol";
import "forge-std/console.sol";

import {LoadKey} from "test/base/loadkey.t.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint, EntryPoint, IAccount, UserOperation, UserOperationLib} from "@4337/core/entryPoint.sol";
import {SimpleAccount, SimpleAccountFactory} from "@4337/samples/SimpleAccountFactory.sol";
import {TestPaymaster, IMailbox, IIGP} from "contracts/TestPaymaster2.sol";
import {TestEscrow} from "contracts/TestEscrow2.sol";
import {PaymasterAndData, PaymasterAndData2} from "contracts/interfaces/ITestEscrow.sol";
import {HyperlaneMailbox} from "contracts/test/HyperlaneMailbox.sol";
import {HyperlaneIGP} from "contracts/test/HyperlaneIGP.sol"; 
import {ERC20} from "contracts/test/ERC20.sol";

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
    using ECDSA for bytes32;
    using UserOperationLib for UserOperation;

    IEntryPoint entryPoint_;
    address entryPointAddress;
    SimpleAccountFactory simpleAccountFactory_;
    address simpleAccountFactoryAddress;
    SimpleAccount simpleAccount_;
    address simpleAccountAddress;
    TestPaymaster _testPaymaster;
    address testPaymasterAddress;
    TestEscrow _testEscrow;
    address testEscrowAddress;
    HyperlaneMailbox _hyperlaneMailbox;
    address hyperlaneMailboxAddress;
    HyperlaneIGP _hyperlaneIGP;
    address hyperlaneIGPAddress;
    ERC20 _ERC20;
    address ERC20Address;

    uint256 internal constant SALT = 0x55;

    address internal constant RECEIVER = address(bytes20(bytes32(keccak256("defaultReceiver"))));

    address internal constant BUNDLER = address(bytes20(bytes32(keccak256("defaultBundler"))));

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

    function setUp() public virtual override {
        super.setUp();
        uint256 gas;

        _ERC20 = new ERC20("Test Token", "TKN");
        ERC20Address = address(_ERC20);

        entryPoint_ = new EntryPoint();
        entryPointAddress = address(entryPoint_);

        simpleAccountFactory_ = new SimpleAccountFactory(IEntryPoint(entryPointAddress));
        UserOperation memory userOp = userOpBase;

        _hyperlaneMailbox = new HyperlaneMailbox(uint32(block.chainid));
        hyperlaneMailboxAddress = address(_hyperlaneMailbox);
        _hyperlaneIGP = new HyperlaneIGP(hyperlaneMailboxAddress);
        hyperlaneIGPAddress = address(_hyperlaneIGP);

        _testPaymaster = new TestPaymaster(
            IEntryPoint(entryPointAddress),//IEntryPoint entryPoint_, 
            hyperlaneMailboxAddress,//address hyperlane_mailbox_, 
            hyperlaneIGPAddress,//address hyperlane_igp_,
            RECEIVER//address defaultReceiver_
        );
        testPaymasterAddress = address(_testPaymaster);
        _testPaymaster.addEscrow(block.chainid, testEscrowAddress);
        _testPaymaster.addAcceptedChain(block.chainid, true);
        _testPaymaster.addAcceptedAsset(block.chainid, address(0), true);
        _testPaymaster.addAcceptedOrigin(BUNDLER, true);

        _testEscrow = new TestEscrow();
        testEscrowAddress = address(_testEscrow);
        _testEscrow.addEntryPoint(block.chainid, entryPointAddress);
        _testEscrow.addHyperlaneAddress(hyperlaneMailboxAddress, true);


        // needs to execute and accept message on chain A
        // then execute handle on chain B


        bytes memory callData_;
        bytes memory initCode_;
        PaymasterAndData memory paymasterAndData_;
        address sender_;
        bytes32 userOpHash;
        uint8 v;
        bytes32 r;
        bytes32 s;
        UserOperation[] memory userOps = new UserOperation[](1);
        uint256 newSize;
        address newAddress;
        
        // create callData:
        // initCode_ = abi.encodePacked(simpleAccountFactory_, abi.encodeWithSignature("createAccount(address,uint256)", eoaAddress, SALT+1));
        // sender_ = simpleAccountFactory_.getAddress(eoaAddress, SALT+1);

        // userOp.sender = sender_;
        // userOp.initCode = initCode_;

        // userOpHash = entryPoint_.getUserOpHash(userOp);
        // (v, r, s) = vm.sign(privateKey, userOpHash.toEthSignedMessageHash());
        // userOp.signature = abi.encodePacked(r, s, v);
        // entryPoint_.depositTo{value: 1 ether}(sender_);
        // userOps[0] = (userOp);

        // // create calldata from eoa simple account to entrypoint, to create 0x69
        // callData_ = abi.encodeWithSelector(entryPoint_.handleOps.selector, userOps, msg.sender);
        // callData_ = abi.encodeWithSelector(SimpleAccount.execute.selector, entryPointAddress, 0, callData_);

        // newAddress = sender_;
        // assembly {
        //     newSize := extcodesize(newAddress)
        // }
        // console.log("new address", newAddress);
        // console.log("new balance", entryPoint_.balanceOf(sender_));
        // console.log("new address size", newSize);

        // cannot create double create account due to reentrancy guard
        initCode_ = abi.encodePacked(simpleAccountFactory_, abi.encodeWithSignature("createAccount(address,uint256)", eoaAddress, SALT));
        sender_ = simpleAccountFactory_.getAddress(eoaAddress, SALT);
        paymasterAndData_ = paymasterAndDataBase;
        paymasterAndData_.paymaster = address(0);
        paymasterAndData_.owner = address(0);
        paymasterAndData_.chainId = uint256(0);
        paymasterAndData_.asset = address(0);
        paymasterAndData_.amount = uint256(0);

        userOp.sender = sender_;
        userOp.initCode = initCode_;
        userOp.callData = callData_; // null for now
        userOp.paymasterAndData = abi.encodePacked(
            paymasterAndData_.paymaster,
            paymasterAndData_.owner,
            paymasterAndData_.chainId,
            paymasterAndData_.asset,
            paymasterAndData_.amount
        );

        userOpHash = entryPoint_.getUserOpHash(userOp);
        (v, r, s) = vm.sign(privateKey, userOpHash.toEthSignedMessageHash());
        userOp.signature = abi.encodePacked(r, s, v);
        entryPoint_.depositTo{value: 1 ether}(sender_);
        userOps[0] = (userOp);

        //
        bytes memory payload_ = abi.encodeWithSelector(bytes4(0x1fad948c), userOps, payable(address(uint160(uint256(6666)))));
        gas = gasleft();
        assembly {
            pop(call(gas(), sload(entryPointAddress.slot), 0, add(payload_, 0x20), mload(payload_), 0, 0))
        }
        //entryPoint_.handleOps(userOps, payable(address(uint160(uint256(6666)))));
        newAddress = sender_;
        assembly {
            newSize := extcodesize(newAddress)
        }
        console.log("new address", newAddress);
        console.log("new balance", entryPoint_.balanceOf(sender_));
        console.log("new address size", newSize);
        console.log("gas used for factory deployment", gas - gasleft());
    }

    function testPaymaster() public {}

    // test the execution of assets moving from paymaster to be used by the AA account
    function testPaymaster2() public {}
 }