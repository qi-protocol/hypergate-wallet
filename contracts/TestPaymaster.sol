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
    mapping(uint64 => address) paymasterAddress;
    
    bytes4 _selector;
    address ccip_router;

    constructor(IEntryPoint entryPoint_, address ccip_router_) BasePaymaster(entryPoint_) {
        _selector = bytes4(keccak256("HandleMessage(bytes)"));
        ccip_router = ccip_router_;
    }

    function getPaymasterAddress(uint64 chainId) public view returns(address) {
        return paymasterAddress[chainId];
    }

    function addPaymaster(uint64 chainId, address paymasterAddress_) public onlyOwner {
        paymasterAddress[chainId] = paymasterAddress_;
    }

    function send(
        uint64 destinationChainSelector,
        address receiver,
        bytes memory data
    ) external payable returns (bytes32 messageId) {
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
        // send with hash and signature
        bytes calldata data = userOp.paymasterAndData;
        uint256 paymasterAndDataLength = data.length;
        require(paymasterAndDataLength == 0 || paymasterAndDataLength < 100,
            "TPM: invalid data length"
        );

        // deserialize PaymasterAndData (paymaster, chainid, target, owner, amount)
        //bytes20, bytes8, bytes20, bytes20, bytes32 = 100 bytes
        address paymaster_ = address(bytes20(data[:20]));
        uint64 chainId_ = uint64(bytes8(data[20:28]));
        address target_ = address(bytes20(data[28:48]));
        address owner_ = address(bytes20(data[48:68]));
        uint256 amount_ = uint256(bytes32(data[68:100]));

        this.send{value: amount_}(chainId_, target_, abi.encode(userOp));
    }}

    function withdraw(address target) public onlyOwner() {
        payable(target).call{value: address(this).balance}("");
    }

    fallback() external payable {}
}