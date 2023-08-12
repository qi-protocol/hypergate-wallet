// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

contract HypergatWalletFactory {
    struct Wallet {
        uint256 timestamp;
        uint256 nonce;
        uint256 walletType;
        uint256 walletSubType;
    }

    struct Hook {
        uint256 gasLimit;
        uint256 amount;
        address target;
        bytes data;
    }

    mapping(address => Wallet) account;
    mapping(address => uint256) nonce;

    function createWallet(address target, bytes calldata data, uint256 amount, uint256 gas) external payable returns(address) {
        (bool success, bytes memory receipt) = target.call{value: amount, gas: gas}(data);
        require(success, "Wallet creation failed");
        return address(bytes20(receipt));
    }

    function getWalletAddress(address target, bytes calldata data) external returns(address walletAddress, bool initalized) {
        (bool success, bytes memory receipt) = target.call(data);
        require(success, "Wallet creation failed");
        walletAddress = address(bytes20(receipt));
        assembly { initalized := extcodesize(walletAddress) }
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
}