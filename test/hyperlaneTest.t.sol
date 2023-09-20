// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import {Vm as vm} from "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";

import {IMailbox, IIGP, TestPaymaster, IEntryPoint} from "flat/TestPaymaster2_f.sol";

contract Deploy is Test {
    address internal eoaAddress;

    uint256[2] internal publicKey;
    string internal constant SIGNER_1 = "1";

    uint32 _originDomain = 11155111;
    uint32 _desitinationDomain = 80001;

    address recipient = 0x5A3f58B9EbC47013902301f821Ad2A52Da19daD8; // escrow
    address mailbox = 0xCC737a94FecaeC165AbCf12dED095BB13F037685;
    address igp = 0x8f9C3888bFC8a5B25AED115A82eCbb788b196d2a;
    address simpleAccountFactory = 
}