// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;
/**
 * returned data from validateUserOp.
 * validateUserOp returns a uint256, with is created by `_packedValidationData` and parsed by `_parseValidationData`
 * @param aggregator - address(0) - the account validated the signature by itself.
 *              address(1) - the account failed to validate the signature.
 *              otherwise - this is an address of a signature aggregator that must be used to validate the signature.
 * @param validAfter - this UserOp is valid only after this timestamp.
 * @param validaUntil - this UserOp is valid only up to this timestamp.
 */
    struct ValidationData {
        address aggregator;
        uint48 validAfter;
        uint48 validUntil;
    }

//extract sigFailed, validAfter, validUntil.
// also convert zero validUntil to type(uint48).max
    function _parseValidationData(uint validationData) pure returns (ValidationData memory data) {
        address aggregator = address(uint160(validationData));
        uint48 validUntil = uint48(validationData >> 160);
        if (validUntil == 0) {
            validUntil = type(uint48).max;
        }
        uint48 validAfter = uint48(validationData >> (48 + 160));
        return ValidationData(aggregator, validAfter, validUntil);
    }

// intersect account and paymaster ranges.
    function _intersectTimeRange(uint256 validationData, uint256 paymasterValidationData) pure returns (ValidationData memory) {
        ValidationData memory accountValidationData = _parseValidationData(validationData);
        ValidationData memory pmValidationData = _parseValidationData(paymasterValidationData);
        address aggregator = accountValidationData.aggregator;
        if (aggregator == address(0)) {
            aggregator = pmValidationData.aggregator;
        }
        uint48 validAfter = accountValidationData.validAfter;
        uint48 validUntil = accountValidationData.validUntil;
        uint48 pmValidAfter = pmValidationData.validAfter;
        uint48 pmValidUntil = pmValidationData.validUntil;

        if (validAfter < pmValidAfter) validAfter = pmValidAfter;
        if (validUntil > pmValidUntil) validUntil = pmValidUntil;
        return ValidationData(aggregator, validAfter, validUntil);
    }

/**
 * helper to pack the return value for validateUserOp
 * @param data - the ValidationData to pack
 */
    function _packValidationData(ValidationData memory data) pure returns (uint256) {
        return uint160(data.aggregator) | (uint256(data.validUntil) << 160) | (uint256(data.validAfter) << (160 + 48));
    }

/**
 * helper to pack the return value for validateUserOp, when not using an aggregator
 * @param sigFailed - true for signature failure, false for success
 * @param validUntil last timestamp this UserOperation is valid (or zero for infinite)
 * @param validAfter first timestamp this UserOperation is valid
 */
    function _packValidationData(bool sigFailed, uint48 validUntil, uint48 validAfter) pure returns (uint256) {
        return (sigFailed ? 1 : 0) | (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48));
    }

/**
 * keccak function over calldata.
 * @dev copy calldata into memory, do keccak and drop allocated memory. Strangely, this is more efficient than letting solidity do it.
 */
    function calldataKeccak(bytes calldata data) pure returns (bytes32 ret) {
        assembly {
            let mem := mload(0x40)
            let len := data.length
            calldatacopy(mem, data.offset, len)
            ret := keccak256(mem, len)
        }
    }

/**
 * User Operation struct
 * @param sender the sender account of this request.
     * @param nonce unique value the sender uses to verify it is not a replay.
     * @param initCode if set, the account contract will be created by this constructor/
     * @param callData the method call to execute on this account.
     * @param callGasLimit the gas limit passed to the callData method call.
     * @param verificationGasLimit gas used for validateUserOp and validatePaymasterUserOp.
     * @param preVerificationGas gas not calculated by the handleOps method, but added to the gas paid. Covers batch overhead.
     * @param maxFeePerGas same as EIP-1559 gas parameter.
     * @param maxPriorityFeePerGas same as EIP-1559 gas parameter.
     * @param paymasterAndData if set, this field holds the paymaster address and paymaster-specific data. the paymaster will pay for the transaction instead of the sender.
     * @param signature sender-verified signature over the entire request, the EntryPoint address and the chain ID.
     */
    struct UserOperation {

        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes paymasterAndData;
        bytes signature;
    }

/**
 * Utility functions helpful when working with UserOperation structs.
 */
library UserOperationLib {

    function getSender(UserOperation calldata userOp) internal pure returns (address) {
        address data;
        //read sender from userOp, which is first userOp member (saves 800 gas...)
        assembly {data := calldataload(userOp)}
        return address(uint160(data));
    }

    //relayer/block builder might submit the TX with higher priorityFee, but the user should not
    // pay above what he signed for.
    function gasPrice(UserOperation calldata userOp) internal view returns (uint256) {
    unchecked {
        uint256 maxFeePerGas = userOp.maxFeePerGas;
        uint256 maxPriorityFeePerGas = userOp.maxPriorityFeePerGas;
        if (maxFeePerGas == maxPriorityFeePerGas) {
            //legacy mode (for networks that don't support basefee opcode)
            return maxFeePerGas;
        }
        return min(maxFeePerGas, maxPriorityFeePerGas + block.basefee);
    }
    }

    function pack(UserOperation calldata userOp) internal pure returns (bytes memory ret) {
        address sender = getSender(userOp);
        uint256 nonce = userOp.nonce;
        bytes32 hashInitCode = calldataKeccak(userOp.initCode);
        bytes32 hashCallData = calldataKeccak(userOp.callData);
        uint256 callGasLimit = userOp.callGasLimit;
        uint256 verificationGasLimit = userOp.verificationGasLimit;
        uint256 preVerificationGas = userOp.preVerificationGas;
        uint256 maxFeePerGas = userOp.maxFeePerGas;
        uint256 maxPriorityFeePerGas = userOp.maxPriorityFeePerGas;
        bytes32 hashPaymasterAndData = calldataKeccak(userOp.paymasterAndData);

        return abi.encode(
            sender, nonce,
            hashInitCode, hashCallData,
            callGasLimit, verificationGasLimit, preVerificationGas,
            maxFeePerGas, maxPriorityFeePerGas,
            hashPaymasterAndData
        );
    }

    function hash(UserOperation calldata userOp) internal pure returns (bytes32) {
        return keccak256(pack(userOp));
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);

  function approve(address spender, uint256 value) external returns (bool success);

  function balanceOf(address owner) external view returns (uint256 balance);

  function decimals() external view returns (uint8 decimalPlaces);

  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

  function increaseApproval(address spender, uint256 subtractedValue) external;

  function name() external view returns (string memory tokenName);

  function symbol() external view returns (string memory tokenSymbol);

  function totalSupply() external view returns (uint256 totalTokensIssued);

  function transfer(address to, uint256 value) external returns (bool success);

  function transferAndCall(
    address to,
    uint256 value,
    bytes calldata data
  ) external returns (bool success);

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool success);
}

// End consumer library.
library Client {
  struct EVMTokenAmount {
    address token; // token address on the local chain.
    uint256 amount; // Amount of tokens.
  }

  struct Any2EVMMessage {
    bytes32 messageId; // MessageId corresponding to ccipSend on source.
    uint64 sourceChainSelector; // Source chain selector.
    bytes sender; // abi.decode(sender) if coming from an EVM chain.
    bytes data; // payload sent in original message.
    EVMTokenAmount[] destTokenAmounts; // Tokens and their amounts in their destination chain representation.
  }

  // If extraArgs is empty bytes, the default is 200k gas limit and strict = false.
  struct EVM2AnyMessage {
    bytes receiver; // abi.encode(receiver address) for dest EVM chains
    bytes data; // Data payload
    EVMTokenAmount[] tokenAmounts; // Token transfers
    address feeToken; // Address of feeToken. address(0) means you will send msg.value.
    bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV1)
  }

  // extraArgs will evolve to support new features
  // bytes4(keccak256("CCIP EVMExtraArgsV1"));
  bytes4 public constant EVM_EXTRA_ARGS_V1_TAG = 0x97a657c9;
  struct EVMExtraArgsV1 {
    uint256 gasLimit; // ATTENTION!!! MAX GAS LIMIT 4M FOR BETA TESTING
    bool strict; // See strict sequencing details below.
  }

  function _argsToBytes(EVMExtraArgsV1 memory extraArgs) internal pure returns (bytes memory bts) {
    return abi.encodeWithSelector(EVM_EXTRA_ARGS_V1_TAG, extraArgs);
  }
}

interface IRouterClient {
  error UnsupportedDestinationChain(uint64 destChainSelector);
  error InsufficientFeeTokenAmount();
  error InvalidMsgValue();

  /// @notice Checks if the given chain ID is supported for sending/receiving.
  /// @param chainSelector The chain to check.
  /// @return supported is true if it is supported, false if not.
  function isChainSupported(uint64 chainSelector) external view returns (bool supported);

  /// @notice Gets a list of all supported tokens which can be sent or received
  /// to/from a given chain id.
  /// @param chainSelector The chainSelector.
  /// @return tokens The addresses of all tokens that are supported.
  function getSupportedTokens(uint64 chainSelector) external view returns (address[] memory tokens);

  /// @param destinationChainSelector The destination chainSelector
  /// @param message The cross-chain CCIP message including data and/or tokens
  /// @return fee returns guaranteed execution fee for the specified message
  /// delivery to destination chain
  /// @dev returns 0 fee on invalid message.
  function getFee(
    uint64 destinationChainSelector,
    Client.EVM2AnyMessage memory message
  ) external view returns (uint256 fee);

  /// @notice Request a message to be sent to the destination chain
  /// @param destinationChainSelector The destination chain ID
  /// @param message The cross-chain CCIP message including data and/or tokens
  /// @return messageId The message ID
  /// @dev Note if msg.value is larger than the required fee (from getFee) we accept
  /// the overpayment with no refund.
  function ccipSend(
    uint64 destinationChainSelector,
    Client.EVM2AnyMessage calldata message
  ) external payable returns (bytes32);
}

interface OwnableInterface {
  function owner() external returns (address);

  function transferOwnership(address recipient) external;

  function acceptOwnership() external;
}

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwnerWithProposal is OwnableInterface {
  address private s_owner;
  address private s_pendingOwner;

  event OwnershipTransferRequested(address indexed from, address indexed to);
  event OwnershipTransferred(address indexed from, address indexed to);

  constructor(address newOwner, address pendingOwner) {
    require(newOwner != address(0), "Cannot set owner to zero");

    s_owner = newOwner;
    if (pendingOwner != address(0)) {
      _transferOwnership(pendingOwner);
    }
  }

  /**
   * @notice Allows an owner to begin transferring ownership to a new address,
   * pending.
   */
  function transferOwnership(address to) public override onlyOwner {
    _transferOwnership(to);
  }

  /**
   * @notice Allows an ownership transfer to be completed by the recipient.
   */
  function acceptOwnership() external override {
    require(msg.sender == s_pendingOwner, "Must be proposed owner");

    address oldOwner = s_owner;
    s_owner = msg.sender;
    s_pendingOwner = address(0);

    emit OwnershipTransferred(oldOwner, msg.sender);
  }

  /**
   * @notice Get the current owner
   */
  function owner() public view override returns (address) {
    return s_owner;
  }

  /**
   * @notice validate, transfer ownership, and emit relevant events
   */
  function _transferOwnership(address to) private {
    require(to != msg.sender, "Cannot transfer to self");

    s_pendingOwner = to;

    emit OwnershipTransferRequested(s_owner, to);
  }

  /**
   * @notice validate access
   */
  function _validateOwnership() internal view {
    require(msg.sender == s_owner, "Only callable by owner");
  }

  /**
   * @notice Reverts if called by anyone other than the contract owner.
   */
  modifier onlyOwner() {
    _validateOwnership();
    _;
  }
}

/**
 * @title The ConfirmedOwner contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract ConfirmedOwner is ConfirmedOwnerWithProposal {
  constructor(address newOwner) ConfirmedOwnerWithProposal(newOwner, address(0)) {}
}

/// @title The OwnerIsCreator contract
/// @notice A contract with helpers for basic contract ownership.
contract OwnerIsCreator is ConfirmedOwner {
  constructor() ConfirmedOwner(msg.sender) {}
}

// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
  /**
   * @dev Emitted when `value` tokens are moved from one account (`from`) to
   * another (`to`).
   *
   * Note that `value` may be zero.
   */
  event Transfer(address indexed from, address indexed to, uint256 value);

  /**
   * @dev Emitted when the allowance of a `spender` for an `owner` is set by
   * a call to {approve}. `value` is the new allowance.
   */
  event Approval(address indexed owner, address indexed spender, uint256 value);

  /**
   * @dev Returns the amount of tokens in existence.
   */
  function totalSupply() external view returns (uint256);

  /**
   * @dev Returns the amount of tokens owned by `account`.
   */
  function balanceOf(address account) external view returns (uint256);

  /**
   * @dev Moves `amount` tokens from the caller's account to `to`.
   *
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * Emits a {Transfer} event.
   */
  function transfer(address to, uint256 amount) external returns (bool);

  /**
   * @dev Returns the remaining number of tokens that `spender` will be
   * allowed to spend on behalf of `owner` through {transferFrom}. This is
   * zero by default.
   *
   * This value changes when {approve} or {transferFrom} are called.
   */
  function allowance(address owner, address spender) external view returns (uint256);

  /**
   * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
   *
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * IMPORTANT: Beware that changing an allowance with this method brings the risk
   * that someone may use both the old and the new allowance by unfortunate
   * transaction ordering. One possible solution to mitigate this race
   * condition is to first reduce the spender's allowance to 0 and set the
   * desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   *
   * Emits an {Approval} event.
   */
  function approve(address spender, uint256 amount) external returns (bool);

  /**
   * @dev Moves `amount` tokens from `from` to `to` using the
   * allowance mechanism. `amount` is then deducted from the caller's
   * allowance.
   *
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * Emits a {Transfer} event.
   */
  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) external returns (bool);
}

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract Withdraw is OwnerIsCreator {
    error FailedToWithdrawEth(address owner, address target, uint256 value);

    function withdraw(address beneficiary) public onlyOwner {
        uint256 amount = address(this).balance;
        (bool sent, ) = beneficiary.call{value: amount}("");
        if (!sent) revert FailedToWithdrawEth(msg.sender, beneficiary, amount);
    }

    function withdrawToken(
        address beneficiary,
        address token
    ) public onlyOwner {
        uint256 amount = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(beneficiary, amount);
    }
}

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */
contract BasicMessageSender is Withdraw {
    enum PayFeesIn {
        Native,
        LINK
    }

    address immutable i_router;
    address immutable i_link;

    event MessageSent(bytes32 messageId);

    constructor(address router, address link) {
        i_router = router;
        i_link = link;
        LinkTokenInterface(i_link).approve(i_router, type(uint256).max);
    }

    receive() external payable {}

    function send(
        uint64 destinationChainSelector,
        address receiver,
        string memory messageText,
        PayFeesIn payFeesIn
    ) external returns (bytes32 messageId) {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(messageText),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: payFeesIn == PayFeesIn.LINK ? i_link : address(0)
        });

        uint256 fee = IRouterClient(i_router).getFee(
            destinationChainSelector,
            message
        );

        if (payFeesIn == PayFeesIn.LINK) {
            //  LinkTokenInterface(i_link).approve(i_router, fee);
            messageId = IRouterClient(i_router).ccipSend(
                destinationChainSelector,
                message
            );
        } else {
            messageId = IRouterClient(i_router).ccipSend{value: fee}(
                destinationChainSelector,
                message
            );
        }

        emit MessageSent(messageId);
    }
}

// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// OpenZeppelin Contracts (last updated v4.9.0) (utils/Strings.sol)

// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1, "Math: mulDiv overflow");

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}

// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SignedMath.sol)

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toString(int256 value) internal pure returns (string memory) {
        return string(abi.encodePacked(value < 0 ? "-" : "", toString(SignedMath.abs(value))));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

// OpenZeppelin Contracts (last updated v4.9.0) (utils/cryptography/ECDSA.sol)

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV // Deprecated in v4.8
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 message) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32")
            mstore(0x1c, hash)
            message := keccak256(0x00, 0x3c)
        }
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 data) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, "\x19\x01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            data := keccak256(ptr, 0x42)
        }
    }

    /**
     * @dev Returns an Ethereum Signed Data with intended validator, created from a
     * `validator` and `data` according to the version 0 of EIP-191.
     *
     * See {recover}.
     */
    function toDataWithIntendedValidatorHash(address validator, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x00", validator, data));
    }
}

// needs to recieve a message from ccip (UserOp, PaymasterAddress)
// then release locked funds
// deserialize PaymasterAndData (paymaster, chainid, target, owner, amount)
// chainid == block.chainid
// validateSignature == owner
// transfer amount to paymaster 
contract TestEscrow is Ownable {
    using UserOperationLib for UserOperation;
    using Strings for uint256;
    using ECDSA for bytes32;

    mapping(address => Escrow) _accountInfo;
    mapping(uint64 => address) _entryPoint;
    mapping(address => bool) ccipAddress;
    mapping(address => bool) layerZeroAddress;
    mapping(address => bool) hyperlaneAddress;
    mapping(address => uint256) _escrowBalance;

    address public interchainSecurityModule;

    struct Escrow {
        uint256 deadline;
        uint256 nonce;
        mapping(uint256 => Payment) history;
        mapping(address => uint256) assetBalance;
    }

    struct Payment {
        uint256 timestamp;
        uint256 assetAmount;
        uint256 id;
        uint256 chainId;
        address asset;
        address to;
    }

    struct PaymasterAndData {
        address paymaster;
        uint64 chainId;
        address asset;
        address owner;
        uint256 amount;
    }

    bool lock;
    modifier locked() {
        require(!lock, "no reentry");
        lock = true;
        _;
        lock = false;
    }

    function getBalance(address account_, address asset_) public returns(uint256) {
        return _accountInfo[account_].assetBalance[asset_];
    }

    function getDeadline(address account_) public returns(uint256) {
        return _accountInfo[account_].deadline;
    }

    function addEntryPoint(address entryPoint_, uint64 chainId_) public onlyOwner {
        _entryPoint[chainId_] = entryPoint_;
    }

    function addCCIPAddress(address ccip, bool state) public onlyOwner {
        ccipAddress[ccip] = state;
    }

    function addHyperlaneAddress(address hyperlane, bool state) public onlyOwner {
        hyperlaneAddress[hyperlane] = state;
    }

    function pack(UserOperation calldata userOp) internal pure returns (bytes memory ret) {
        address sender = getSender(userOp);
        uint256 nonce = userOp.nonce;
        bytes32 hashInitCode = calldataKeccak(userOp.initCode);
        bytes32 hashCallData = calldataKeccak(userOp.callData);
        uint256 callGasLimit = userOp.callGasLimit;
        uint256 verificationGasLimit = userOp.verificationGasLimit;
        uint256 preVerificationGas = userOp.preVerificationGas;
        uint256 maxFeePerGas = userOp.maxFeePerGas;
        uint256 maxPriorityFeePerGas = userOp.maxPriorityFeePerGas;
        bytes32 hashPaymasterAndData = calldataKeccak(userOp.paymasterAndData);

        return abi.encode(
            sender, nonce,
            hashInitCode, hashCallData,
            callGasLimit, verificationGasLimit, preVerificationGas,
            maxFeePerGas, maxPriorityFeePerGas,
            hashPaymasterAndData
        );
    }

    function hash(UserOperation calldata userOp) public pure returns (bytes32) {
        return keccak256(pack(userOp));
    }

    function calldataKeccak(bytes calldata data) public pure returns (bytes32 ret) {
        assembly {
            let mem := mload(0x40)
            let len := data.length
            calldatacopy(mem, data.offset, len)
            ret := keccak256(mem, len)
        }
    }

    function getSender(UserOperation calldata userOp) internal pure returns (address) {
        address data;
        //read sender from userOp, which is first userOp member (saves 800 gas...)
        assembly {data := calldataload(userOp)}
        return address(uint160(data));
    }

    /** @dev Deserializs userop calldata for easier integration into any dapp
      *      Warning: this function is low-level manipulation
      */
    function _decodeUserOperation() public returns (UserOperation memory) {
        bytes32 messageId;
        uint256 sourceChainSelector;
        bytes memory sender;
        address uoSender;
        uint256 uoNonce;
        bytes memory uoInitCode;
        bytes memory uoCallData;
        uint256 messageSize;
        uint256 uoCallGasLimit;
        uint256 uoVerificationGasLimit;
        uint256 uoPreVerificationGas;
        uint256 uoMaxFeePerGas;
        uint256 uoMaxPriorityFeePerGas;
        bytes memory uoPaymasterAndData;
        bytes memory uoSignature;
        uint256 dummy;
        Client.EVMTokenAmount memory destTokenAmounts;
        assembly {
            let len := mload(0x20)
            let ptr := mload(0x40)
            let offset := 0x4

            // ================================================================
            // begin deserialize CCIP message
            calldatacopy(ptr, add(offset, 0x20), 0x20)
            messageId := mload(ptr)
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0x40), 0x20)
            sourceChainSelector := mload(ptr)
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0x60), 0x20) // string size ref
            calldatacopy(ptr, add(mload(ptr), 0x4), 0x20)
            messageSize := mload(ptr) // not used
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0x80), 0x20)
            calldatacopy(len, add(sub(mload(ptr), 0x20), 0x4), 0x20)
            calldatacopy(ptr, add(mload(ptr), 0x4), mload(len))
            sender := mload(ptr)
            // ================================================================
            // begin deserialize user operation
            calldatacopy(ptr, add(offset, 0x100), 0x20)
            offset := add(offset, 0x120)
            // ----------------------------------------------------------------
            calldatacopy(ptr, offset, 0x20)
            calldatacopy(ptr, add(mload(ptr), offset), 0x20)
            uoSender := mload(ptr)
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0x40), 0x20)
            uoNonce := mload(ptr)
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0x60), 0x20)
            uoInitCode := mload(ptr) // ref
            calldatacopy(ptr, add(offset, 0x80), 0x20)
            uoCallData := mload(ptr) // ref
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0xA0), 0x20)
            uoCallGasLimit := mload(ptr)
            calldatacopy(ptr, add(offset, 0xC0), 0x20)
            uoVerificationGasLimit := mload(ptr)
            calldatacopy(ptr, add(offset, 0xE0), 0x20)
            uoPreVerificationGas := mload(ptr)
            calldatacopy(ptr, add(offset, 0x100), 0x20)
            uoMaxFeePerGas := mload(ptr)
            calldatacopy(ptr, add(offset, 0x120), 0x20)
            uoMaxPriorityFeePerGas := mload(ptr)
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0x140), 0x20)
            uoPaymasterAndData := mload(ptr) // ref
            calldatacopy(ptr, add(offset, 0x160), 0x20)
            uoSignature := mload(ptr) // ref
            // ----------------------------------------------------------------
            calldatacopy(len, add(uoInitCode, add(offset, 0x20)), 0x20)
            switch iszero(len)
            case 0 {
                calldatacopy(ptr, add(uoInitCode, add(offset, 0x40)), mload(len))
                uoInitCode := mload(ptr)
            }
            // ----------------------------------------------------------------
            calldatacopy(len, add(uoCallData, add(offset, 0x20)), 0x20)
            switch iszero(len)
            case 0 {
                //calldatacopy(ptr, add(uoCallData, add(offset, 0x20)), mload(add(len, 0x20)))
                calldatacopy(ptr, add(uoCallData, add(offset, 0x40)), mload(len))
                uoCallData := mload(ptr)
            }
            // ----------------------------------------------------------------
            calldatacopy(len, add(uoPaymasterAndData, add(offset, 0x20)), 0x20)
            switch iszero(len)
            case 0 {
                calldatacopy(ptr, add(uoPaymasterAndData, add(offset, 0x20)), add(mload(len), 0x20))
                //calldatacopy(ptr, add(uoPaymasterAndData, add(offset, 0x40)), mload(len))
                uoPaymasterAndData := mload(ptr)
                dummy := mload(ptr)
                dummy := mload(add(ptr, 0x20)) // correct
                mstore(ptr, uoPaymasterAndData)
                dummy := mload(add(ptr, 0x40)) // gave 288
            }
            // ----------------------------------------------------------------
            calldatacopy(len, add(uoSignature, add(offset, 0x20)), 0x20)
            switch iszero(len)
            case 0 {
                calldatacopy(ptr, add(uoSignature, add(offset, 0x40)), mload(len))
                uoSignature := mload(ptr)
            }
            // ================================================================
            // continue CCIP deserialization
            calldatacopy(ptr, sub(offset, 0x20), 0x20)
            offset := add(offset, mload(ptr))
            // ----------------------------------------------------------------
            calldatacopy(len, offset, 0x20)
            switch iszero(len)
            case 0 {
                calldatacopy(ptr, add(offset, 0x20), mload(len))
                destTokenAmounts := mload(ptr)
            }
            calldatacopy(len, offset, 0x20)

            
            // ================================================================
            // CCIP UserOp referance sheet
            // ================================================================
            // 0x // messageId (bytes32)
            // 0000000000000000000000000000000000000000000000000000000000000020
            // 00000000000000000000000000000000000000000000000000000000000003e8
            // sourceChainSelector
            // 000000000000000000000000000000000000000000000000b63e800d00000000
            // wtf is this? data string size ref
            // 00000000000000000000000000000000000000000000000000000000000000a0
            // sender ref
            // 00000000000000000000000000000000000000000000000000000000000000e0
            // wtf is this? data string size
            // 00000000000000000000000000000000000000000000000000000000000005a0
            // sender (message)
            // 0000000000000000000000000000000000000000000000000000000000000020
            // 7fa9385be102ac3eac297483dd6233d62b3e1496000000000000000000000000
            // ================================================================
            // data start
            // 00000000000000000000000000000000000000000000000000000000000004a0
            // ----------------------------------------------------------------
            // sender (userop)
            // 0000000000000000000000000000000000000000000000000000000000000020
            // ff65689a4aeb6eadd18cad2de0022f8aa18b67de000000000000000000000000
            // ----------------------------------------------------------------
            // nonce
            // 00000000000000000000000000000000000000000000000000000000000000f0
            // ----------------------------------------------------------------
            // initCode ref
            // 0000000000000000000000000000000000000000000000000000000000000160
            // callData ref
            // 0000000000000000000000000000000000000000000000000000000000000180
            // ----------------------------------------------------------------
            // callGasLimit
            // 0000000000000000000000000000000000000000000000000000000000989680
            // verificationGasLimit
            // 0000000000000000000000000000000000000000000000000000000001312d00
            // preVerificationGas
            // 0000000000000000000000000000000000000000000000000000000001312d00
            // maxFeePerGas
            // 0000000000000000000000000000000000000000000000000000000000000002
            // maxPriorityFeePerGas
            // 0000000000000000000000000000000000000000000000000000000000000001
            // ----------------------------------------------------------------
            // paymasterAndData ref
            // 0000000000000000000000000000000000000000000000000000000000000340
            // signature ref
            // 0000000000000000000000000000000000000000000000000000000000000400
            // ----------------------------------------------------------------
            // initCode size
            // 0000000000000000000000000000000000000000000000000000000000000000
            // ----------------------------------------------------------------
            // callData size
            // 0000000000000000000000000000000000000000000000000000000000000184
            // b61d27f6 // calldata
            // 000000000000000000000000c532a74256d3db42d0bf7a0400fefdbad7694008
            // 00000000000000000000000000000000000000000000000000038d7ea4c68000
            // 0000000000000000000000000000000000000000000000000000000000000060
            // 00000000000000000000000000000000000000000000000000000000000000e4
            // 7ff36ab500000000000000000000000000000000000000000000000000000000
            // 0000000000000000000000000000000000000000000000000000000000000000
            // 0000008000000000000000000000000052eb5d94da6146836b0a6c542b69545d
            // d35fda6d00000000000000000000000000000000000000000000000000000000
            // 669e545500000000000000000000000000000000000000000000000000000000
            // 000000020000000000000000000000007b79995e5f793a07bc00c21412e50eca
            // e098e7f9000000000000000000000000ae0086b0f700d6d7d4814c4ba1e55d3b
            // c0dfee0200000000000000000000000000000000000000000000000000000000
            // 00000000000000000000000000000000000000000000000000000000
            // ----------------------------------------------------------------
            // paymasterAndData
            // 00000000000000000000000000000000000000000000000000000000000000a0
            // 0000000000000000000000000000000000000000000000000000000000000000
            // 0000000000000000000000000000000000000000000000000000000000000000
            // 0000000000000000000000000000000000000000000000000000000000000000
            // 0000000000000000000000000000000000000000000000000000000000000000
            // 0000000000000000000000000000000000000000000000000000000000000000
            // ----------------------------------------------------------------
            // signature
            // 0000000000000000000000000000000000000000000000000000000000000041
            // 190999a8ab31185b0c415c5e1fbb48dd71429e0fee42c1d1c82bfa27b07a7097
            // 29a859e59fb4721398502b92b2ff0696ee130b489a1347182f92bfa33fd11f0f
            // 1b00000000000000000000000000000000000000000000000000000000000000
            // data end
            // ================================================================
            // destTokenAmounts
            // 0000000000000000000000000000000000000000000000000000000000000000
        }
        //revert((dummy).toString());

        return UserOperation(
            uoSender,
            uint256(uoNonce),
            uoInitCode,
            uoCallData,
            uint256(uoCallGasLimit),
            uint256(uoVerificationGasLimit),
            uint256(uoPreVerificationGas),
            uint256(uoMaxFeePerGas),
            uint256(uoMaxPriorityFeePerGas),
            uoPaymasterAndData,
            uoSignature
        );
    }

    function _decodeUserOperation(bytes memory data) public returns (UserOperation memory) {
        address uoSender;
        uint256 uoNonce;
        bytes memory uoInitCode;
        bytes memory uoCallData;
        uint256 uoCallGasLimit;
        uint256 uoVerificationGasLimit;
        uint256 uoPreVerificationGas;
        uint256 uoMaxFeePerGas;
        uint256 uoMaxPriorityFeePerGas;
        bytes memory uoPaymasterAndData;
        bytes memory uoSignature;

        assembly {
            let len := mload(0x20)
            let ptr := mload(0x40)
            let offset := 0x4

            calldatacopy(ptr, offset, 0x20)
            calldatacopy(ptr, add(mload(ptr), offset), 0x20)
            uoSender := mload(ptr)
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0x40), 0x20)
            uoNonce := mload(ptr)
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0x60), 0x20)
            uoInitCode := mload(ptr) // ref
            calldatacopy(ptr, add(offset, 0x80), 0x20)
            uoCallData := mload(ptr) // ref
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0xA0), 0x20)
            uoCallGasLimit := mload(ptr)
            calldatacopy(ptr, add(offset, 0xC0), 0x20)
            uoVerificationGasLimit := mload(ptr)
            calldatacopy(ptr, add(offset, 0xE0), 0x20)
            uoPreVerificationGas := mload(ptr)
            calldatacopy(ptr, add(offset, 0x100), 0x20)
            uoMaxFeePerGas := mload(ptr)
            calldatacopy(ptr, add(offset, 0x120), 0x20)
            uoMaxPriorityFeePerGas := mload(ptr)
            // ----------------------------------------------------------------
            calldatacopy(ptr, add(offset, 0x140), 0x20)
            uoPaymasterAndData := mload(ptr) // ref
            calldatacopy(ptr, add(offset, 0x160), 0x20)
            uoSignature := mload(ptr) // ref
            // ----------------------------------------------------------------
            calldatacopy(len, add(uoInitCode, add(offset, 0x20)), 0x20)
            switch iszero(len)
            case 0 {
                calldatacopy(ptr, add(uoInitCode, add(offset, 0x40)), mload(len))
                uoInitCode := mload(ptr)
            }
            // ----------------------------------------------------------------
            calldatacopy(len, add(uoCallData, add(offset, 0x20)), 0x20)
            switch iszero(len)
            case 0 {
                calldatacopy(ptr, add(uoCallData, add(offset, 0x40)), mload(len))
                uoCallData := mload(ptr)
            }
            // ----------------------------------------------------------------
            calldatacopy(len, add(uoPaymasterAndData, add(offset, 0x20)), 0x20)
            switch iszero(len)
            case 0 {
                calldatacopy(ptr, add(uoPaymasterAndData, add(offset, 0x40)), mload(len))
                uoPaymasterAndData := mload(ptr)
            }
            // ----------------------------------------------------------------
            calldatacopy(len, add(uoSignature, add(offset, 0x20)), 0x20)
            switch iszero(len)
            case 0 {
                calldatacopy(ptr, add(uoSignature, add(offset, 0x40)), mload(len))
                uoSignature := mload(ptr)
            }
        }

        return UserOperation(
            uoSender,
            uint256(uoNonce),
            uoInitCode,
            uoCallData,
            uint256(uoCallGasLimit),
            uint256(uoVerificationGasLimit),
            uint256(uoPreVerificationGas),
            uint256(uoMaxFeePerGas),
            uint256(uoMaxPriorityFeePerGas),
            uoPaymasterAndData,
            uoSignature
        );
    }

    /// @dev Deposit and lock in a single contract call
    function depositAndLock(
        address account_, 
        address asset_, 
        uint256 amount_, 
        uint256 seconds_, 
        bytes memory signature_
    ) public {
        deposit(account_, asset_, amount_);
        extendLock(account_, seconds_, signature_);
    }

    // extend lock by calling with value: 0, 0, 0
    /// @dev This function adds funds of amount_ of an asset_, then calls
    ///      _deposit to commit the added funds.
    function deposit(address account_, address asset_, uint256 amount_) public payable locked {
        if(asset_ != address(0)) {
            require(msg.value == 0, "non-payable when using tokens");
            bytes memory payload_ = abi.encodeWithSignature(
                "transferFrom(address,address,uint256)", 
                msg.sender, 
                address(this), 
                amount_
            );
            assembly {
                pop(call(gas(), asset_, 0, add(payload_, 0x20), mload(payload_), 0,0))
            }
        }

        _deposit(account_, asset_);
        // need to increment time deposit is locked
    }
    
    /// @dev This function traces the delta of unaccounted changes to the
    ///      escrow balances and then adds that difference to the balance of 
    ///      the owner account.
    function _deposit(address account_, address asset_) internal {
        bytes4 selector_ = bytes4(keccak256("balanceOf(address)"));
        bytes memory payload_ = abi.encodePacked(selector_, account_);
        uint256 escrowBalance_ = _escrowBalance[asset_];
        uint256 delta;
        if(asset_ == address(0)) {
            delta = address(this).balance - escrowBalance_;
        } else {
            assembly {
                pop(call(gas(), asset_, 0, add(payload_, 0x20), mload(payload_), 0, 0x20))
                returndatacopy(0, 0, 0x20)
                delta := sub(mload(0), escrowBalance_)
            }
        }

        if(delta == 0) {
            revert InvalidDeltaValue();
        }

        _accountInfo[account_].assetBalance[asset_] = _accountInfo[account_].assetBalance[asset_] + delta;
    }

    /// @dev The ability to increment lock time must be exclusive to the account owner.
    ///      This is crypographically secured.
    function extendLock(address account_, uint256 seconds_, bytes memory signature_) public {
        if(account_ == address(0)) {
            revert InvalidOwner(account_);
        }

        if(_accountInfo[account_].deadline >= block.timestamp + seconds_) {
            revert InvalidTimeInput();
        }

        bytes32 hash_ = hashSeconds(account_, seconds_);
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(hash_.toEthSignedMessageHash(), signature_);
        if (error != ECDSA.RecoverError.NoError) {
            revert BadSignature();
        }

        if(recovered != account_) {
            revert InvalidSignature(account_, recovered);
        }

        _accountInfo[account_].deadline = block.timestamp + seconds_;
    }

    function hashSeconds(address account_, uint256 seconds_) public returns(bytes32) {
        return keccak256(abi.encode(account_, seconds_));
    }

    function withdraw(address account_, address asset_, uint256 amount_) public locked {
        Escrow storage accountInfo_ = _accountInfo[account_];
        if(accountInfo_.deadline > block.timestamp) {
            revert WithdrawRejected("Too early");
        }

        bool success;
        if(asset_ == address(0)) {
            (success,) = payable(account_).call{value: amount_}("");
        } else {
            bytes memory payload_ = abi.encodeWithSignature("transferFrom(address,address,uint256)", address(this), account_, amount_);
            assembly {
                success := call(gas(), asset_, 0, add(payload_, 0x20), mload(payload_), 0,0)
            }
            
        }

        if(!success) {
            revert TransferFailed();
        }

        if(accountInfo_.assetBalance[asset_] < amount_) {
            revert WithdrawRejected("Insufficent balance");
        }

        accountInfo_.assetBalance[asset_] = accountInfo_.assetBalance[asset_] - amount_;

    }

    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata message
        ) external {

        if(!hyperlaneAddress[msg.sender]) {
            revert InvalidCCIPAddress(msg.sender);
        }

        // deserialize userop and paymasterAndData
        (UserOperation memory mUserOp, address receiver_) = abi.decode(message, (UserOperation, address));
        PaymasterAndData memory paymasterAndData = abi.decode(mUserOp.paymasterAndData, (PaymasterAndData));

        // hash userop locally
        bytes memory payload_ = abi.encodeWithSelector(bytes4(0x7b1d0da3), mUserOp);
        bytes32 userOpHash;
        assembly {
            pop(call(gas(), address(), 0, add(payload_, 0x20), mload(payload_), 0, 0x20))
            userOpHash := mload(0)
        }
        userOpHash = keccak256(abi.encode(
            userOpHash, 
            _entryPoint[paymasterAndData.chainId], 
            uint256(paymasterAndData.chainId)
        ));
        
        // validate signature
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(userOpHash.toEthSignedMessageHash(), mUserOp.signature);
        if (error != ECDSA.RecoverError.NoError) {
            revert BadSignature();
        } else {
            if(recovered != paymasterAndData.owner) {
                revert InvalidSignature(paymasterAndData.owner, recovered);
            }
        }
        //revert((uint256(uint160(paymasterAndData.owner))).toString());

        if(paymasterAndData.paymaster == address(0)) { revert InvalidPaymaster(paymasterAndData.paymaster); }
        if(paymasterAndData.chainId == uint64(0)) { revert InvalidChain(paymasterAndData.chainId); }
        if(paymasterAndData.owner == address(0)) { revert InvalidOwner(paymasterAndData.owner); }
        if(paymasterAndData.owner == address(this)) { revert InvalidOwner(paymasterAndData.owner); }

        Escrow storage accountInfo_ = _accountInfo[paymasterAndData.owner];
        if(block.timestamp > accountInfo_.deadline) { revert InvalidDeadline(""); }
        
        // revert(uint256(uint160(paymasterAndData.owner)).toString());
        // revert(uint256(_accountInfo[paymasterAndData.owner].assetBalance[paymasterAndData.asset]).toString());
        
        // Transfer amount of asset to receiver
        bool success_;
        address asset_ = paymasterAndData.asset;
        if(accountInfo_.assetBalance[asset_] < paymasterAndData.amount) { 
            revert InsufficentFunds(paymasterAndData.owner, asset_, paymasterAndData.amount);
        }

        if(asset_ == address(0)) { // address(0) == ETH
            (success_,) = payable(receiver_).call{value: paymasterAndData.amount}("");
        } else {
            // insufficent address(this) balance will auto-revert
            payload_ = abi.encodeWithSignature(
                "transferFrom(address,address,uint256)", 
                address(this), 
                receiver_, 
                paymasterAndData.amount
            );
            assembly {
                success_ := call(gas(), asset_, 0, add(payload_, 0x20), mload(payload_), 0, 0)
            }
        }
        if(!success_) { 
            revert PaymasterPaymentFailed(
                receiver_, 
                asset_, 
                paymasterAndData.owner, 
                paymasterAndData.amount
            );
        }
        accountInfo_.history[accountInfo_.nonce] = Payment(
            block.timestamp,
            paymasterAndData.amount,
            uint256(0),
            paymasterAndData.chainId,
            asset_,
            receiver_
        );
        accountInfo_.nonce++;

        uint256 escrowBalance_;
        
        if(asset_ == address(0)) {
            escrowBalance_ = address(this).balance;
        } else {
            payload_ = abi.encodeWithSignature("balanceOf(address)", address(this));
            assembly {
                pop(call(gas(), asset_, 0, add(payload_, 0x20), mload(payload_), 0, 0x20))
                returndatacopy(0, 0, 0x20)
                escrowBalance_ := mload(0)
            }
        }

        _escrowBalance[asset_] = escrowBalance_;

        emit PrintUserOp(mUserOp, paymasterAndData);
    }

    function handleMessage(Client.Any2EVMMessage memory message) payable external locked {
        if(!ccipAddress[msg.sender]) {
            revert InvalidCCIPAddress(msg.sender);
        }

        // deserialize userop and paymasterAndData
        (UserOperation memory mUserOp, address receiver_) = abi.decode(message.data, (UserOperation, address));
        PaymasterAndData memory paymasterAndData = abi.decode(mUserOp.paymasterAndData, (PaymasterAndData));

        // hash userop locally
        bytes memory payload_ = abi.encodeWithSelector(bytes4(0x7b1d0da3), mUserOp);
        bytes32 userOpHash;
        assembly {
            pop(call(gas(), address(), 0, add(payload_, 0x20), mload(payload_), 0, 0x20))
            userOpHash := mload(0)
        }
        userOpHash = keccak256(abi.encode(
            userOpHash, 
            _entryPoint[paymasterAndData.chainId], 
            uint256(paymasterAndData.chainId)
        ));
        
        // validate signature
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(userOpHash.toEthSignedMessageHash(), mUserOp.signature);
        if (error != ECDSA.RecoverError.NoError) {
            revert BadSignature();
        } else {
            if(recovered != paymasterAndData.owner) {
                revert InvalidSignature(paymasterAndData.owner, recovered);
            }
        }
        //revert((uint256(uint160(paymasterAndData.owner))).toString());

        if(paymasterAndData.paymaster == address(0)) { revert InvalidPaymaster(paymasterAndData.paymaster); }
        if(paymasterAndData.chainId == uint64(0)) { revert InvalidChain(paymasterAndData.chainId); }
        if(paymasterAndData.owner == address(0)) { revert InvalidOwner(paymasterAndData.owner); }
        if(paymasterAndData.owner == address(this)) { revert InvalidOwner(paymasterAndData.owner); }

        Escrow storage accountInfo_ = _accountInfo[paymasterAndData.owner];
        if(block.timestamp > accountInfo_.deadline) { revert InvalidDeadline(""); }
        
        // revert(uint256(uint160(paymasterAndData.owner)).toString());
        // revert(uint256(_accountInfo[paymasterAndData.owner].assetBalance[paymasterAndData.asset]).toString());
        
        // Transfer amount of asset to receiver
        bool success_;
        address asset_ = paymasterAndData.asset;
        if(accountInfo_.assetBalance[asset_] < paymasterAndData.amount) { 
            revert InsufficentFunds(paymasterAndData.owner, asset_, paymasterAndData.amount);
        }

        if(asset_ == address(0)) { // address(0) == ETH
            (success_,) = payable(receiver_).call{value: paymasterAndData.amount}("");
        } else {
            // insufficent address(this) balance will auto-revert
            payload_ = abi.encodeWithSignature(
                "transferFrom(address,address,uint256)", 
                address(this), 
                receiver_, 
                paymasterAndData.amount
            );
            assembly {
                success_ := call(gas(), asset_, 0, add(payload_, 0x20), mload(payload_), 0, 0)
            }
        }
        if(!success_) { 
            revert PaymasterPaymentFailed(
                receiver_, 
                asset_, 
                paymasterAndData.owner, 
                paymasterAndData.amount
            );
        }
        accountInfo_.history[accountInfo_.nonce] = Payment(
            block.timestamp,
            paymasterAndData.amount,
            uint256(message.messageId),
            paymasterAndData.chainId,
            asset_,
            receiver_
        );
        accountInfo_.nonce++;

        uint256 escrowBalance_;
        
        if(asset_ == address(0)) {
            escrowBalance_ = address(this).balance;
        } else {
            payload_ = abi.encodeWithSignature("balanceOf(address)", address(this));
            assembly {
                pop(call(gas(), asset_, 0, add(payload_, 0x20), mload(payload_), 0, 0x20))
                returndatacopy(0, 0, 0x20)
                escrowBalance_ := mload(0)
            }
        }

        _escrowBalance[asset_] = escrowBalance_;

        emit PrintUserOp(mUserOp, paymasterAndData);
    }
// struct Any2EVMMessage {
//     bytes32 messageId; // MessageId corresponding to ccipSend on source.
//     uint64 sourceChainSelector; // Source chain selector.
//     bytes sender; // abi.decode(sender) if coming from an EVM chain.
//     bytes data; // payload sent in original message.
//     EVMTokenAmount[] destTokenAmounts; // Tokens and their amounts in their destination chain representation.
//   }
    function printOp(Client.Any2EVMMessage memory message) payable external locked {
        if(!ccipAddress[msg.sender]) {
            revert InvalidCCIPAddress(msg.sender);
        }

        // deserialize userop and paymasterAndData
        (UserOperation memory mUserOp, address receiver_) = abi.decode(message.data, (UserOperation, address));
        PaymasterAndData memory paymasterAndData = abi.decode(mUserOp.paymasterAndData, (PaymasterAndData));

        // hash userop locally
        bytes memory payload_ = abi.encodeWithSelector(bytes4(0x7b1d0da3), mUserOp);
        bytes32 userOpHash;
        assembly {
            pop(call(gas(), address(), 0, add(payload_, 0x20), mload(payload_), 0, 0x20))
            userOpHash := mload(0)
        }
        userOpHash = keccak256(abi.encode(
            userOpHash, 
            _entryPoint[paymasterAndData.chainId], 
            uint256(paymasterAndData.chainId)
        ));
        
        // validate signature
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(userOpHash.toEthSignedMessageHash(), mUserOp.signature);
        if (error != ECDSA.RecoverError.NoError) {
            revert BadSignature();
        } else {
            if(recovered != paymasterAndData.owner) {
                revert InvalidSignature(paymasterAndData.owner, recovered);
            }
        }
        //revert((uint256(uint160(paymasterAndData.owner))).toString());

        if(paymasterAndData.paymaster == address(0)) { revert InvalidPaymaster(paymasterAndData.paymaster); }
        if(paymasterAndData.chainId == uint64(0)) { revert InvalidChain(paymasterAndData.chainId); }
        if(paymasterAndData.owner == address(0)) { revert InvalidOwner(paymasterAndData.owner); }
        if(paymasterAndData.owner == address(this)) { revert InvalidOwner(paymasterAndData.owner); }

        Escrow storage accountInfo_ = _accountInfo[paymasterAndData.owner];
        if(block.timestamp > accountInfo_.deadline) { revert InvalidDeadline(""); }
        
        // revert(uint256(uint160(paymasterAndData.owner)).toString());
        // revert(uint256(_accountInfo[paymasterAndData.owner].assetBalance[paymasterAndData.asset]).toString());
        
        // Transfer amount of asset to receiver
        bool success_;
        address asset_ = paymasterAndData.asset;
        if(accountInfo_.assetBalance[asset_] < paymasterAndData.amount) { 
            revert InsufficentFunds(paymasterAndData.owner, asset_, paymasterAndData.amount);
        }

        if(asset_ == address(0)) { // address(0) == ETH
            (success_,) = payable(receiver_).call{value: paymasterAndData.amount}("");
        } else {
            // insufficent address(this) balance will auto-revert
            payload_ = abi.encodeWithSignature(
                "transferFrom(address,address,uint256)", 
                address(this), 
                receiver_, 
                paymasterAndData.amount
            );
            assembly {
                success_ := call(gas(), asset_, 0, add(payload_, 0x20), mload(payload_), 0, 0)
            }
        }
        if(!success_) { 
            revert PaymasterPaymentFailed(
                receiver_, 
                asset_, 
                paymasterAndData.owner, 
                paymasterAndData.amount
            );
        }
        accountInfo_.history[accountInfo_.nonce] = Payment(
            block.timestamp,
            paymasterAndData.amount,
            uint256(message.messageId),
            paymasterAndData.chainId,
            asset_,
            receiver_
        );
        accountInfo_.nonce++;

        uint256 escrowBalance_;
        
        if(asset_ == address(0)) {
            escrowBalance_ = address(this).balance;
        } else {
            payload_ = abi.encodeWithSignature("balanceOf(address)", address(this));
            assembly {
                pop(call(gas(), asset_, 0, add(payload_, 0x20), mload(payload_), 0, 0x20))
                returndatacopy(0, 0, 0x20)
                escrowBalance_ := mload(0)
            }
        }

        _escrowBalance[asset_] = escrowBalance_;

        emit PrintUserOp(mUserOp, paymasterAndData);
    }
    
    /*
    Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
                receiver: abi.encode(receiver),
                data: abi.encode(messageText),
                tokenAmounts: new Client.EVMTokenAmount[](0),
                extraArgs: "",
                feeToken: payFeesIn == PayFeesIn.LINK ? i_link : address(0)
            });

    */
    function callPrintOp(Client.Any2EVMMessage memory message) payable external locked {
        // validate msg.sender is ccip source
        // cast data into userop
        // ignore the rest
        if(!ccipAddress[msg.sender]) {
            revert InvalidCCIPAddress(msg.sender);
        }
        // UserOperation calldata userOp;// = _calldataUserOperation(_decodeUserOperation(message.data));
        // PaymasterAndData memory data = _decodePaymasterAndData(userOp.paymasterAndData);

        // // authenticate the operation
        // bytes32 userOpHash = userOp.hash();
        // // need to check safe signature method (maybe ecdsa?)

        // if(data.chainId != block.chainid) {
        //     revert InvalidChain(data.chainId);
        // }
        // if(data.amount < address(this).balance) {
        //     revert BalanceError(data.amount, address(this).balance);
        // }
    }

    error WithdrawRejected(string);
    error TransferFailed();
    error InsufficentFunds(address account, address asset, uint256 amount);
    error PaymasterPaymentFailed(address receiver, address asset, address account, uint256 amount);
    error InvalidCCIPAddress(address badSender);
    error InvalidLayerZeroAddress(address badSender);
    error InvalidHyperlaneAddress(address badSender);
    error InvalidChain(uint64 badDestination);
    error InvalidOwner(address owner);
    error InvalidPaymaster(address paymaster);
    error InvalidSignature(address owner, address notOwner);
    error InvalidTimeInput();
    error InvalidDeltaValue();
    error InvalidDeadline(string);
    error BadSignature();
    error BalanceError(uint256 requested, uint256 actual);

    event PrintUserOp(UserOperation userOp, PaymasterAndData paymasterAndData);

    fallback() external payable {}
}
