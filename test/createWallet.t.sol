// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import {Vm as vm} from "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";

import {EntryPoint, IEntryPoint, UserOperation, UserOperationLib} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
import {Safe} from "lib/safe-contracts/contracts/Safe.sol";
import {SafeProxyFactory, SafeProxy} from "lib/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import {HypergateWalletFactory, HypergateWallet} from "contracts/HypergateWalletFactory.sol";
//import {SimpleAccount, SimpleAccountFactory, UserOperation} from "@erc4337/samples/SimpleAccountFactory.sol";
//bytes memory initHypergateWallet = abi.encodeWithSelector(0xc4d66de8,address_);
contract CreateWalletTest is Test {
    using UserOperationLib for UserOperation;
    address internal eoaAddress;

    // Entry point
    EntryPoint public entryPoint;
    address internal entryPointAddress;

    // // Factory for individual 4337 accounts
    // SimpleAccountFactory public simpleAccountFactory;
    // address internal simpleAccountFactoryAddress;

    // Hypergate Wallet variables
    HypergateWalletFactory public hypergateWalletFactory;
    address internal hypergateWalletFactoryAddress;
    HypergateWallet public hypergateWallet;
    address internal hypergateWalletAddress;
    HypergateWallet public hypergateWalletSingleton;
    address internal hypergateWalletSingletonAddress;
    uint256 hypergateNonce;

    // Safe Wallet variables
    SafeProxyFactory public safeProxyFactory;
    address internal safeProxyFactoryAddress;
    Safe public safeSingleton;
    address internal safeSingletonAddress;
    Safe public safeWallet;
    address internal safeWalletAddress;
    address internal safeWalletAddress2;
    bytes safeInitalizer;
    bytes safePayload;
    bytes safeGetAddressPayload;
    bytes hypergateWalletPayload;

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

        hypergateWalletSingleton = new HypergateWallet();
        hypergateWalletSingletonAddress = address(hypergateWalletSingleton);
        hypergateWalletFactory = new HypergateWalletFactory(hypergateWalletSingletonAddress);
        hypergateWalletFactoryAddress = address(hypergateWalletFactory);

        // 0x485cc955 == bytes4(keccak256("initialize(address,address)"))
        bytes memory initHypergateWallet = abi.encodeWithSelector(0x485cc955,eoaAddress, hypergateWalletSingletonAddress);
        hypergateWalletAddress = hypergateWalletFactory.createWallet(initHypergateWallet, bytes32(SALT));
        hypergateWallet = HypergateWallet(payable(hypergateWalletAddress));

        safeSingleton = new Safe();
        safeSingletonAddress = address(safeSingleton);
        safeProxyFactory = new SafeProxyFactory();
        safeProxyFactoryAddress = address(safeProxyFactory);

//function createProxyWithNonce(address _mastercopy, bytes memory initializer, uint256 saltNonce)
        safeInitalizer = abi.encodeWithSelector(0xb63e800d, 
            [eoaAddress],
            0,
            address(0),
            0,
            address(0),
            address(0),
            0,
            address(0)
        );

        safeGetAddressPayload = abi.encodeWithSelector(0x66b312c8, 
            eoaAddress,
            abi.encode(safeInitalizer)
        );
    }

    /**
      * @dev create Safe Wallet directly to EOA
      */
    function testCreateSafe() public {
        safePayload = abi.encodeWithSelector(0x1688f0b9, 
            safeSingletonAddress,
            abi.encode(safeInitalizer),
            uint256(SALT + hypergateNonce)
        );

        uint256 gasUsed = gasleft();
        (, bytes memory receipt) = payable(safeProxyFactoryAddress).call(safePayload);
        gasUsed -= gasleft();
        assembly {
            sstore(safeWalletAddress.slot, mload(add(receipt, 0x20)))
        }

        uint256 size;
        assembly {
                size := extcodesize(sload(safeSingletonAddress.slot))
        }
        console.log("SafeFactory:", safeProxyFactoryAddress);
        console.log("safeSingletonAddress:", safeSingletonAddress);
        console.log("Proxy size:", size);
        console.log("Generated address:", safeWalletAddress);
        console.log("Gas used:", gasUsed);
    }

    /**
      * @dev create Safe Wallet directly to EOA
      */
    function testCreateSafeFromWallet() public {
        safePayload = abi.encodeWithSelector(0x1688f0b9, 
            safeSingletonAddress,
            abi.encode(safeInitalizer),
            uint256(SALT + hypergateNonce)
        );

        console.log("HypergateWallet:", hypergateWalletAddress);
        console.log("hypergateWalletSingleton:", hypergateWalletSingletonAddress);
        console.log("SafeFactory:", safeProxyFactoryAddress);
        console.log("safeSingletonAddress:", safeSingletonAddress);
        hypergateWalletPayload = abi.encodeWithSelector(
            0xdbf4b30f,
            safeProxyFactoryAddress,
            safePayload,
            0,
            300000 gwei
            );
        
        uint256 gasUsed = gasleft();
        (bool success, bytes memory receipt) = payable(hypergateWalletAddress).call(hypergateWalletPayload);
        gasUsed -= gasleft();
        assembly {
            sstore(safeWalletAddress.slot, mload(add(receipt, 0x20)))
        }
        safeWallet = Safe(payable(safeWalletAddress));

        uint256 size;
        assembly {
                size := extcodesize(sload(hypergateWalletAddress.slot))
        }
        
        console.log("Proxy size:", size);
        console.log("Generated address:", safeWalletAddress);
        console.log("Gas used:", gasUsed);
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


createProxyWithNonce(safeSingletonAddress, )
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

abi.encodeWithSelector(0xb63e800d, 
    [eoaAddress],
    0,
    address(0),
    0,
    address(0),
    address(0),
    0,
    address(0)
    )

function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external {
        // setupOwners checks if the Threshold is already set, therefore preventing that this method is called twice
        setupOwners(_owners, _threshold);
        if (fallbackHandler != address(0)) internalSetFallbackHandler(fallbackHandler);
        // As setupOwners can only be called if the contract has not been initialized we don't need a check for setupModules
        setupModules(to, data);

        if (payment > 0) {
            // To avoid running into issues with EIP-170 we reuse the handlePayment function (to avoid adjusting code of that has been verified we do not adjust the method itself)
            // baseGas = 0, gasPrice = 1 and gas = payment => amount = (payment + 0) * 1 = payment
            handlePayment(payment, 0, 1, paymentToken, paymentReceiver);
        }
        emit SafeSetup(msg.sender, _owners, _threshold, to, fallbackHandler);
    }

function createWallet(address target, bytes calldata data, uint256 amount, uint256 gas) external payable returns(address) {
        (bool success, bytes memory receipt) = target.call{value: amount, gas: gas}(data);
        require(success, "Wallet creation failed");
        _wallet[_nonce] = Wallet(address(bytes20(receipt)), target, tx.origin, block.timestamp, uint256(bytes32(data[4:])), amount);
        return address(bytes20(receipt));
    }

function getWalletAddress(address target, bytes calldata data) external {
        (bool success, bytes memory receipt) = target.call(data);
        require(success, "Wallet creation failed");
        address walletAddress = address(bytes20(receipt));
        bool initalized;
        assembly { initalized := isZero(isZero(extcodesize(walletAddress))) }
        revert(abi.encode(walletAddress, initalized));
    }
*/