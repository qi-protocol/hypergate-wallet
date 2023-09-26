// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "forge-std/console.sol";

contract TestL1L1Message is Test{
    // broadcast
    // just deploy escrow on origin chain
    // directly call cciprouter from execution chain
    // need to have dumbed dowed call
    // need to at some point have contracts already deployed to avoid wasting test eth
    function testSimpleMessage() public {
        //
    }
    
    function testDirectCall() public {
        //vm.chainId(chainId_1);
        string memory key = vm.readFile(".secret");
        bytes32 key_bytes = vm.parseBytes32(key);
        uint256 privateKey;
        assembly {
            privateKey := key_bytes
        }

        vm.broadcast();
        // need to fix the entrypoint call to see if calling from entrypoint is appropiate
        // figure out how to call contract on specific chain via vm
        // figure out how to store the contracts of interest in a file to call upon (not env)
        // need contracts to talk to 
        // deploy escrow on goerli
        // deploy paymaster on sepolia
        // call paymaster > call ccip > call 
    }
}