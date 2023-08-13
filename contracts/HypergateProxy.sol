// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

contract HypergateProxy {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1
     */
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Initializes the contract setting the implementation
     *
     * @param logic Address of the initial implementation.
     */
    constructor(address logic) {
        assembly ("memory-safe") {
            sstore(_IMPLEMENTATION_SLOT, logic)
        }
    }

    /**
     * @dev Fallback function: modified to always delegate, even on fail
     * If the degation fails, it's up to the external wallet to handle
     * coincidently that means all txs are success and response must be handled
     * via an offchain system (error log)
     */
    fallback() external payable {
        assembly {
            /* not memory-safe */
            let _singleton := and(sload(_IMPLEMENTATION_SLOT), 0xffffffffffffffffffffffffffffffffffffffff)
            calldatacopy(0, 0, calldatasize())
            pop(delegatecall(gas(), _singleton, 0, calldatasize(), 0, 0))
            return(0, returndatasize())
        }
    }
}
