// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import {Vm as vm} from "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";

import {EntryPoint, IEntryPoint} from "lib/account-abstraction/core/EntryPoint.sol";
//import {SimpleAccount, SimpleAccountFactory, UserOperation} from "@erc4337/samples/SimpleAccountFactory.sol";

contract basicTest is Test {
    address internal eoaAddress;

    // Entry point
    EntryPoint public entryPoint;
    address internal entryPointAddress;

    // Factory for individual 4337 accounts
    SimpleAccountFactory public simpleAccountFactory;
    address internal simpleAccountFactoryAddress;

    SimpleAccount public simpleAccount;
    address internal simpleAccountAddress;

    uint256 internal constant SALT = 0x55;
    
    uint256[2] internal publicKey;
    string internal constant SIGNER_1 = "1";

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

    function setUp() public {
        string memory key = vm.readFile(".secret");
        bytes32 key_bytes = vm.parseBytes32(key);
        uint256 privateKey;
        assembly {
            privateKey := key_bytes
        }
        eoaAddress = vm.addr(privateKey);
        entryPoint = new EntryPoint();
        entryPointAddress = address(entryPoint);
        simpleAccountFactory = new SimpleAccountFactory(IEntryPoint(entryPointAddress));
        simpleAccountFactoryAddress = address(simpleAccountFactory);
        simpleAccount = simpleAccountFactory.createAccount(eoaAddress, SALT);
        simpleAccountAddress = address(simpleAccount);
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

/*
logically
L1-L1
L1-L2
L2-L1
L2-L2

data > entrypoint, data > wallet
pick target, chainid
pick wallet chain A, chain B
pick execution method

Mode:
Sepolia L1 - Sepolia OP L2

Zora / OP / Base:
Goerli L1 - Goerli OP L2

Hyperlane / LayerZero / ChainLink CCIP:
OP Goerli
Sepolia
Goerli
Base Goerli (not hyperlane)

Goals:
Mode > Sepolia > Hyperlane / LayerZero > Goerli > OP
OP > Goerli > Hyperlane / LayerZero > Sepolia > Mode
OP > Goerli > OP
OP > LayerZero > OP

OP can be Zora / OP / Base

Deploy wallet factory contracts to both origin and source



function createProxyWithNonce(address _mastercopy, bytes memory initializer, uint256 saltNonce)
        public
        returns (Proxy proxy)
    {
        proxy = deployProxyWithNonce(_mastercopy, initializer, saltNonce);
        if (initializer.length > 0)
            // solium-disable-next-line security/no-inline-assembly
            assembly {
                if eq(call(gas, proxy, 0, add(initializer, 0x20), mload(initializer), 0, 0), 0) { revert(0,0) }
            }
        emit ProxyCreation(proxy);
    }

function calculateCreateProxyWithNonceAddress(address _mastercopy, bytes calldata initializer, uint256 saltNonce)
        external
        returns (Proxy proxy)
    {
        proxy = deployProxyWithNonce(_mastercopy, initializer, saltNonce);
        revert(string(abi.encodePacked(proxy)));
    }
*/