// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import {Vm as vm} from "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";

import {IMailbox, IIGP, TestPaymaster, IEntryPoint} from "flat/TestPaymaster2_f.sol";
import "contracts/interfaces/ITestEscrow.sol";

contract Deploy is Test {
    address internal eoaAddress;

    uint256[2] internal publicKey;
    string internal constant SIGNER_1 = "1";

    uint32 _originDomain = 11155111;
    uint32 _desitinationDomain = 80001;

    uint256 SALT = 1234567890;

    address recipient = 0x5A3f58B9EbC47013902301f821Ad2A52Da19daD8; // escrow (destination chain)
    address testVault = 0x9394142Baf05e400BAA14254098Bb334b80CCBDA; // (destination chain)
    /** {
      * function withdraw() onlyOwner
      * function withToken(address,address,uint256) onlyOwner
      */
    address mailbox = 0xCC737a94FecaeC165AbCf12dED095BB13F037685;
    address igp = 0x8f9C3888bFC8a5B25AED115A82eCbb788b196d2a;
    address simpleAccountFactory = 0x1B7cc2b0B2D8e7D35F7343f1E761CB4a05Eb134A; // compiled with 0.8.20
    address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    address paymaster_ = 0x3f1c38B5502c36D25499cF51c552663F89AD329C;

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

    function setup() public {}

    // forge test --match-contract hyperlaneTest.t.sol --match-test testOrigin \\
    // -f https://polygon-mumbai.infura.io/v3/341b39bd014341f1a1f7233044da3062
    // INFURA_MUMBAI_TEST_RPC_URL
    // INFURA_SEPOLIA_TEST_RPC_URL
    function testOrigin() public {
        string memory key = vm.readFile(".secret");
        bytes32 key_bytes = vm.parseBytes32(key);
        uint256 privateKey;
        assembly {
            privateKey := key_bytes
        }
        eoaAddress = vm.addr(privateKey);
        entryPointAddress = address(entryPoint);
        bytes memory initCode_ = abi.encodePacked(simpleAccountFactory, abi.encodeWithSignature("createAccount(address,uint256)", eoaAddress, SALT));
        UserOperation memory userOp = userOpBase;
        address sender_ = simpleAccountFactory.getAddress(eoaAddress, SALT);
        userOp.sender = sender_;
        userOp.initCode = initCode_;
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, userOpHash.toEthSignedMessageHash());
        userOp.signature = abi.encodePacked(r, s, v);
        userOp.paymasterAndData = abi.encodePacked(paymaster_, eoaAddress, _desitinationDomain, address(0), uint256(100000000000000000));

        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = (userOp);
        bytes memory payload_ = abi.encodeWithSelector(bytes4(0x1fad948c), userOps, payable(msg.sender));
        
        gas = gasleft();
        vm.startBroadcas(privateKey);
        assembly {
            pop(call(gas(), sload(entryPointAddress.slot), 0, add(payload_, 0x20), mload(payload_), 0, 0))
        }
        vm.stopBroadcast();
        //entryPoint.handleOps(userOps, payable(address(uint160(uint256(6666)))));
        console.log("gas used for factory deployment", gas - gasleft());
        uint256 newSize;
        address newAddress = sender_;
            assembly {
                newSize := extcodesize(newAddress)
            }
        console.log("new address", newAddress);
        console.log("new balance", entryPoint.balanceOf(sender_));
        console.log("new address size", newSize);
        simpleAccountAddress = address(simpleAccount);
    }

    function testDestination() public {
        string memory key = vm.readFile(".secret");
        bytes32 key_bytes = vm.parseBytes32(key);
        uint256 privateKey;
        assembly {
            privateKey := key_bytes
        }
        eoaAddress = vm.addr(privateKey);

        uint256 balanceOfVault;
        uint256 timeLock;
        uint256 lockedETH;
        uint256 nonce;
        bytes memory
        bytes memory payload = abi.encodeWithSignature("getBalance(address,address)", eoaAddress, address(0));
        (,recipient.call(payload)
        bytes memory payload = abi.encodeWithSignature("getDeadline(address)", eoaAddress);
        bytes memory payload = abi.encodeWithSignature("getNonce(address)", eoaAddress);
        bytes memory payload = abi.encodeWithSignature("getPayment(address,uint256)", eoaAddress, nonce);

        function getBalance(address account_, address asset_) public returns(uint256) {
        return _accountInfo[account_].assetBalance[asset_];
    }

    function getDeadline(address account_) public returns(uint256) {
        return _accountInfo[account_].deadline;
    }

    }

    function testCreate() public {
        console.log("All local EVM:");
        console.log("EOA: ", eoaAddress);
        console.log("EntryPoint: ", entryPointAddress);
        console.log("Simple Factory: ", simpleAccountFactoryAddress);
        console.log("SALT: ", SALT);
        console.log("Simple Account: ", simpleAccountAddress);
    }
}