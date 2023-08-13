// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import {UserOperation, UserOperationLib} from "lib/account-abstraction/contracts/interfaces/UserOperation.sol";
import {PayFeesIn, send, Client} from "lib/ccip-starter-kit-foundry/src/BasicMessageSender.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

// needs to recieve a message from ccip (UserOp, PaymasterAddress)
// then release locked funds
// deserialize PaymasterAndData (paymaster, chainid, target, owner, amount)
// chainid == block.chainid
// validateSignature == owner
// transfer amount to paymaster 
contract TestEscrow is BasicMessageReceiver {
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
        UserOperation calldata userOp = UserOperation(message.data);
        bytes memory data = PaymasterAndData(userOp.paymasterAndData);

        // authenticate the operation
        bytes32 memory userOpHash = userOp.hash();
        // need to check safe signature method (maybe ecdsa?)
        // account == validateSignature from safe

        if(data.chainId != block.chainid) {
            revert InvalidChain(data.chainId);
        }
        if(data.amount < balance(address(this))) {
            revert BalanceError(data.amount, balance(address(this)));
        }

        if(data.amount <= accountInfo[data.account])
        (bool success,) = payable(data.target).call{value: data.amount}("");
        if(!success) {
            PaymasterPaymentFailed(data.target, userOp.sender, data.amount);
        }
    }

    function PrintOp(Client.Any2EVMMessage memory message) payable external locked {
        // validate msg.sender is ccip source
        // cast data into userop
        // ignore the rest
        if(!ccipAddress[msg.sender]) {
            revert InvalidCCIPAddress(msg.sender);
        }
        UserOperation calldata userOp = UserOperation(message.data);
        bytes memory data = PaymasterAndData(userOp.paymasterAndData);

        // authenticate the operation
        bytes32 memory userOpHash = userOp.hash();
        // need to check safe signature method (maybe ecdsa?)

        if(data.chainId != block.chainid) {
            revert InvalidChain(data.chainId);
        }
        if(data.amount < balance(address(this))) {
            revert BalanceError(data.amount, balance(address(this)));
        }

        emit PrintUserOp(userOp, data);
    }
//Client.Any2EVMMessage memory message
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
        UserOperation calldata userOp = UserOperation(message.data);
        bytes memory data = PaymasterAndData(userOp.paymasterAndData);

        // authenticate the operation
        bytes32 memory userOpHash = userOp.hash();
        // need to check safe signature method (maybe ecdsa?)

        if(data.chainId != block.chainid) {
            revert InvalidChain(data.chainId);
        }
        if(data.amount < balance(address(this))) {
            revert BalanceError(data.amount, balance(address(this)));
        }
    }

    error WithdrawRejected(string);
    error TransferFailed();
    error PaymasterPaymentFailed(address paymaster, address account, uint256 amount);
    error InvalidCCIPAddress(address badSender);
    error InvalidLayerZeroAddress(address badSender);
    error InvalidHyperlaneAddress(address badSender);
    error InvalidChain(address badDestination);
    error BalanceError(uint256 requested, uint256 actual);

    event PrintUserOp(UserOperation userOp, PaymasterAndData paymasterAndData);

    fallback() external payable {}
}