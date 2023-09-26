// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

//import {IMailbox, IIGP, TestPaymaster, IEntryPoint} from "flat/TestPaymaster2_f.sol";
//import "contracts/interfaces/ITestEscrow.sol";

import {IEntryPoint, EntryPoint, IAccount} from "@4337/core/EntryPoint.sol";
import {SimpleAccount, SimpleAccountFactory} from "@4337/samples/SimpleAccountFactory.sol";
import {TestPaymaster} from "contracts/TestPaymaster.sol";
import {TestEscrow} from "contracts/TestEscrow.sol";
import "contracts/interfaces/ITestEscrow.sol";

/**
What I need
- Paymaster needs to be deployed
- The paymaster need to have BOTH deposited and staked funds in the EntryPoint
- Test is paymaster works locally with normal transactions
- Escrow test already works
- Test Hyperlane live transactions (easier since hyperlane Mumbai/sepolia doesn’t need payment)
- If all works, make it reproducible with instructions
- Make a video of stepping though the process
- Post video to my YouTube and share it (less than 3 mins)
 */

 contract LoadKey is Test {

    address eoaAddress;
    bytes32 internal key_bytes;
    uint256 internal privateKey;

    function setup() public virtual {
        // setup private key
        string memory key = vm.readFile(".secret");
        key_bytes = vm.parseBytes32(key);
        assembly {
            sstore(privateKey.slot, sload(key_bytes.slot))
        }
        eoaAddress = vm.addr(privateKey);
    }

 }