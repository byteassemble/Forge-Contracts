// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)



/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}


// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)




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
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
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


// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)




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


// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)



/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}


// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)



/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}


/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)




// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)



/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}


// OpenZeppelin Contracts v4.4.1 (token/ERC721/utils/ERC721Holder.sol)




// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)



/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}


/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}


contract TycheStake is ERC721Holder, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 public totalCollections = 0;
    mapping(address => bool) public whitelist;
    address[] public poolContracts;
    struct PoolInfo {
        address rewardToken1;
        address rewardToken2;  // If provide the second reward token. If not, 0x
        uint256 startTime;
        uint256 endTime;
        uint256 rewardPerSecond1;  // reward amount per second for reward token1
        uint256 rewardPerSecond2;  // reward amount per second for reward token2
        uint256 lastRewardTime;
        uint256 stakedSupply;
        uint256 accPerShare1;
        uint256 accPerShare2;
    }
    // stakeToken address => PoolInfo
    mapping(address => PoolInfo) public pools;

    struct UserInfo {
        uint256 amount;  // How many tokens staked per collection
        uint256 debt1;  // Reward debt for first reward token
        uint256 debt2;  // Reward debt for second reward token
        uint256[] tokenIds;  // staked token ids
    }
    // user => collection => UserInfo
    mapping(address => mapping(address => UserInfo)) private users;
    // user => collections // view
    mapping(address => address[]) public userCollections;
    // check user staked for add/remove, user => collection => bool
    mapping(address => mapping(address => bool)) public isUserCollection;
    // collection => tokenId => user address
    mapping(address => mapping(uint256 => address)) public tokenOwners;
    
    event CreatePool(
        address stakeToken,
        address rewardToken1,
        uint256 rewardPerSecond1,
        uint256 startTime,
        uint256 endTime,
        address rewardToken2,
        uint256 rewardPerSecond2
    );
    event Stake(address user, address collection, uint256 tokenId);
    event Unstake(address user, address collection, uint256 tokenId);
    event Claim(address user, address collection, address rewardToken, uint256 amount);
    event UpdateReward(address collection, uint256 rate1, uint256 rate2);
    event UpdateStartTime(address collection, uint256 startTime);
    event UpdateEndTime(address collection, uint256 endTime);
    event ClaimTime(uint256);

    constructor() {}
    
    function createPool(address _stakeToken, address _rewardToken1, uint256 _rewardPerSecond1, uint256 _startTime, uint256 _endTime, address _rewardToken2, uint256 _rewardPerSecond2) external onlyOwner {
        require(!whitelist[_stakeToken], "The collection is added already.");
        totalCollections += 1;
        PoolInfo memory pool = pools[_stakeToken];
        pool.startTime = _startTime;
        pool.endTime = _endTime;
        pool.lastRewardTime = _startTime;
        pool.stakedSupply = 0;
        pool.rewardToken1 = _rewardToken1;
        pool.rewardPerSecond1 = _rewardPerSecond1;
        if (_rewardToken2 == address(0)) {
            pool.rewardToken2 = address(0);
            pool.rewardPerSecond2 = 0;
        } else {
            pool.rewardToken2 = _rewardToken2;
            pool.rewardPerSecond2 = _rewardPerSecond2;
        }
        pool.accPerShare1 = 0;
        pool.accPerShare2 = 0;

        pools[_stakeToken] = pool;
        whitelist[_stakeToken] = true;
        poolContracts.push(_stakeToken);
        emit CreatePool(_stakeToken, _rewardToken1, _rewardPerSecond1, _startTime, _endTime, _rewardToken2, _rewardPerSecond2);
    }

    function stake(address _stakeToken, uint256[] memory _tokenIds) external nonReentrant {
        require(whitelist[_stakeToken], "The token is not allowed to stake!");
        uint256 _length = _tokenIds.length;
        require(_length > 0, "You should stake tokens at least one.");
        _updatePool(_stakeToken);
        PoolInfo storage pool = pools[_stakeToken];
        UserInfo storage user = users[msg.sender][_stakeToken];

        uint256[2] memory rewardAmounts = checkRewards(msg.sender, _stakeToken);
        if (rewardAmounts[0] > 0) {
            safeRewardTransfer(pool.rewardToken1, msg.sender, rewardAmounts[0]);
            emit Claim(msg.sender, _stakeToken, pool.rewardToken1, rewardAmounts[0]);
        }
        if (rewardAmounts[1] > 0) {
            safeRewardTransfer(pool.rewardToken2, msg.sender, rewardAmounts[1]);
            emit Claim(msg.sender, _stakeToken, pool.rewardToken2, rewardAmounts[1]);
        }

        for (uint256 i = 0; i < _length; i++) {
            IERC721(_stakeToken).safeTransferFrom(msg.sender, address(this), _tokenIds[i]);
            user.tokenIds.push(_tokenIds[i]);
            tokenOwners[_stakeToken][_tokenIds[i]] = msg.sender;
            emit Stake(msg.sender, _stakeToken, _tokenIds[i]);
        }
        user.amount += _length;
        pool.stakedSupply += _length;

        if (!isUserCollection[msg.sender][_stakeToken]) {
            isUserCollection[msg.sender][_stakeToken] = true;
            userCollections[msg.sender].push(_stakeToken);
        }

        user.debt1 = user.amount * pool.accPerShare1;
        user.debt2 = user.amount * pool.accPerShare2;
    }

    function unstakeOne(address _stakeToken, uint256 _tokenId) external nonReentrant {
        require(whitelist[_stakeToken], "The token is not allowed to stake!");
        require(tokenOwners[_stakeToken][_tokenId] == msg.sender, "Token owner can unstake only");
        _updatePool(_stakeToken);
        PoolInfo storage pool = pools[_stakeToken];
        UserInfo storage user = users[msg.sender][_stakeToken];

        uint256[2] memory rewardAmounts = checkRewards(msg.sender, _stakeToken);
        if (rewardAmounts[0] > 0) {
            safeRewardTransfer(pool.rewardToken1, msg.sender, rewardAmounts[0]);
            emit Claim(msg.sender, _stakeToken, pool.rewardToken1, rewardAmounts[0]);
        }
        if (rewardAmounts[1] > 0) {
            safeRewardTransfer(pool.rewardToken2, msg.sender, rewardAmounts[1]);
            emit Claim(msg.sender, _stakeToken, pool.rewardToken2, rewardAmounts[1]);
        }

        uint256 _length = user.tokenIds.length;
        require(_length > 0, "You don't have any staked token");
        for(uint256 i = 0; i < _length - 1; i++) {
            if (user.tokenIds[i] == _tokenId) {
                user.tokenIds[i] = user.tokenIds[_length - 1];
            }
        }
        user.tokenIds.pop();
        user.amount --;
        if (user.amount == 0) {
            // remove user collection
            isUserCollection[msg.sender][_stakeToken] = false;
            uint256 lengthOfUserCollections = userCollections[msg.sender].length;
            for(uint256 i = 0; i < lengthOfUserCollections - 1; i++) {
                if (userCollections[msg.sender][i] == _stakeToken) {
                    userCollections[msg.sender][i] = userCollections[msg.sender][lengthOfUserCollections - 1];
                }
            }
            userCollections[msg.sender].pop();
        }
        pool.stakedSupply --;
        IERC721(_stakeToken).safeTransferFrom(address(this), msg.sender, _tokenId);
        tokenOwners[_stakeToken][_tokenId] = address(0);

        user.debt1 = user.amount * pool.accPerShare1;
        user.debt2 = user.amount * pool.accPerShare2;
        emit Unstake(msg.sender, _stakeToken, _tokenId);
    }

    function unstake(address _stakeToken) external nonReentrant {
        require(whitelist[_stakeToken], "The token is not allowed to stake!");
        _updatePool(_stakeToken);
        PoolInfo storage pool = pools[_stakeToken];
        UserInfo storage user = users[msg.sender][_stakeToken];
        
        uint256[2] memory rewardAmounts = checkRewards(msg.sender, _stakeToken);
        if (rewardAmounts[0] > 0) {
            safeRewardTransfer(pool.rewardToken1, msg.sender, rewardAmounts[0]);
            emit Claim(msg.sender, _stakeToken, pool.rewardToken1, rewardAmounts[0]);
        }
        if (rewardAmounts[1] > 0) {
            safeRewardTransfer(pool.rewardToken2, msg.sender, rewardAmounts[1]);
            emit Claim(msg.sender, _stakeToken, pool.rewardToken2, rewardAmounts[1]);
        }
        
        uint256[] memory tokenIds = user.tokenIds;
        uint256 _length = tokenIds.length;
        for (uint256 i = 0; i < _length; i++) {
            IERC721(_stakeToken).safeTransferFrom(address(this), msg.sender, tokenIds[i]);
            tokenOwners[_stakeToken][tokenIds[i]] = address(0);
            emit Unstake(msg.sender, _stakeToken, tokenIds[i]);
        }
        user.amount = 0;
        delete user.tokenIds;
        
        // remove user collection
        isUserCollection[msg.sender][_stakeToken] = false;
        uint256 lengthOfUserCollections = userCollections[msg.sender].length;
        for(uint256 i = 0; i < lengthOfUserCollections - 1; i++) {
            if (userCollections[msg.sender][i] == _stakeToken) {
                userCollections[msg.sender][i] = userCollections[msg.sender][lengthOfUserCollections - 1];
            }
        }
        userCollections[msg.sender].pop();

        pool.stakedSupply -= _length;
        user.debt1 = user.amount * pool.accPerShare1;
        user.debt2 = user.amount * pool.accPerShare2;
    }

    function claim(address _stakeToken) external nonReentrant {
        require(whitelist[_stakeToken], "The token is not allowed to stake!");
        _updatePool(_stakeToken);
        PoolInfo storage pool = pools[_stakeToken];
        UserInfo storage user = users[msg.sender][_stakeToken];

        uint256[2] memory rewardAmounts = checkRewards(msg.sender, _stakeToken);
        if (rewardAmounts[0] > 0) {
            safeRewardTransfer(pool.rewardToken1, msg.sender, rewardAmounts[0]);
            emit Claim(msg.sender, _stakeToken, pool.rewardToken1, rewardAmounts[0]);
        }
        if (rewardAmounts[1] > 0) {
            safeRewardTransfer(pool.rewardToken2, msg.sender, rewardAmounts[1]);
            emit Claim(msg.sender, _stakeToken, pool.rewardToken2, rewardAmounts[1]);
        }
        user.debt1 = user.amount * pool.accPerShare1;
        user.debt2 = user.amount * pool.accPerShare2;
        emit ClaimTime(block.timestamp);
    }

    // Internal functions
    function _updatePool(address _stakeToken) internal {
        PoolInfo storage pool = pools[_stakeToken];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        if (pool.stakedSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = _getMultiplier(pool.lastRewardTime, block.timestamp, pool.endTime);
        pool.accPerShare1 = pool.accPerShare1 + multiplier * pool.rewardPerSecond1 / pool.stakedSupply;
        if (pool.rewardToken2 != address(0)) {
            pool.accPerShare2 = pool.accPerShare2 + multiplier * pool.rewardPerSecond2 / pool.stakedSupply;
        }
        pool.lastRewardTime = block.timestamp;
    }

    function _getMultiplier(uint256 _from, uint256 _to, uint256 _endTime) internal pure returns (uint256) {
        if (_to <= _endTime) {
            return _to - _from;
        } else if (_from >= _endTime) {
            return 0;
        } else {
            return _endTime - _from;
        }
    }

    /*
     * @notice check rewards in real time.
     */
    function checkRewards(address _user, address _stakeToken) public view returns(uint256[2] memory) {
        uint256 reward1 = 0;
        uint256 reward2 = 0;
        PoolInfo storage pool = pools[_stakeToken];
        UserInfo storage user = users[_user][_stakeToken];
        uint256 adjustedPerShare1 = pool.accPerShare1;
        uint256 adjustedPerShare2 = pool.accPerShare2;
        uint256 multiplier = _getMultiplier(pool.lastRewardTime, block.timestamp, pool.endTime);
        if (block.timestamp > pool.lastRewardTime && pool.stakedSupply != 0) {
            adjustedPerShare1 = pool.accPerShare1 + multiplier * pool.rewardPerSecond1 / pool.stakedSupply;
        }
        reward1 = user.amount * adjustedPerShare1 - user.debt1;
        if (pool.rewardToken2 != address(0)) {
            if (block.timestamp > pool.lastRewardTime && pool.stakedSupply != 0) {
                adjustedPerShare2 = pool.accPerShare2 + multiplier * pool.rewardPerSecond2 / pool.stakedSupply;
            }
            reward2 = user.amount * adjustedPerShare2 - user.debt2;
        }
        return [reward1, reward2];
    }

    function safeRewardTransfer(address _rewardToken, address _to, uint256 _amount) internal {
        IERC20 rewardToken = IERC20(_rewardToken);
        uint256 rewardBalance = rewardToken.balanceOf(address(this));
        require(rewardBalance >= _amount, "insufficent reward.");
        rewardToken.safeTransfer(_to, _amount);
    }

    function updateRewardRate(address _stakeToken, uint256 _newRate1, uint256 _newRate2) external onlyOwner {
        require(whitelist[_stakeToken], "The token is not allowed to stake!");
        _updatePool(_stakeToken);
        PoolInfo storage pool = pools[_stakeToken];
        pool.rewardPerSecond1 = _newRate1;
        pool.rewardPerSecond2 = _newRate2;
        emit UpdateReward(_stakeToken, _newRate1, _newRate2);
    }

    function updateStartTime(address _stakeToken, uint256 _startTime) external onlyOwner {
        require(block.timestamp < _startTime, "New startBlock must be higher than current block");
        require(whitelist[_stakeToken], "The token is not allowed to stake!");
        PoolInfo storage pool = pools[_stakeToken];
        require(block.timestamp < pool.startTime, "Pool has started already");

        pool.startTime = _startTime;
        pool.lastRewardTime = _startTime;

        emit UpdateStartTime(_stakeToken, _startTime);
    }

    function getUserTokenIds(address _user, address _stakeToken) public view returns(uint256[] memory) {
        return users[_user][_stakeToken].tokenIds;
    }

    function getUserCollections(address _user) public view returns(address[] memory) {
        return userCollections[_user];
    }

    function checkUser(address _user, address _stakeToken) public view returns (UserInfo memory) {
        return users[_user][_stakeToken];
    }

    function getPoolContracts() public view returns(address[] memory) {
        return poolContracts;
    }
    
    function recoverWrongTokens(address _rewardToken) external onlyOwner {
        IERC20(_rewardToken).transfer(msg.sender, IERC20(_rewardToken).balanceOf(address(this)));
    }

    function readBlockTimestamp() external view returns (uint256) {
        return block.timestamp;
    }
}
