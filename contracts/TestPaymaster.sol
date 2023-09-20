// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import {UserOperation} from "lib/account-abstraction/contracts/interfaces/UserOperation.sol";
import {BasePaymaster} from "lib/account-abstraction/contracts/core/BasePaymaster.sol";
import {EntryPoint, IEntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
import {Client, IRouterClient} from "lib/ccip-starter-kit-foundry/src/BasicMessageSender.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

// needs to recieve a message from ccip (UserOp, PaymasterAddress)
// then release locked funds
// deserialize PaymasterAndData (paymaster, chainid, target, owner, amount)
//bytes20, bytes8, bytes20, bytes20, bytes32 = 100 bytes
// chainid == block.chainid
// validateSignature == owner
// transfer amount to paymaster 
contract TestPaymaster is BasePaymaster {
    mapping(uint64 => address) public escrowAddress;
    mapping(uint64 => bool) public acceptedChain;
    mapping(uint64 => mapping(address => bool)) public acceptedAsset;
    mapping(address => bool) public acceptedOrigin;
    
    bytes4 _selector;
    address ccip_router;
    address defaultReceiver;

    // later version this will be packed instead
    struct PaymasterAndData {
        address paymaster;
        uint64 chainId;
        address asset;
        address owner;
        uint256 amount;
    }

    constructor(IEntryPoint entryPoint_, address ccip_router_, address defaultReceiver_) BasePaymaster(entryPoint_) {
        _selector = bytes4(keccak256("HandleMessage(bytes)"));
        ccip_router = ccip_router_;
        defaultReceiver = defaultReceiver_;
    }

    function getEscrowAddress(uint64 chainId) public view returns(address) {
        return escrowAddress[chainId];
    }

    function addEscrow(uint64 chainId, address escrowAddress_) public onlyOwner {
        escrowAddress[chainId] = escrowAddress_;
    }

    function addAcceptedChain(uint64 chainId_, bool state_) public onlyOwner {
        acceptedChain[chainId_] = state_;
    }

    function addAcceptedAsset(uint64 chainId_, address asset_, bool state_) public onlyOwner {
        acceptedAsset[chainId_][asset_] = state_;
    }

    function addAcceptedOrigin(address origin_, bool state_) public onlyOwner {
        acceptedOrigin[origin_] = state_;
    }

    function setCCIP(address ccip_router_) public onlyOwner {
        ccip_router = ccip_router_;
    }

    function getFee(
        uint64 destinationChainSelector,
        address receiver_,
        UserOperation calldata userOp
    ) public returns(uint256) {
        // uint256 paymasterAndDataLength = data.length;
        // if(paymasterAndDataLength < 100) { // only matters for encodePacked (currently 0x100 w/0)
        //     revert InvalidDataLength(paymasterAndDataLength);
        // }

        PaymasterAndData memory paymasterAndData_ = abi.decode(userOp.paymasterAndData, (PaymasterAndData));
        address paymaster_ = paymasterAndData_.paymaster;
        uint64 chainId_ = paymasterAndData_.chainId;
        address asset_ = paymasterAndData_.asset;
        address owner_ = paymasterAndData_.owner;
        uint256 amount_ = paymasterAndData_.amount;

        bytes4 selector_ = bytes4(0x8509636d);

        // paymaster must elect to accept funds from specific chains
        if(!acceptedChain[chainId_]) {
            revert InvalidChainId(chainId_);
        }

        if(!acceptedAsset[chainId_][asset_]) {
            revert InvalidAsset(chainId_, asset_);
        }

        address receiver_ = escrowAddress[chainId_] != address(0) ? escrowAddress[chainId_] : address(this);

        this.send{value: amount_}(chainId_, escrowAddress[chainId_], abi.encode(userOp, receiver_));
        bytes memory data = abi.encode(userOp, receiver_);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver_),
            data: abi.encode(_selector, data),
            tokenAmounts: new Client.EVMTokenAmount[](0), // no tokens
            extraArgs: "", // no extra
            feeToken: address(0) // always pay in ETH
        });

        uint256 fee = IRouterClient(ccip_router).getFee(
            destinationChainSelector,
            message
        );
    }

    // selector: 0xb63e800d
    function send(
        uint64 destinationChainSelector,
        address receiver,
        bytes memory data
    ) external payable returns (bytes32 messageId) {
        bytes4 selector_ = bytes4(0x8509636d);

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
        
        messageId = IRouterClient(ccip_router).ccipSend{value: fee+msg.value}(
            destinationChainSelector,
            message
        );
    }

    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32, uint256 requiredPreFund)
    internal
    override
    returns (bytes memory context, uint256 validationResult) {unchecked {
        // by default requires entrypoint to be the msg.sender
        if(!acceptedOrigin[tx.origin]) {
            revert InvalidOrigin(tx.origin);
        }

        // send with hash and signature
        //bytes calldata data = userOp.paymasterAndData;

        // uint256 paymasterAndDataLength = data.length;
        // if(paymasterAndDataLength < 100) { // only matters for encodePacked (currently 0x100 w/0)
        //     revert InvalidDataLength(paymasterAndDataLength);
        // }

        //bytes20, bytes8, bytes20, bytes20, bytes32 = 100 bytes
        // TODO: change to encodePacked paymasterAndData
        // address paymaster_ = address(bytes20(data[:20]));
        // uint64 chainId_ = uint64(bytes8(data[20:28]));
        // address asset_ = address(bytes20(data[28:48]));
        // address owner_ = address(bytes20(data[48:68]));
        // uint256 amount_ = uint256(bytes32(data[68:100]));

        PaymasterAndData memory paymasterAndData_ = abi.decode(userOp.paymasterAndData, (PaymasterAndData));
        address paymaster_ = paymasterAndData_.paymaster;
        uint64 chainId_ = paymasterAndData_.chainId;
        address asset_ = paymasterAndData_.asset;
        address owner_ = paymasterAndData_.owner;
        uint256 amount_ = paymasterAndData_.amount;

        // paymaster must elect to accept funds from specific chains
        if(!acceptedChain[chainId_]) {
            revert InvalidChainId(chainId_);
        }

        if(!acceptedAsset[chainId_][asset_]) {
            revert InvalidAsset(chainId_, asset_);
        }

        address receiver = escrowAddress[chainId_] != address(0) ? escrowAddress[chainId_] : address(this);

        this.send{value: amount_}(chainId_, escrowAddress[chainId_], abi.encode(userOp, receiver));
    }}

    // function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
    // internal view override returns (bytes memory context, uint256 validationData) {

    //     (userOpHash);
    //     // verificationGasLimit is dual-purposed, as gas limit for postOp. make sure it is high enough
    //     require(userOp.verificationGasLimit > COST_OF_POST, "DepositPaymaster: gas too low for postOp");

    //     bytes calldata paymasterAndData = userOp.paymasterAndData;
    //     require(paymasterAndData.length == 20+20, "DepositPaymaster: paymasterAndData must specify token");
    //     IERC20 token = IERC20(address(bytes20(paymasterAndData[20:])));
    //     address account = userOp.getSender();
    //     uint256 maxTokenCost = getTokenValueOfEth(token, maxCost);
    //     uint256 gasPriceUserOp = userOp.gasPrice();
    //     require(unlockBlock[account] == 0, "DepositPaymaster: deposit not locked");
    //     require(balances[token][account] >= maxTokenCost, "DepositPaymaster: deposit too low");
    //     return (abi.encode(account, token, gasPriceUserOp, maxTokenCost, maxCost),0);
    // }

    fallback() external payable {}

    error InvalidChainId(uint64 chainId);
    error InvalidOrigin(address bundler);
    error InvalidAsset(uint64 chainId, address asset);
    error InvalidDataLength(uint256 dataLength);
}