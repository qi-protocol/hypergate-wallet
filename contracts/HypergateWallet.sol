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
    uint256 _nonce;
    address _owner;

    modifier onlyOwner() {
        require(msg.sender == _owner);
        _;
    }

    function initialize(
        address owner_,
        address singleton_
    ) external initializer {
        _owner = owner_;
        bytes32 singleton = bytes32(uint256(uint160(singleton_)));
        assembly {
            sstore(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc, singleton)
        }
    }

    function transferOwnership(address to) external onlyOwner {
        _owner = to;
    }

    function createWallet(address target, bytes memory data, uint256 amount, uint256 gas) external payable returns(address) {
        uint256 dataStart = 4 + 3 * 32; // function selector + 3 parameters of 32 bytes each

        // Calculate the starting position of the actual data (skipping the length)
        uint256 actualDataStart = dataStart + 32;

        // Calculate the length of the actual data
        uint256 dataLength = data.length;

        // Allocate memory for the actual data
        bytes memory payload = new bytes(dataLength);

        // Copy the actual data from calldata to memory
        assembly {
            calldatacopy(add(payload, 32), actualDataStart, dataLength)
        }

        // Execute the function call using the payload
        bool success;
        bytes memory receipt;
        (success, receipt) = payable(target).call(data);
        require(success, "Wallet creation failed");
        address walletAddress;
        assembly {
            walletAddress := mload(add(receipt, 0x20))
        }
        _wallet[_nonce] = Wallet(walletAddress, target, tx.origin, block.timestamp, 0, amount);
        _nonce++;
        return walletAddress;
    }

    function getWalletAddress(address target, bytes calldata data) external {
        (bool success, bytes memory receipt) = target.call(data);
        require(success, "Wallet creation failed");
        address walletAddress = address(bytes20(receipt));
        bool initalized;
        assembly { initalized := iszero(iszero(extcodesize(walletAddress))) }
        bytes memory revert_ = abi.encode(walletAddress, initalized);
        assembly {
            revert(0, revert_)
        }
    }

    function getWallet(uint256 nonce_) external view returns(Wallet memory) {
        return _wallet[nonce_];
    }

    function getNonce() external virtual view returns(uint256) {
        return _nonce;
    }

    function execute(
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

    function safeExecute(
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

    function executeWithHook(
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

    function safeExecuteWithHook(
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

    fallback() external payable {}

    // revert call wallet
    // fallback() external payable {
    //     // all requests are forwarded to the fallback contract use STATICCALL
    //     assembly {
    //         /* not memory-safe */
    //         calldatacopy(0, 0, calldatasize())
    //         let result := staticcall(gas(), fallbackContract, 0, calldatasize(), 0, 0)
    //         returndatacopy(0, 0, returndatasize())
    //         switch result
    //         case 0 { revert(0, returndatasize()) }
    //         default { return(0, returndatasize()) }
    //     }
    // }
}