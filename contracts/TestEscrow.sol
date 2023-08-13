// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import {UserOperation, UserOperationLib} from "lib/account-abstraction/contracts/interfaces/UserOperation.sol";
import {Client} from "lib/ccip-starter-kit-foundry/src/BasicMessageSender.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

// needs to recieve a message from ccip (UserOp, PaymasterAddress)
// then release locked funds
// deserialize PaymasterAndData (paymaster, chainid, target, owner, amount)
// chainid == block.chainid
// validateSignature == owner
// transfer amount to paymaster 
contract TestEscrow {
    using UserOperationLib for UserOperation;

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
        require(lock, "no reentry");
        lock = true;
        _;
        lock = false;
    }

    function _decodePaymasterAndData(bytes memory data) internal pure returns (PaymasterAndData memory) {
        require(data.length == 104, "Invalid data length"); // 20 + 8 + 20 + 20 + 32 = 100 bytes

        PaymasterAndData memory result;
        address paymaster;
        uint64 chainId;
        address target;
        address owner;
        uint256 amount;

        uint256 len = data.length;
        bytes memory dataCopy = new bytes(len);
        assembly {
            calldatacopy(add(dataCopy, 0x20), 0, len) // Copy calldata to memory

            paymaster := mload(add(dataCopy, 0x20))
            chainId := mload(add(dataCopy, 0x34))
            target := mload(add(dataCopy, 0x40))
            owner := mload(add(dataCopy, 0x60))
            amount := mload(add(dataCopy, 0x80))
        }

        result.paymaster = paymaster;
        result.chainId = chainId;
        result.target = target;
        result.owner = owner;
        result.amount = amount;

        return result;
    }


    function _calldataUserOperation(UserOperation memory userop) internal view returns(UserOperation calldata op) {
        assembly {
            op := userop
        }
    }

    function _decodeUserOperation(bytes memory data) internal pure returns (UserOperation memory) {
        UserOperation memory result;
        address sender;
        uint256 nonce;
        bytes memory initCode;
        bytes memory callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes memory paymasterAndData;
        bytes memory signature;

        uint256 len = data.length;
        bytes memory dataCopy = new bytes(len);
        assembly {
            calldatacopy(add(dataCopy, 0x20), 0, len) // Copy calldata to memory

            sender := mload(add(dataCopy, 0x20))
            nonce := mload(add(dataCopy, 0x40))
            
            let offset := add(dataCopy, mload(add(dataCopy, 0x60)))
            initCode := add(offset, 0x20)
            
            offset := add(offset, mload(offset))
            callData := add(offset, 0x20)
            
            offset := add(offset, mload(offset))
            callGasLimit := mload(add(offset, 0x20))
            verificationGasLimit := mload(add(offset, 0x40))
            preVerificationGas := mload(add(offset, 0x60))
            maxFeePerGas := mload(add(offset, 0x80))
            maxPriorityFeePerGas := mload(add(offset, 0xA0))
            
            offset := add(offset, 0xC0)
            paymasterAndData := add(offset, 0x20)
            
            offset := add(offset, mload(offset))
            signature := add(offset, 0x20)
        }

        result.sender = sender;
        result.nonce = nonce;
        result.initCode = initCode;
        result.callData = callData;
        result.callGasLimit = callGasLimit;
        result.verificationGasLimit = verificationGasLimit;
        result.preVerificationGas = preVerificationGas;
        result.maxFeePerGas = maxFeePerGas;
        result.maxPriorityFeePerGas = maxPriorityFeePerGas;
        result.paymasterAndData = paymasterAndData;
        result.signature = signature;

        return result;
    }



    // extend lock by calling with value: 0
    function Deposit(address account) public payable locked {
        Escrow storage accountInfo_ = accountInfo[account];
        accountInfo_.deadline = block.timestamp + 1200;
        accountInfo_.balance = accountInfo_.balance + msg.value;
    }

    function Withdraw(address account, uint256 amount) public locked {
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

    function HandleMessage(Client.Any2EVMMessage memory message) payable external locked {
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
        // account == validateSignature from safe

        if(data.chainId != block.chainid) {
            revert InvalidChain(data.chainId);
        }
        if(data.amount < address(this).balance) {
            revert BalanceError(data.amount, address(this).balance);
        }

        if(data.amount <= accountInfo[data.owner].balance) {
            revert InsufficentFunds(userOp.sender, data.amount, accountInfo[data.owner].balance);
        }
        (bool success,) = payable(data.target).call{value: data.amount}("");
        if(!success) {
            revert PaymasterPaymentFailed(data.target, userOp.sender, data.amount);
        }
    }

    function PrintOp(Client.Any2EVMMessage memory message) payable external locked {
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
    
    /*
    Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
                receiver: abi.encode(receiver),
                data: abi.encode(messageText),
                tokenAmounts: new Client.EVMTokenAmount[](0),
                extraArgs: "",
                feeToken: payFeesIn == PayFeesIn.LINK ? i_link : address(0)
            });

    */
    function CallPrintOp(Client.Any2EVMMessage memory message) payable external locked {
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
