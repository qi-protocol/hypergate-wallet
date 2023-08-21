// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import {UserOperation, UserOperationLib} from "lib/account-abstraction/contracts/interfaces/UserOperation.sol";
import {Client} from "lib/ccip-starter-kit-foundry/src/BasicMessageSender.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

// needs to recieve a message from ccip (UserOp, PaymasterAddress)
// then release locked funds
// deserialize PaymasterAndData (paymaster, chainid, target, owner, amount)
// chainid == block.chainid
// validateSignature == owner
// transfer amount to paymaster 
contract TestEscrow is Ownable {
    using UserOperationLib for UserOperation;
    using Strings for uint256;

    mapping(address => Escrow) accountInfo;
    mapping(address => bool) entryPoint;
    mapping(address => bool) ccipAddress;
    mapping(address => bool) layerZeroAddress;
    mapping(address => bool) hyperlaneAddress;

    struct Escrow {
        uint256 deadline;
        uint256 nonce;
        uint256 balance;
        mapping(uint256 => Payment) history;
    }

    struct Payment {
        uint256 timestamp;
        uint256 assetAmount;
        uint256 id;
        uint256 chainId;
        address to;
    }

    struct PaymasterAndData {
        address paymaster;
        uint64 chainId;
        address target;
        address owner;
        uint256 amount;
    }

    bool lock;
    modifier locked() {
        require(!lock, "no reentry");
        lock = true;
        _;
        lock = false;
    }

    function addCCIPAddress(address ccip, bool state) public onlyOwner {
        ccipAddress[ccip] = state;
    }

    function _decodePaymasterAndData(bytes memory data) internal returns (PaymasterAndData memory) {
        require(data.length >= 160, (data.length).toString());

        bytes32[5] memory op_data;

        uint256 len = data.length;
        bytes memory dataCopy = new bytes(len);
        assembly {
            calldatacopy(add(dataCopy, 0x20), 0, len) // Copy calldata to memory

            mstore(add(op_data, 0x20), mload(add(dataCopy, 0x20))) // paymaster
            mstore(add(op_data, 0x40), mload(add(dataCopy, 0x40))) // chainId
            mstore(add(op_data, 0x60), mload(add(dataCopy, 0x60))) // target
            mstore(add(op_data, 0x80), mload(add(dataCopy, 0x80))) // owner
            mstore(add(op_data, 0xA0), mload(add(dataCopy, 0xA0))) // amount
        }

        return PaymasterAndData(
            address(uint160(uint256(op_data[0]))),
            uint64(uint256(op_data[1])),
            address(uint160(uint256(op_data[2]))),
            address(uint160(uint256(op_data[3]))),
            uint256(op_data[4])
        );
    }


    function _calldataUserOperation(UserOperation memory userop) internal view returns(UserOperation calldata op) {
        assembly {
            op := userop
        }
    }

    // deserialize userop calldata for easier integration into any dapp
    function _decodeUserOperation(bytes calldata data) public returns (UserOperation memory) {
        bytes32 messageId;
        uint256 sourceChainSelector;
        bytes memory sender;
        address uoSender;
        uint256 uoNonce;
        bytes memory uoInitCode;
        bytes memory uoCallData;
        uint256 messageSize;
        uint256 uoCallGasLimit;
        uint256 uoVerificationGasLimit;
        uint256 uoPreVerificationGas;
        uint256 uoMaxFeePerGas;
        uint256 uoMaxPriorityFeePerGas;
        bytes memory uoPaymasterAndData;
        bytes memory uoSignature;
        Client.EVMTokenAmount memory destTokenAmounts;
        assembly {
            let dataLength
            let objectLength
            let len := mload(0x20)
            let ptr := mload(0x40)
            let offset := 0x4

            // ================================================================
            // begin deserialize CCIP message
            calldatacopy(ptr, add(offset, 0x20), 0x20)
            messageId := mload(ptr)
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0x40), 0x20)
            sourceChainSelector := mload(ptr)
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0x60), 0x20) // string size ref
            calldatacopy(ptr, add(mload(ptr), 0x4), 0x20)
            messageSize := mload(ptr) // not used
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0x80), 0x20)
            calldatacopy(len, add(sub(mload(ptr), 0x20), 0x4), 0x20)
            calldatacopy(ptr, add(mload(ptr), 0x4), mload(len))
            sender := mload(ptr)
            // ================================================================
            // begin deserialize user operation
            calldatacopy(ptr, add(offset, 0x100), 0x20)
            offset := add(offset, 0x120)
            // ----------------------------------------------------------------
            calldatacopy(ptr, offset, 0x20)
            calldatacopy(ptr, add(mload(ptr), offset), 0x20)
            uoSender := mload(ptr)
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0x40), 0x20)
            uoNonce := mload(ptr)
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0x60), 0x20)
            uoInitCode := mload(ptr) // ref
            calldatacopy(ptr, add(offset, 0x80), 0x20)
            uoCallData := mload(ptr) // ref
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0xA0), 0x20)
            uoCallGasLimit := mload(ptr)
            calldatacopy(ptr, add(offset, 0xC0), 0x20)
            uoVerificationGasLimit := mload(ptr)
            calldatacopy(ptr, add(offset, 0xE0), 0x20)
            uoPreVerificationGas := mload(ptr)
            calldatacopy(ptr, add(offset, 0x100), 0x20)
            uoMaxFeePerGas := mload(ptr)
            calldatacopy(ptr, add(offset, 0x120), 0x20)
            uoMaxPriorityFeePerGas := mload(ptr)
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0x140), 0x20)
            uoPaymasterAndData := mload(ptr) // ref
            calldatacopy(ptr, add(offset, 0x160), 0x20)
            uoSignature := mload(ptr) // ref
            // ----------------------------------------------------------------
            calldatacopy(len, add(uoInitCode, add(offset, 0x20)), 0x20)
            switch iszero(len)
            case 0 {
                calldatacopy(ptr, add(uoInitCode, add(offset, 0x40)), mload(len))
                uoInitCode := mload(ptr)
            }
            // ----------------------------------------------------------------
            calldatacopy(len, add(uoCallData, add(offset, 0x20)), 0x20)
            switch iszero(len)
            case 0 {
                calldatacopy(ptr, add(uoCallData, add(offset, 0x40)), mload(len))
                uoCallData := mload(ptr)
            }
            // ----------------------------------------------------------------
            calldatacopy(len, add(uoPaymasterAndData, add(offset, 0x20)), 0x20)
            switch iszero(len)
            case 0 {
                calldatacopy(ptr, add(uoPaymasterAndData, add(offset, 0x40)), mload(len))
                uoPaymasterAndData := mload(ptr)
            }
            // ----------------------------------------------------------------
            calldatacopy(len, add(uoSignature, add(offset, 0x20)), 0x20)
            switch iszero(len)
            case 0 {
                calldatacopy(ptr, add(uoSignature, add(offset, 0x40)), mload(len))
                uoSignature := mload(ptr)
            }
            // ================================================================
            // continue CCIP deserialization
            calldatacopy(ptr, sub(offset, 0x20), 0x20)
            offset := add(offset, mload(ptr))
            // ----------------------------------------------------------------
            calldatacopy(len, offset, 0x20)
            switch iszero(len)
            case 0 {
                calldatacopy(ptr, add(offset, 0x20), mload(len))
                destTokenAmounts := mload(ptr)
            }
            calldatacopy(len, offset, 0x20)


            
            // ================================================================
            // CCIP UserOp referance sheet
            // ================================================================
            // 0x // messageId (bytes32)
            // 0000000000000000000000000000000000000000000000000000000000000020
            // 00000000000000000000000000000000000000000000000000000000000003e8
            // sourceChainSelector
            // 000000000000000000000000000000000000000000000000b63e800d00000000
            // wtf is this? data string size ref
            // 00000000000000000000000000000000000000000000000000000000000000a0
            // sender ref
            // 00000000000000000000000000000000000000000000000000000000000000e0
            // wtf is this? data string size
            // 00000000000000000000000000000000000000000000000000000000000005a0
            // sender (message)
            // 0000000000000000000000000000000000000000000000000000000000000020
            // 7fa9385be102ac3eac297483dd6233d62b3e1496000000000000000000000000
            // ================================================================
            // data start
            // 00000000000000000000000000000000000000000000000000000000000004a0
            // ----------------------------------------------------------------
            // sender (userop)
            // 0000000000000000000000000000000000000000000000000000000000000020
            // ff65689a4aeb6eadd18cad2de0022f8aa18b67de000000000000000000000000
            // ----------------------------------------------------------------
            // nonce
            // 00000000000000000000000000000000000000000000000000000000000000f0
            // ----------------------------------------------------------------
            // initCode ref
            // 0000000000000000000000000000000000000000000000000000000000000160
            // callData ref
            // 0000000000000000000000000000000000000000000000000000000000000180
            // ----------------------------------------------------------------
            // callGasLimit
            // 0000000000000000000000000000000000000000000000000000000000989680
            // verificationGasLimit
            // 0000000000000000000000000000000000000000000000000000000001312d00
            // preVerificationGas
            // 0000000000000000000000000000000000000000000000000000000001312d00
            // maxFeePerGas
            // 0000000000000000000000000000000000000000000000000000000000000002
            // maxPriorityFeePerGas
            // 0000000000000000000000000000000000000000000000000000000000000001
            // ----------------------------------------------------------------
            // paymasterAndData ref
            // 0000000000000000000000000000000000000000000000000000000000000340
            // signature ref
            // 0000000000000000000000000000000000000000000000000000000000000400
            // ----------------------------------------------------------------
            // initCode size
            // 0000000000000000000000000000000000000000000000000000000000000000
            // ----------------------------------------------------------------
            // callData size
            // 0000000000000000000000000000000000000000000000000000000000000184
            // b61d27f6 // calldata
            // 000000000000000000000000c532a74256d3db42d0bf7a0400fefdbad7694008
            // 00000000000000000000000000000000000000000000000000038d7ea4c68000
            // 0000000000000000000000000000000000000000000000000000000000000060
            // 00000000000000000000000000000000000000000000000000000000000000e4
            // 7ff36ab500000000000000000000000000000000000000000000000000000000
            // 0000000000000000000000000000000000000000000000000000000000000000
            // 0000008000000000000000000000000052eb5d94da6146836b0a6c542b69545d
            // d35fda6d00000000000000000000000000000000000000000000000000000000
            // 669e545500000000000000000000000000000000000000000000000000000000
            // 000000020000000000000000000000007b79995e5f793a07bc00c21412e50eca
            // e098e7f9000000000000000000000000ae0086b0f700d6d7d4814c4ba1e55d3b
            // c0dfee0200000000000000000000000000000000000000000000000000000000
            // 00000000000000000000000000000000000000000000000000000000
            // ----------------------------------------------------------------
            // paymasterAndData
            // 00000000000000000000000000000000000000000000000000000000000000a0
            // 0000000000000000000000000000000000000000000000000000000000000000
            // 0000000000000000000000000000000000000000000000000000000000000000
            // 0000000000000000000000000000000000000000000000000000000000000000
            // 0000000000000000000000000000000000000000000000000000000000000000
            // 0000000000000000000000000000000000000000000000000000000000000000
            // ----------------------------------------------------------------
            // signature
            // 0000000000000000000000000000000000000000000000000000000000000041
            // 190999a8ab31185b0c415c5e1fbb48dd71429e0fee42c1d1c82bfa27b07a7097
            // 29a859e59fb4721398502b92b2ff0696ee130b489a1347182f92bfa33fd11f0f
            // 1b00000000000000000000000000000000000000000000000000000000000000
            // data end
            // ================================================================
            // destTokenAmounts
            // 0000000000000000000000000000000000000000000000000000000000000000
        }

        return UserOperation(
            uoSender,
            uint256(uoNonce),
            uoInitCode,
            uoCallData,
            uint256(uoCallGasLimit),
            uint256(uoVerificationGasLimit),
            uint256(uoPreVerificationGas),
            uint256(uoMaxFeePerGas),
            uint256(uoMaxPriorityFeePerGas),
            uoPaymasterAndData,
            uoSignature
        );
    }



    // extend lock by calling with value: 0
    function deposit(address account) public payable locked {
        Escrow storage accountInfo_ = accountInfo[account];
        accountInfo_.deadline = block.timestamp + 1200;
        accountInfo_.balance = accountInfo_.balance + msg.value;
    }

    function withdraw(address account, uint256 amount) public locked {
        Escrow storage accountInfo_ = accountInfo[account];
        if(accountInfo_.deadline > block.timestamp) {
            revert WithdrawRejected("Too early");
        }
        if(accountInfo_.balance < amount) {
            revert WithdrawRejected("Insufficent balance");
        }
        (bool success,) = payable(account).call{value: amount}("");
        if(!success) {
            revert TransferFailed();
        }
    }

    function handleMessage(Client.Any2EVMMessage memory message) payable external locked {
        // validate msg.sender is ccip source
        // cast data into userop
        // ignore the rest
        if(!ccipAddress[msg.sender]) {
            revert InvalidCCIPAddress(msg.sender);
        }
        // UserOperation calldata userOp;// = _calldataUserOperation(_decodeUserOperation(message.data));
        // PaymasterAndData memory data = _decodePaymasterAndData(userOp.paymasterAndData);

        // // authenticate the operation
        // bytes32 userOpHash = userOp.hash();
        // // need to check safe signature method (maybe ecdsa?)
        // // account == validateSignature from safe

        // if(data.chainId != block.chainid) {
        //     revert InvalidChain(data.chainId);
        // }
        // if(data.amount < address(this).balance) {
        //     revert BalanceError(data.amount, address(this).balance);
        // }

        // if(data.amount <= accountInfo[data.owner].balance) {
        //     revert InsufficentFunds(userOp.sender, data.amount, accountInfo[data.owner].balance);
        // }
        // (bool success,) = payable(data.target).call{value: data.amount}("");
        // if(!success) {
        //     revert PaymasterPaymentFailed(data.target, userOp.sender, data.amount);
        // }
    }
// struct Any2EVMMessage {
//     bytes32 messageId; // MessageId corresponding to ccipSend on source.
//     uint64 sourceChainSelector; // Source chain selector.
//     bytes sender; // abi.decode(sender) if coming from an EVM chain.
//     bytes data; // payload sent in original message.
//     EVMTokenAmount[] destTokenAmounts; // Tokens and their amounts in their destination chain representation.
//   }
    function printOp(Client.Any2EVMMessage memory message) payable external locked {
        // latestMessageId = message.messageId;
        // latestSourceChainSelector = message.sourceChainSelector;
        // latestSender = abi.decode(message.sender, (address));
        // latestMessage = abi.decode(message.data, (string));
        // validate msg.sender is ccip source
        // cast data into userop
        // ignore the rest
        if(!ccipAddress[msg.sender]) {
            revert InvalidCCIPAddress(msg.sender);
        }
        // need to check for authorized paymaster?
        UserOperation memory mUserOp = _decodeUserOperation();

        // UserOperation calldata userOp = _calldataUserOperation(mUserOp);
        // PaymasterAndData memory data = _decodePaymasterAndData(mUserOp.paymasterAndData);

        // // authenticate the operation
        // bytes32 userOpHash = userOp.hash();
        // // need to check safe signature method (maybe ecdsa?)

        // if(data.chainId != block.chainid) {
        //     revert InvalidChain(data.chainId);
        // }
        // if(data.amount < address(this).balance) {
        //     revert BalanceError(data.amount, address(this).balance);
        // }

        // emit PrintUserOp(userOp, data);
    }
    
    /*
    Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
                receiver: abi.encode(receiver),
                data: abi.encode(messageText),
                tokenAmounts: new Client.EVMTokenAmount[](0),
                extraArgs: "",
                feeToken: payFeesIn == PayFeesIn.LINK ? i_link : address(0)
            });

    */
    function callPrintOp(Client.Any2EVMMessage memory message) payable external locked {
        // validate msg.sender is ccip source
        // cast data into userop
        // ignore the rest
        if(!ccipAddress[msg.sender]) {
            revert InvalidCCIPAddress(msg.sender);
        }
        // UserOperation calldata userOp;// = _calldataUserOperation(_decodeUserOperation(message.data));
        // PaymasterAndData memory data = _decodePaymasterAndData(userOp.paymasterAndData);

        // // authenticate the operation
        // bytes32 userOpHash = userOp.hash();
        // // need to check safe signature method (maybe ecdsa?)

        // if(data.chainId != block.chainid) {
        //     revert InvalidChain(data.chainId);
        // }
        // if(data.amount < address(this).balance) {
        //     revert BalanceError(data.amount, address(this).balance);
        // }
    }

    error WithdrawRejected(string);
    error TransferFailed();
    error InsufficentFunds(address account, uint256 needed, uint256 available);
    error PaymasterPaymentFailed(address paymaster, address account, uint256 amount);
    error InvalidCCIPAddress(address badSender);
    error InvalidLayerZeroAddress(address badSender);
    error InvalidHyperlaneAddress(address badSender);
    error InvalidChain(uint64 badDestination);
    error BalanceError(uint256 requested, uint256 actual);

    event PrintUserOp(UserOperation userOp, PaymasterAndData paymasterAndData);

    fallback() external payable {}
}
