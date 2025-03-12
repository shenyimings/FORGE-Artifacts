// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { LinkTokenInterface } from "../interfaces/chainlink/LinkTokenInterface.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IRouterClient } from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { Client } from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

contract RadpieCCIPBridge is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    address public radpie;
    address public chainlinkRouter;

    mapping(uint64 => bool) public whitelistedChains;

    /* ============ Events ============ */

    event ChainlinkRouterUpdated(address oldRouterAddress, address newRouterAddress);
    event ChainWhitelisted(uint64 indexed _destinationChainSelector);
    event ChainDenylisted(uint64 indexed _destinationChainSelector);

    // Event emitted when the tokens are transferred to an account on another chain.
    event TokensTransferred(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        address token, // The token address that was transferred.
        uint256 tokenAmount, // The token amount that was transferred.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the message.
    );

    /* ============ Errors ============ */

    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance to cover the fees.
    error DestinationChainNotWhitelisted(uint64 destinationChainSelector); // Used when the destination chain has not been whitelisted by the contract owner.
    error InvalidAddress();
    error InvalidAmount();
    error AlreadyRegsitered();
    error InvalidToken();
    error AddressZero();

    /* ============ Constructor ============ */
    constructor() {
        _disableInitializers();
    }

    function __RadpieCCIPBridge_init(address _router, address _radpie) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        chainlinkRouter = _router;
        radpie = _radpie;
    }

    /* ============ Modifiers ============ */

    /// @dev Modifier that checks if the chain with the given destinationChainSelector is whitelisted.
    /// @param _destinationChainSelector The selector of the destination chain.
    modifier onlyWhitelistedChain(uint64 _destinationChainSelector) {
        if (!whitelistedChains[_destinationChainSelector])
            revert DestinationChainNotWhitelisted(_destinationChainSelector);
        _;
    }

    /* ============ External Getters ============ */

    function getSupportedTokens(
        uint64 chainSelector
    ) external view returns (address[] memory tokens) {
        tokens = IRouterClient(chainlinkRouter).getSupportedTokens(chainSelector);
    }

    /**
     * @dev Estimates the gas fee for sending a message from the current chain to another chain.
     * @param _destinationChainSelector The selector of the destination chain.
     * @param _receiver The address of the message receiver on the destination chain.
     * @param _amount The amount of tokens to be sent.
     * @return The estimated gas fee for sending the message.
     */
    function estimateMsgGasFee(
        uint64 _destinationChainSelector,
        address _receiver,
        uint256 _amount
    ) external view returns (uint256) {
        // Call the internal function to estimate the gas fee
        (, uint256 fee) = _estimateGasFee(
            _destinationChainSelector,
            _receiver,
            radpie,
            _amount,
            address(0)
        );

        // Return the calculated gas fee
        return fee;
    }

    /* ============ External Functions ============ */

    function tokenTransfer(
        uint64 destinationChainSelector,
        address _receiver,
        uint256 _amount
    ) external payable nonReentrant whenNotPaused onlyWhitelistedChain(destinationChainSelector) {
        if (_receiver == address(0)) revert InvalidAddress();

        if (_amount == 0 || msg.value == 0) revert InvalidAmount();

        IERC20(radpie).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20(radpie).safeIncreaseAllowance(chainlinkRouter, _amount);

        (Client.EVM2AnyMessage memory evm2AnyMessage, uint256 fee) = _estimateGasFee(
            destinationChainSelector,
            _receiver,
            radpie,
            _amount,
            address(0)
        );

        if (fee > msg.value) revert NotEnoughBalance(msg.value, fee);

        bytes32 messageId;

        messageId = IRouterClient(chainlinkRouter).ccipSend{ value: fee }(
            destinationChainSelector,
            evm2AnyMessage
        );

        emit TokensTransferred(
            messageId,
            destinationChainSelector,
            _receiver,
            radpie,
            _amount,
            address(0),
            fee
        );
    }

    /* ============ Admin Functions ============ */

    function setRouterAddress(address _router) external onlyOwner {
        if (_router == address(0)) revert AddressZero();
        address oldRouter = chainlinkRouter;
        chainlinkRouter = _router;

        emit ChainlinkRouterUpdated(oldRouter, _router);
    }

    /// @dev Whitelists a chain for transactions.
    /// @notice This function can only be called by the owner.
    /// @param _destinationChainSelector The selector of the destination chain to be whitelisted.
    function whitelistChain(uint64 _destinationChainSelector) external onlyOwner {
        whitelistedChains[_destinationChainSelector] = true;
        emit ChainWhitelisted(_destinationChainSelector);
    }

    /// @dev Denylists a chain for transactions.
    /// @notice This function can only be called by the owner.
    /// @param _destinationChainSelector The selector of the destination chain to be denylisted.
    function denylistChain(uint64 _destinationChainSelector) external onlyOwner {
        whitelistedChains[_destinationChainSelector] = false;
        emit ChainDenylisted(_destinationChainSelector);
    }

    /* ============ Internal Functions ============ */

    function _estimateGasFee(
        uint64 _destinationChainSelector,
        address _receiver,
        address _token,
        uint256 _amount,
        address _feeToken
    ) internal view returns (Client.EVM2AnyMessage memory evm2AnyMessage, uint256) {
        evm2AnyMessage = _buildCCIPMessage(_receiver, _token, _amount, _feeToken);

        uint256 fee = IRouterClient(chainlinkRouter).getFee(
            _destinationChainSelector,
            evm2AnyMessage
        );
        return (evm2AnyMessage, fee);
    }

    /// @notice Construct a CCIP message.
    /// @dev This function will create an EVM2AnyMessage struct with all the necessary information for tokens transfer.
    /// @param _receiver The address of the receiver.
    /// @param _token The token to be transferred.
    /// @param _amount The amount of the token to be transferred.
    /// @param _feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
    /// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
    function _buildCCIPMessage(
        address _receiver,
        address _token,
        uint256 _amount,
        address _feeTokenAddress
    ) internal pure returns (Client.EVM2AnyMessage memory) {
        // Set the token amounts
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: _token,
            amount: _amount
        });
        tokenAmounts[0] = tokenAmount;
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver), // ABI-encoded receiver address
            data: "", // No data
            tokenAmounts: tokenAmounts, // The amount and type of token being transferred
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit to 0 as we are not sending any data and non-strict sequencing mode
                Client.EVMExtraArgsV1({ gasLimit: 0, strict: false })
            ),
            // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
            feeToken: _feeTokenAddress
        });
        return evm2AnyMessage;
    }
}
