// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "lib/openzeppelin-contracts/contracts/utils/Create2.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

contract HypergateWallet is Initializable {
    struct Wallet {
        address wallet;
        address walletType;
        address initializer;
        uint256 timestamp;
        uint256 walletSubType;
        uint256 cost;
    }

    struct Hook {
        uint256 gasLimit;
        uint256 amount;
        address target;
        bytes data;
    }

    mapping(uint256 => Wallet) _wallet;
    uint256 nonce;

    function initialize(
        address owner_
    ) external initializer {
        _addOwner(owner_);
    }

    function createWallet(address target, bytes calldata data, uint256 amount, uint256 gas) external payable returns(address) {
        (bool success, bytes memory receipt) = target.call{value: amount, gas: gas}(data);
        require(success, "Wallet creation failed");
        _wallet[nonce] = Wallet(address(bytes20(receipt)), target, tx.origin, block.timestamp, uint256(data[4:]), amount);
        return address(bytes20(receipt));
    }

    function getWalletAddress(address target, bytes calldata data) external returns(address walletAddress, bool initalized) {
        (bool success, bytes memory receipt) = target.call(data);
        require(success, "Wallet creation failed");
        walletAddress = address(bytes20(receipt));
        assembly { initalized := extcodesize(walletAddress) }
    }

    function getWallet(uint256 nonce_) external view returns(Wallet memory) {
        return _wallet[nonce_];
    }

    function getNonce() external virtual view returns(uint256) {
        return nonce;
    }

    function Execute(
        uint256 gasLimit,
        uint256 amount,
        address target,
        bytes calldata data
        ) external payable returns(bool) {
            (bool success,) = payable(target).call{
                gas: gasLimit,
                value: amount
                }(data);
            return success;
    }

    function SafeExecute(
        uint256 gasLimit,
        uint256 amount,
        address target, 
        bytes calldata data
    ) external payable {
        (bool success, bytes memory receipt) = payable(target).call{
            gas: gasLimit,
            value: amount
            }(data);
        if(!success) {
            revert ExecuteFailed(target, receipt);
        }
    }

    function ExecuteWithHook(
        uint256 gasLimit,
        uint256 amount,
        address target,
        bytes calldata data, 
        Hook[] calldata beforeExecute,
        Hook[] calldata afterExecute
        ) external payable returns(bool) {
            if(beforeExecute.length != 0) {
                _executeHook(beforeExecute);
            }
            (bool success,) = payable(target).call{
                gas: gasLimit,
                value: amount
                }(data);
            if(afterExecute.length != 0) {
                _executeHook(afterExecute);
            }
            return success;
    }

    function SafeExecuteWithHook(
        uint256 gasLimit,
        uint256 amount,
        address target, 
        bytes calldata data, 
        Hook[] calldata beforeExecute,
        Hook[] calldata afterExecute
    ) external payable {
        if(beforeExecute.length != 0) {
                _executeHook(beforeExecute);
        }
        (bool success, bytes memory receipt) = payable(target).call{
            gas: gasLimit,
            value: amount
            }(data);
        if(afterExecute.length != 0) {
            _executeHook(afterExecute);
        }
        if(!success) {
            revert ExecuteFailed(target, receipt);
        }
    }

    function _executeHook(Hook[] calldata hook) internal {
        uint256 size = hook.length;
        bool success;
        bytes memory receipt;
        for(uint256 i; i<size; i++) {
            (success, receipt) = payable(hook[i].target).call{
                gas: hook[i].gasLimit,
                value: hook[i].amount
                }(hook[i].data);
        }
    }

    function _safeExecuteHook(Hook[] calldata hook) internal {
        uint256 size = hook.length;
        bool success;
        bytes memory receipt;
        uint256 _gas = gasleft();
        for(uint256 i; i<size; i++) {
            _gas = gasleft();
            if(_gas < hook[i].gasLimit) {
                revert GasError(i);
            }
            (success, receipt) = payable(hook[i].target).call{
                gas: hook[i].gasLimit,
                value: hook[i].amount
                }(hook[i].data);
            if(!success) {
                revert HookReverted(i, receipt);
            }
        }
    }

    error ExecuteFailed(address target, bytes data);
    error GasError(uint256 index);
    error HookReverted(uint256 index, bytes data);

    // revert call wallet
    fallback() external payable {
        // all requests are forwarded to the fallback contract use STATICCALL
        assembly {
            /* not memory-safe */
            calldatacopy(0, 0, calldatasize())
            let result := staticcall(gas(), fallbackContract, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}