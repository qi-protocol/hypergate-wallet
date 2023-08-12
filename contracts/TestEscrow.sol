// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import {UserOperation, UserOperationLib} from "lib/account-abstraction/contracts/interfaces/UserOperation.sol";
import {PayFeesIn, send, Client} from "lib/ccip-starter-kit-foundry/src/BasicMessageSender.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

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

    function HandleMessage(bytes calldata op) payable external locked {
        UserOperation userOp = UserOperation(op);

        address paymaster_ = address(bytes20(data[:20]));
        uint64 chainId_ = uint64(bytes8(data[20:28]));
        address target_ = address(bytes20(data[28:48]));
        address owner_ = address(bytes20(data[48:68]));
        uint256 amount_ = uint256(bytes32(data[68:100]));

        // authenticate the operation
        bytes32 memory userOpHash = userOp.hash();
        // need to check safe signature method (maybe ecdsa?)

        if(chainId_ != block.chainid) {
            revert InvalidChain();
        }
        if(amount_ < balance(address(this))) {
            revert BalanceError(amount_, balance(address(this)));
        }
    }

    error WithdrawRejected(string);
    error TransferFailed();
    error InvalidChain();
    error BalanceError(uint256 requested, uint256 actual);

    fallback() external payable {}
}