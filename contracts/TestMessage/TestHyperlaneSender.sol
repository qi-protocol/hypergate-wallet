// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

//import "hardhat/console.sol";

// destinationDomain:
// mumbai: 80001
// sepoli: 11155111

// mailbox:
// mumbai: 0xCC737a94FecaeC165AbCf12dED095BB13F037685
// sepolia: 0xCC737a94FecaeC165AbCf12dED095BB13F037685

// defaultInterchainGasPaymaster:
// mumbai: 0xF90cB82a76492614D07B82a7658917f3aC811Ac1
// sepolia: 0xF987d7edcb5890cB321437d8145E3D51131298b6

// interchainGasPaymaster:
// mumbai: 0x8f9C3888bFC8a5B25AED115A82eCbb788b196d2a
// sepolia: 0x8f9C3888bFC8a5B25AED115A82eCbb788b196d2a

// polygon test recipient: 0x941541c2aCF106234263e6F379FB79e98beed187
// msg.value: 200000000000000000 (0.2 ETH)
// destination: 80001
// recipient: 0x941541c2aCF106234263e6F379FB79e98beed187
// body1: 0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000c68656c6c6f20776f726c64210000000000000000000000000000000000000000
// body2: 0x1fad948c0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000ff65689a4aeb6eadd18cad2de0022f8aa18b67de0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000052eb5d94da6146836b0a6c542b69545dd35fda6d0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000030d4000000000000000000000000000000000000000000000000000000000000186a000000000000000000000000000000000000000000000000000000000000186a0000000000000000000000000000000000000000000000000000000000393870000000000000000000000000000000000000000000000000000000000039387000000000000000000000000000000000000000000000000000000000000000340000000000000000000000000000000000000000000000000000000000000036000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000184b61d27f6000000000000000000000000c532a74256d3db42d0bf7a0400fefdbad769400800000000000000000000000000000000000000000000000000038d7ea4c68000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e47ff36ab50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000052eb5d94da6146836b0a6c542b69545dd35fda6d00000000000000000000000000000000000000000000000000000000669e545500000000000000000000000000000000000000000000000000000000000000020000000000000000000000007b79995e5f793a07bc00c21412e50ecae098e7f9000000000000000000000000ae0086b0f700d6d7d4814c4ba1e55d3bc0dfee02000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041bcce576dda7131ce526353d5e0f82e22ef56c41edd3fed365f6dae1a179f8f506a6de5c0c66f80c86e804dcfbc0a2a509bacb6d8d1a51e9b5509ae79031fd7441c00000000000000000000000000000000000000000000000000000000000000
//        https://mumbai.polygonscan.com/address/0x941541c2acf106234263e6f379fb79e98beed187#readContract#F1

interface IMailbox {
    function dispatch( uint32 _destinationDomain, bytes32 _recipientAddress, bytes calldata _messageBody) external returns (bytes32);
}

// The amount of gas that the recipient contract consumes on the destination
// chain when handling a message from this origin chain.
contract SendTest {
    uint256 gasAmount = 100000;
    address igp;
    address mailbox;

    constructor(address igp_, address mailbox_) {
        igp = igp_;
        mailbox = mailbox_;
    }

    function setAddresses(address igp_, address mailbox_) public {
        igp = igp_;
        mailbox = mailbox_;
    }

    function messageToBytes(string memory message) public pure returns(bytes memory) {
        return abi.encode(message);
    }

    function bytesToMessage(bytes memory message) public pure returns(string memory) {
        return abi.decode(message, (string));
    }

    function testAddress(address input) public pure returns(bytes32) {
        return bytes32(uint256(uint160(input)));
    }

    function sendAndPayForMessage(
        uint32 destination_, 
        address recipient_, 
        bytes memory body_,
        uint256 gas_
        ) external payable {

        bool success;
        bytes memory receipt;
        bytes memory payload;
        bytes32 messageId;

        // send message
        // payload = abi.encodeWithSignature(
        //     "dispatch(uint32,bytes32,bytes)",
        //     destination_,
        //     bytes32(uint256(uint160(recipient_))),
        //     body_
        // );
        // (success, receipt) = mailbox.call{gas: gas_}(payload);
        messageId = IMailbox(mailbox).dispatch(
            destination_,
            bytes32(uint256(uint160(recipient_))),
            body_
        );
        // messageId = bytes32(receipt);

        // pay for message
        payload = abi.encodeWithSignature(
            "payForGas(bytes32,uint32,uint256,address)",
            messageId,
            destination_,
            gasAmount,
            msg.sender
        );
        (success, receipt) = igp.call{value: msg.value}(payload);
    }

    function sendMessage(
        uint32 destination_, 
        address recipient_, 
        bytes memory body_,
        uint256 gas_
        ) public returns(bytes32) {

        bool success;
        bytes memory receipt;
        bytes memory payload;
        bytes32 messageId;

        // send message
        // payload = abi.encodeWithSelector(
        //     bytes4(0x6c0814da),
        //     destination_,
        //     bytes32(uint256(uint160(recipient_))),
        //     body_
        // );
        // (success, receipt) = mailbox.call{gas: gas_}(payload);
        messageId = IMailbox(mailbox).dispatch(
            destination_,
            bytes32(uint256(uint160(recipient_))),
            body_
        );
        return messageId;
        // messageId = bytes32(receipt);
    }

    function payForMessage(
        uint32 destination_, 
        bytes32 messageId,
        uint256 gas_
        ) external payable returns(bool) {

        bool success;
        bytes memory receipt;
        bytes memory payload;
        // pay for message
        payload = abi.encodeWithSignature(
            "payForGas(bytes32,uint32,uint256,address)",
            messageId,
            destination_,
            gasAmount,
            msg.sender
        );
        (success, receipt) = igp.call{gas: gas_, value: msg.value}(payload);
        return success;
    }

    function checkBytes4(string memory message) public pure returns(bytes4) {
        return bytes4(keccak256(abi.encode(message)));
    }
}