pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IKeyManager.sol";
import "./interfaces/IERC20Lite.sol";
import "./interfaces/ICFReceiver.sol";
import "./abstract/Shared.sol";
import "./Deposit.sol";
import "./AggKeyNonceConsumer.sol";
import "./GovernanceCommunityGuarded.sol";

/**
 * @title    Vault contract
 * @notice   The vault for holding and transferring native/tokens and deploying contracts for fetching
 *           individual deposits. It also allows users to do cross-chain swaps and(or) calls by
 *           making a function call directly to this contract.
 */
contract Vault is IVault, AggKeyNonceConsumer, GovernanceCommunityGuarded {
    using SafeERC20 for IERC20;

    uint256 private constant _AGG_KEY_EMERGENCY_TIMEOUT = 14 days;
    uint256 private constant _GAS_TO_FORWARD = 3500;

    event TransferNativeFailed(address payable indexed recipient, uint256 amount);
    event TransferTokenFailed(address payable indexed recipient, uint256 amount, address indexed token, bytes reason);

    event SwapNative(uint32 dstChain, bytes dstAddress, uint16 dstToken, uint256 amount, address indexed sender);
    event SwapToken(
        uint32 dstChain,
        bytes dstAddress,
        uint16 dstToken,
        address srcToken,
        uint256 amount,
        address indexed sender
    );

    /// @dev dstAddress is not indexed because indexing a dynamic type (string) to be able to filter,
    ///      makes it so we won't be able to decode it unless we specifically search for it. If we want
    ///      to filter it and decode it then we would need to have both the indexed and the non-indexed
    ///      version in the event.
    event XCallNative(
        uint32 dstChain,
        bytes dstAddress,
        uint16 dstToken,
        uint256 amount,
        address indexed sender,
        bytes message,
        uint256 dstNativeBudget,
        bytes refundAddress
    );
    event XCallToken(
        uint32 dstChain,
        bytes dstAddress,
        uint16 dstToken,
        address srcToken,
        uint256 amount,
        address indexed sender,
        bytes message,
        uint256 dstNativeBudget,
        bytes refundAddress
    );

    event AddGasNative(bytes32 swapID, uint256 amount);
    event AddGasToken(bytes32 swapID, uint256 amount, address token);

    constructor(IKeyManager keyManager) AggKeyNonceConsumer(keyManager) {}

    /// @dev   Get the governor address from the KeyManager. This is called by the onlyGovernor
    ///        modifier in the GovernanceCommunityGuarded. This logic can't be moved to the
    ///        GovernanceCommunityGuarded since it requires a reference to the KeyManager.
    function _getGovernor() internal view override returns (address) {
        return getKeyManager().getGovernanceKey();
    }

    /// @dev   Get the community key from the KeyManager. This is called by the isCommunityKey
    ///        modifier in the GovernanceCommunityGuarded. This logic can't be moved to the
    ///        GovernanceCommunityGuarded since it requires a reference to the KeyManager.
    function _getCommunityKey() internal view override returns (address) {
        return getKeyManager().getCommunityKey();
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                  Transfer and Fetch                      //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Can do a combination of all fcns in this contract. It first fetches all
     *          deposits , then it performs all transfers specified with the rest
     *          of the inputs, the same as transferBatch (where all inputs are again required
     *          to be of equal length - however the lengths of the fetch inputs do not have to
     *          be equal to lengths of the transfer inputs). Fetches/transfers of native are
     *          indicated with 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE as the token address.
     * @dev     FetchAndDeploy is executed first to handle the edge case , which probably shouldn't
     *          happen anyway, where a deploy and a fetch for the same address are in the same batch.
     *          Transfers are executed last to ensure that all fetching has been completed first.
     * @param sigData   The keccak256 hash over the msg (uint) (here that's
     *                  a hash over the calldata to the function with an empty sigData) and
     *                  sig over that hash (uint) from the aggregate key
     * @param deployFetchParamsArray    The array of deploy and fetch parameters
     * @param fetchParamsArray    The array of fetch parameters
     * @param transferParamsArray The array of transfer parameters
     */
    function allBatch(
        SigData calldata sigData,
        DeployFetchParams[] calldata deployFetchParamsArray,
        FetchParams[] calldata fetchParamsArray,
        TransferParams[] calldata transferParamsArray
    )
        external
        override
        onlyNotSuspended
        consumesKeyNonce(
            sigData,
            keccak256(
                abi.encodeWithSelector(
                    this.allBatch.selector,
                    SigData(sigData.keyManAddr, sigData.chainID, 0, 0, sigData.nonce, address(0)),
                    deployFetchParamsArray,
                    fetchParamsArray,
                    transferParamsArray
                )
            )
        )
    {
        // Fetch by deploying new deposits
        _deployAndFetchBatch(deployFetchParamsArray);

        // Fetch from already deployed deposits
        _fetchBatch(fetchParamsArray);

        // Send all transfers
        _transferBatch(transferParamsArray);
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                          Transfers                       //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Transfers native or a token from this vault to a recipient
     * @param sigData   The keccak256 hash over the msg (uint) (here that's
     *                  a hash over the calldata to the function with an empty sigData) and
     *                  sig over that hash (uint) from the aggregate key
     * @param transferParams       The transfer parameters
     */
    function transfer(
        SigData calldata sigData,
        TransferParams calldata transferParams
    )
        external
        override
        onlyNotSuspended
        nzAddr(transferParams.token)
        nzAddr(transferParams.recipient)
        nzUint(transferParams.amount)
        consumesKeyNonce(
            sigData,
            keccak256(
                abi.encodeWithSelector(
                    this.transfer.selector,
                    SigData(sigData.keyManAddr, sigData.chainID, 0, 0, sigData.nonce, address(0)),
                    transferParams
                )
            )
        )
    {
        _transfer(transferParams.token, transferParams.recipient, transferParams.amount);
    }

    /**
     * @notice  Transfers native or tokens from this vault to recipients.
     * @param sigData   The keccak256 hash over the msg (uint) (here that's a hash over
     *                  the calldata to the function with an empty sigData) and sig over
     *                  that hash (uint) from the aggregate key
     * @param transferParamsArray The array of transfer parameters.
     */
    function transferBatch(
        SigData calldata sigData,
        TransferParams[] calldata transferParamsArray
    )
        external
        override
        onlyNotSuspended
        consumesKeyNonce(
            sigData,
            keccak256(
                abi.encodeWithSelector(
                    this.transferBatch.selector,
                    SigData(sigData.keyManAddr, sigData.chainID, 0, 0, sigData.nonce, address(0)),
                    transferParamsArray
                )
            )
        )
    {
        _transferBatch(transferParamsArray);
    }

    /**
     * @notice  Transfers native or tokens from this vault to recipients.
     * @param transferParamsArray The array of transfer parameters.
     */
    function _transferBatch(TransferParams[] calldata transferParamsArray) private {
        uint256 length = transferParamsArray.length;
        for (uint256 i = 0; i < length; ) {
            _transfer(transferParamsArray[i].token, transferParamsArray[i].recipient, transferParamsArray[i].amount);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice  Transfers ETH or a token from this vault to a recipient
     * @dev     When transfering native tokens, using call function limiting the amount of gas so
     *          the receivers can't consume all the gas. Setting that amount of gas to more than
     *          2300 to future-proof the contract in case of opcode gas costs changing.
     * @dev     When transferring ERC20 tokens, if it fails ensure the transfer fails gracefully
     *          to not revert an entire batch. e.g. usdc blacklisted recipient. Following safeTransfer
     *          approach to support tokens that don't return a bool.
     * @param token The address of the token to be transferred
     * @param recipient The address of the recipient of the transfer
     * @param amount    The amount to transfer, in wei (uint)
     */
    function _transfer(address token, address payable recipient, uint256 amount) private {
        if (address(token) == _NATIVE_ADDR) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, ) = recipient.call{gas: _GAS_TO_FORWARD, value: amount}("");
            if (!success) {
                emit TransferNativeFailed(recipient, amount);
            }
        } else {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, bytes memory returndata) = token.call(
                abi.encodeWithSelector(IERC20(token).transfer.selector, recipient, amount)
            );

            if (success) {
                if (returndata.length > 0) {
                    if (abi.decode(returndata, (bool)) == false) {
                        emit TransferTokenFailed(recipient, amount, token, returndata);
                    }
                }
            } else {
                emit TransferTokenFailed(recipient, amount, token, returndata);
            }
        }
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                        Fetch Deposits                    //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Retrieves any token from multiple address, deterministically generated using
     *          create2, by creating a contract for that address, sending it to this vault.
     * @param sigData   The keccak256 hash over the msg (uint) (here that's normally
     *                  a hash over the calldata to the function with an empty sigData) and
     *                  sig over that hash (uint) from the aggregate key
     * @param deployFetchParamsArray    The array of deploy and fetch parameters
     */
    function deployAndFetchBatch(
        SigData calldata sigData,
        DeployFetchParams[] calldata deployFetchParamsArray
    )
        external
        override
        onlyNotSuspended
        consumesKeyNonce(
            sigData,
            keccak256(
                abi.encodeWithSelector(
                    this.deployAndFetchBatch.selector,
                    SigData(sigData.keyManAddr, sigData.chainID, 0, 0, sigData.nonce, address(0)),
                    deployFetchParamsArray
                )
            )
        )
    {
        _deployAndFetchBatch(deployFetchParamsArray);
    }

    function _deployAndFetchBatch(DeployFetchParams[] calldata deployFetchParamsArray) private {
        // Deploy deposit contracts
        uint256 length = deployFetchParamsArray.length;
        for (uint256 i = 0; i < length; ) {
            new Deposit{salt: deployFetchParamsArray[i].swapID}(IERC20Lite(deployFetchParamsArray[i].token));
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice  Retrieves any token addresses where a Deposit contract is already deployed.
     * @param sigData   The keccak256 hash over the msg (uint) (here that's normally
     *                  a hash over the calldata to the function with an empty sigData) and
     *                  sig over that hash (uint) from the aggregate key
     * @param fetchParamsArray    The array of fetch parameters
     */
    function fetchBatch(
        SigData calldata sigData,
        FetchParams[] calldata fetchParamsArray
    )
        external
        override
        onlyNotSuspended
        consumesKeyNonce(
            sigData,
            keccak256(
                abi.encodeWithSelector(
                    this.fetchBatch.selector,
                    SigData(sigData.keyManAddr, sigData.chainID, 0, 0, sigData.nonce, address(0)),
                    fetchParamsArray
                )
            )
        )
    {
        _fetchBatch(fetchParamsArray);
    }

    /**
     * @notice  Retrieves any token from multiple addresses where a Deposit contract is already deployed.
     *          It emits an event if the fetch fails.
     * @param fetchParamsArray    The array of fetch parameters
     */
    function _fetchBatch(FetchParams[] calldata fetchParamsArray) private {
        uint256 length = fetchParamsArray.length;
        for (uint256 i = 0; i < length; ) {
            Deposit(fetchParamsArray[i].fetchContract).fetch(IERC20Lite(fetchParamsArray[i].token));
            unchecked {
                ++i;
            }
        }
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //         Initiate cross-chain swaps (source chain)        //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Swaps native token for a token in another chain. The egress token will be transferred to the specified 
     *          destination address on the destination chain.
     * @dev     Checking the validity of inputs shall be done as part of the event witnessing. Only the amount is checked
     *          to explicity indicate that an amount is required.  It isn't preventing spamming.

     * @param dstChain      The destination chain according to the Chainflip Protocol's nomenclature.
     * @param dstAddress    Bytes containing the destination address on the destination chain.
     * @param dstToken      Destination token to be swapped to.
     */
    function xSwapNative(
        uint32 dstChain,
        bytes memory dstAddress,
        uint16 dstToken
    ) external payable override onlyNotSuspended nzUint(msg.value) {
        emit SwapNative(dstChain, dstAddress, dstToken, msg.value, msg.sender);
    }

    /**
     * @notice  Swaps ERC20 token for a token in another chain. The desired token will be transferred to the specified 
     *          destination address on the destination chain. The provided ERC20 token must be supported by the Chainflip Protocol. 
     * @dev     Checking the validity of inputs shall be done as part of the event witnessing. Only the amount is checked
     *          to explicity indicate that an amount is required.

     * @param dstChain      The destination chain according to the Chainflip Protocol's nomenclature.
     * @param dstAddress    Bytes containing the destination address on the destination chain.
     * @param dstToken      Uint containing the specifics of the swap to be performed according to Chainflip's nomenclature.
     * @param srcToken      Address of the source token to swap.
     * @param amount        Amount of tokens to swap.
     */
    function xSwapToken(
        uint32 dstChain,
        bytes memory dstAddress,
        uint16 dstToken,
        IERC20 srcToken,
        uint256 amount
    ) external override onlyNotSuspended nzUint(amount) {
        srcToken.safeTransferFrom(msg.sender, address(this), amount);
        emit SwapToken(dstChain, dstAddress, dstToken, address(srcToken), amount, msg.sender);
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //     Initiate cross-chain call and swap (source chain)    //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Performs a cross-chain call to the destination address on the destination chain. Native tokens must be paid
     *          to this contract. The swap intent determines if the provided tokens should be swapped to a different token
     *          and transferred as part of the cross-chain call. Otherwise, all tokens are used as a payment for gas on the destination chain.
     *          The message parameter is transmitted to the destination chain as part of the cross-chain call.
     * @dev     Checking the validity of inputs shall be done as part of the event witnessing. Only the amount is checked
     *          to explicity inidcate that an amount is required. It isn't preventing spamming.
     *
     * @param dstChain      The destination chain according to the Chainflip Protocol's nomenclature.
     * @param dstAddress    Bytes containing the destination address on the destination chain.
     * @param dstToken      Uint containing the specifics of the swap to be performed, if any, as part of the xCall. The string
     *                      must follow Chainflip's nomenclature. It can signal that no swap needs to take place
     *                      and the source token will be used for gas in a swapless xCall.
     * @param message       The message to be sent to the egress chain. This is a general purpose message.
     * @param dstNativeBudget  The amount of native gas to be used on the destination chain's call.
     * @param refundAddress Address for any future refunds to the user.
     */
    function xCallNative(
        uint32 dstChain,
        bytes calldata dstAddress,
        uint16 dstToken,
        bytes calldata message,
        uint256 dstNativeBudget,
        bytes calldata refundAddress
    ) external payable override onlyNotSuspended nzUint(msg.value) {
        emit XCallNative(
            dstChain,
            dstAddress,
            dstToken,
            msg.value,
            msg.sender,
            message,
            dstNativeBudget,
            refundAddress
        );
    }

    /**
     * @notice  Performs a cross-chain call to the destination chain and destination address. An ERC20 token amount
     *          needs to be approved to this contract. The ERC20 token must be supported by the Chainflip Protocol.
     *          The swap intent determines whether the provided tokens should be swapped to a different token
     *          by the Chainflip Protocol. If so, the swapped tokens will be transferred to the destination chain as part
     *          of the cross-chain call. Otherwise, the tokens are used as a payment for gas on the destination chain.
     *          The message parameter is transmitted to the destination chain as part of the cross-chain call.
     * @dev     Checking the validity of inputs shall be done as part of the event witnessing. Only the amount is checked
     *          to explicity indicate that an amount is required.
     *
     * @param dstChain      The destination chain according to the Chainflip Protocol's nomenclature.
     * @param dstAddress    Bytes containing the destination address on the destination chain.
     * @param dstToken      Uint containing the specifics of the swap to be performed, if any, as part of the xCall. The string
     *                      must follow Chainflip's nomenclature. It can signal that no swap needs to take place
     *                      and the source token will be used for gas in a swapless xCall.
     * @param message       The message to be sent to the egress chain. This is a general purpose message.
     * @param dstNativeBudget  The amount of native gas to be used on the destination chain's call. That gas will be paid with the
     *                      source token.
     * @param srcToken      Address of the source token.
     * @param amount        Amount of tokens to swap.
     * @param refundAddress Address for any future refunds to the user.
     */
    function xCallToken(
        uint32 dstChain,
        bytes memory dstAddress,
        uint16 dstToken,
        bytes calldata message,
        uint256 dstNativeBudget,
        IERC20 srcToken,
        uint256 amount,
        bytes calldata refundAddress
    ) external override onlyNotSuspended nzUint(amount) {
        srcToken.safeTransferFrom(msg.sender, address(this), amount);
        emit XCallToken(
            dstChain,
            dstAddress,
            dstToken,
            address(srcToken),
            amount,
            msg.sender,
            message,
            dstNativeBudget,
            refundAddress
        );
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                     Gas topups                           //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Add gas (topup) to an existing cross-chain call with the unique identifier swapID.
     *          Native tokens must be paid to this contract as part of the call.
     * @param swapID    The unique identifier for this swap (bytes32)
     */
    function addGasNative(bytes32 swapID) external payable override onlyNotSuspended {
        emit AddGasNative(swapID, msg.value);
    }

    /**
     * @notice  Add gas (topup) to an existing cross-chain call with the unique identifier swapID.
     *          A Chainflip supported token must be paid to this contract as part of the call.
     * @param swapID    The unique identifier for this swap (bytes32)
     * @param token     Address of the token to provide.
     * @param amount    Amount of tokens to provide.
     */
    function addGasToken(
        bytes32 swapID,
        uint256 amount,
        IERC20 token
    ) external override onlyNotSuspended nzUint(amount) {
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit AddGasToken(swapID, amount, address(token));
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //      Execute cross-chain call and swap (dest. chain)     //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Transfers ETH or a token from this vault to a recipient and makes a function call
     *          completing a cross-chain swap and call. The ICFReceiver interface is expected on
     *          the receiver's address. A message is passed to the receiver along with other
     *          parameters specifying the origin of the swap.
     * @param sigData   The keccak256 hash over the msg (uint) (here that's normally a hash over
     *                  the calldata to the function with an empty sigData) and sig over that
     *                  that hash (uint) from the aggregate key.
     * @param transferParams  The transfer parameters
     * @param srcChain        The source chain where the call originated from.
     * @param srcAddress      The address where the transfer originated within the ingress chain.
     * @param message         The message to be passed to the recipient.
     */
    function executexSwapAndCall(
        SigData calldata sigData,
        TransferParams calldata transferParams,
        uint32 srcChain,
        bytes calldata srcAddress,
        bytes calldata message
    )
        external
        override
        onlyNotSuspended
        nzAddr(transferParams.token)
        nzAddr(transferParams.recipient)
        nzUint(transferParams.amount)
        consumesKeyNonce(
            sigData,
            keccak256(
                abi.encodeWithSelector(
                    this.executexSwapAndCall.selector,
                    SigData(sigData.keyManAddr, sigData.chainID, 0, 0, sigData.nonce, address(0)),
                    transferParams,
                    srcChain,
                    srcAddress,
                    message
                )
            )
        )
    {
        // Logic in another internal function to avoid the stackTooDeep error
        _executexSwapAndCall(transferParams, srcChain, srcAddress, message);
    }

    /**
     * @notice Logic for transferring the tokens and calling the recipient. It's on the receiver to
     *         make sure the call doesn't revert, otherwise the tokens won't be transferred.
     *         The _transfer function is not used because we want to be able to embed the native token
     *         into the cfReceive call to avoid doing two external calls.
     *         In case of revertion the tokens will remain in the Vault. Therefore, the destination
     *         contract must ensure it doesn't revert e.g. using try-catch mechanisms.
     * @dev    In the case of the ERC20 transfer reverting, not handling the error to allow for tx replay.
     *         Also, to ensure the cfReceive call is made only if the transfer is successful.
     */
    function _executexSwapAndCall(
        TransferParams calldata transferParams,
        uint32 srcChain,
        bytes calldata srcAddress,
        bytes calldata message
    ) private {
        if (transferParams.token == _NATIVE_ADDR) {
            ICFReceiver(transferParams.recipient).cfReceive{value: transferParams.amount}(
                srcChain,
                srcAddress,
                message,
                transferParams.token,
                transferParams.amount
            );
        } else {
            IERC20(transferParams.token).safeTransfer(transferParams.recipient, transferParams.amount);
            ICFReceiver(transferParams.recipient).cfReceive(
                srcChain,
                srcAddress,
                message,
                transferParams.token,
                transferParams.amount
            );
        }
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //          Execute cross-chain call (dest. chain)          //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Executes a cross-chain function call. The ICFReceiver interface is expected on
     *          the receiver's address. A message is passed to the receiver along with other
     *          parameters specifying the origin of the swap. This is used for cross-chain messaging
     *          without any swap taking place on the Chainflip Protocol.
     * @param sigData   The keccak256 hash over the msg (uint) (here that's normally
     *                  a hash over the calldata to the function with an empty sigData) and
     *                  sig over that hash (uint) from the aggregate key
     * @param srcChain       The source chain where the call originated from.
     * @param srcAddress     The address where the transfer originated from in the ingressParams.
     * @param message        The message to be passed to the recipient.
     */
    function executexCall(
        SigData calldata sigData,
        address recipient,
        uint32 srcChain,
        bytes calldata srcAddress,
        bytes calldata message
    )
        external
        override
        onlyNotSuspended
        nzAddr(recipient)
        consumesKeyNonce(
            sigData,
            keccak256(
                abi.encodeWithSelector(
                    this.executexCall.selector,
                    SigData(sigData.keyManAddr, sigData.chainID, 0, 0, sigData.nonce, address(0)),
                    recipient,
                    srcChain,
                    srcAddress,
                    message
                )
            )
        )
    {
        ICFReceiver(recipient).cfReceivexCall(srcChain, srcAddress, message);
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                        Governance                        //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Withdraw all funds to governance address in case of emergency. This withdrawal needs
     *         to be approved by the Community and it can only be executed if no nonce from the
     *         current AggKey had been consumed in _AGG_KEY_TIMEOUT time. It is a last resort and
     *         can be used to rectify an emergency.
     * @param tokens    The addresses of the tokens to be transferred
     */
    function govWithdraw(
        address[] calldata tokens
    ) external override onlyGovernor onlyCommunityGuardDisabled onlySuspended timeoutEmergency {
        // Could use msg.sender or getGovernor() but hardcoding the get call just for extra safety
        address payable recipient = payable(getKeyManager().getGovernanceKey());

        // Transfer all native and ERC20 Tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == _NATIVE_ADDR) {
                _transfer(_NATIVE_ADDR, recipient, address(this).balance);
            } else {
                _transfer(tokens[i], recipient, IERC20(tokens[i]).balanceOf(address(this)));
            }
        }
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                          Modifiers                       //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /// @dev    Check that no nonce has been consumed in the last 14 days - emergency
    modifier timeoutEmergency() {
        require(
            block.timestamp - getKeyManager().getLastValidateTime() >= _AGG_KEY_EMERGENCY_TIMEOUT,
            "Vault: not enough time"
        );
        _;
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                          Fallbacks                       //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /// @dev For receiving native when Deposit.fetch() is called.
    receive() external payable {}
}
