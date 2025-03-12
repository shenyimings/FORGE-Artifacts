// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20, IERC20, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Multicall} from "openzeppelin-contracts/contracts/utils/Multicall.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IOrderProcessor} from "../../src/orders/IOrderProcessor.sol";
import "prb-math/Common.sol" as PrbMath;
import {Nonces} from "../common/Nonces.sol";
import {SelfPermit} from "../common/SelfPermit.sol";
import {IForwarder} from "./IForwarder.sol";

/// @notice Contract for paying gas fees for users and forwarding meta transactions to OrderProcessor contracts.
/// @author Dinari (https://github.com/dinaricrypto/issuer-contracts/blob/main/src/issuer/OrderProcessor.sol)
contract Forwarder is IForwarder, Ownable, Nonces, Multicall, SelfPermit, ReentrancyGuard, EIP712 {
    using SafeERC20 for IERC20Permit;
    using SafeERC20 for IERC20;
    using Address for address;

    /// ------------------------------- Types -------------------------------

    error UserNotRelayer();
    error InvalidSigner();
    error InvalidAmount();
    error ExpiredRequest();
    error UnsupportedCall();
    error FeeTooHigh();
    error ForwarderNotApprovedByProcessor();
    error NotSupportedModule();
    error UnsupportedToken();

    event RelayerSet(address indexed relayer, bool isRelayer);
    event SupportedModuleSet(address indexed module, bool isSupported);
    event FeeUpdated(uint256 feeBps);
    event CancellationGasCostUpdated(uint256 gas);
    event EthUsdOracleSet(address indexed oracle);
    event PaymentOracleSet(address indexed paymentToken, address indexed oracle);
    event UserOperationSponsored(
        address indexed user,
        address indexed paymentToken,
        uint256 actualTokenCharge,
        uint256 actualGasCost,
        uint256 actualTokenPrice
    );

    /// ------------------------------- Constants -------------------------------

    bytes private constant FORWARDREQUEST_TYPE = abi.encodePacked(
        "ForwardRequest(address user,address to,address paymentToken,bytes data,uint64 deadline,uint256 nonce)"
    );
    bytes32 private constant FORWARDREQUEST_TYPEHASH = keccak256(FORWARDREQUEST_TYPE);

    /// ------------------------------- Storage -------------------------------

    /// @inheritdoc IForwarder
    uint16 public feeBps;

    /// @inheritdoc IForwarder
    uint256 public cancellationGasCost;

    /// @notice The set of supported modules.
    mapping(address => bool) public isSupportedModule;

    /// @inheritdoc IForwarder
    mapping(address => bool) public isRelayer;

    /// @inheritdoc IForwarder
    mapping(bytes32 => address) public orderSigner;

    address public ethUsdOracle;

    mapping(address => address) public paymentOracle;

    /// ------------------------------- Modifiers -------------------------------

    modifier onlyRelayer() {
        if (!isRelayer[msg.sender]) {
            revert UserNotRelayer();
        }
        _;
    }

    /// ------------------------------- Initialization -------------------------------

    /// @notice Constructs the Forwarder contract.
    /// @dev Initializes the domain separator used for EIP-712 compliant signature verification.
    constructor(address _ethUsdOracle) EIP712("Forwarder", "1") Ownable(msg.sender) {
        feeBps = 0;
        cancellationGasCost = 0;
        ethUsdOracle = _ethUsdOracle;
    }

    /// ------------------------------- Administration -------------------------------

    /// @notice Sets Relayer address state.
    /// @dev Only callable by the contract owner.
    function setRelayer(address newRelayer, bool _isRelayer) external onlyOwner {
        isRelayer[newRelayer] = _isRelayer;
        emit RelayerSet(newRelayer, _isRelayer);
    }

    /// @notice Sets the address of a supported module.
    /// @dev Only callable by the contract owner.
    function setSupportedModule(address module, bool isSupported) external onlyOwner {
        isSupportedModule[module] = isSupported;
        emit SupportedModuleSet(module, isSupported);
    }

    /// @notice Updates the fee rate.
    /// @dev Only callable by the contract owner.
    /// @param newFeeBps The new fee rate in basis points.
    function setFeeBps(uint16 newFeeBps) external onlyOwner {
        if (newFeeBps > 10000) revert FeeTooHigh();

        feeBps = newFeeBps;
        emit FeeUpdated(newFeeBps);
    }

    /// @notice Updates the cancellation gas cost estimate.
    /// @dev Only callable by the contract owner.
    /// @param newCancellationGasCost The new cancellation fee.
    function setCancellationGasCost(uint256 newCancellationGasCost) external onlyOwner {
        cancellationGasCost = newCancellationGasCost;
        emit CancellationGasCostUpdated(newCancellationGasCost);
    }

    /**
     * @dev add oracle for eth in usd
     * @param _ethUsdOracle chainlink oracle address
     */
    function setEthUsdOracle(address _ethUsdOracle) external onlyOwner {
        ethUsdOracle = _ethUsdOracle;
        emit EthUsdOracleSet(_ethUsdOracle);
    }

    /**
     * @dev add oracle for a payment token
     * @param paymentToken asset to add oracle
     * @param oracle chainlink oracle address
     */
    function setPaymentOracle(address paymentToken, address oracle) external onlyOwner {
        paymentOracle[paymentToken] = oracle;
        emit PaymentOracleSet(paymentToken, oracle);
    }

    /**
     * @notice Rescue ERC20 tokens locked up in this contract.
     * @param tokenContract ERC20 token contract address
     * @param to        Recipient address
     * @param amount    Amount to withdraw
     */
    function rescueERC20(IERC20 tokenContract, address to, uint256 amount) external onlyOwner {
        tokenContract.safeTransfer(to, amount);
    }

    /**
     * @notice Get the current oracle price for a payment token
     */
    function getPaymentPriceInWei(address paymentToken) public view returns (uint256) {
        if (paymentOracle[paymentToken] == address(0)) revert UnsupportedToken();
        return _getPaymentPriceInWei(paymentToken);
    }

    function _getPaymentPriceInWei(address paymentToken) internal view returns (uint256) {
        address _oracle = paymentOracle[paymentToken];
        // slither-disable-next-line unused-return
        (, int256 paymentPrice,,,) = AggregatorV3Interface(_oracle).latestRoundData();
        // slither-disable-next-line unused-return
        (, int256 ethUSDPrice,,,) = AggregatorV3Interface(ethUsdOracle).latestRoundData();
        // adjust values to align decimals
        uint8 paymentPriceDecimals = AggregatorV3Interface(_oracle).decimals();
        uint8 ethUSDPriceDecimals = AggregatorV3Interface(ethUsdOracle).decimals();
        if (paymentPriceDecimals > ethUSDPriceDecimals) {
            ethUSDPrice = ethUSDPrice * int256(10 ** (paymentPriceDecimals - ethUSDPriceDecimals));
        } else if (paymentPriceDecimals < ethUSDPriceDecimals) {
            paymentPrice = paymentPrice * int256(10 ** (ethUSDPriceDecimals - paymentPriceDecimals));
        }
        // compute payment price in wei
        uint256 paymentPriceInWei = PrbMath.mulDiv(uint256(paymentPrice), 1 ether, uint256(ethUSDPrice));
        return uint256(paymentPriceInWei);
    }

    /// ------------------------------- Forwarding -------------------------------

    /// @inheritdoc IForwarder
    function forwardFunctionCall(ForwardRequest calldata metaTx)
        external
        onlyRelayer
        nonReentrant
        returns (bytes memory result)
    {
        uint256 gasStart = gasleft();
        _validateForwardRequest(metaTx);

        // Get the function selector
        bytes4 functionSelector = bytes4(metaTx.data[:4]);
        // Check call
        if (functionSelector == IOrderProcessor.requestOrder.selector) {
            // Check if function selector is request Order to approve quantityIn
            // Get order from data
            (IOrderProcessor.Order memory order) = abi.decode(metaTx.data[4:], (IOrderProcessor.Order));
            _requestOrderPreparation(order, metaTx.user, metaTx.to);
        } else if (functionSelector == IOrderProcessor.requestCancel.selector) {
            // Check if cancel request is from the original order signer
            // Get data from metaTx
            (address recipient, uint256 index) = abi.decode(metaTx.data[4:], (address, uint256));
            bytes32 orderId = IOrderProcessor(metaTx.to).getOrderId(recipient, index);
            if (orderSigner[orderId] != metaTx.user) revert InvalidSigner();
        } else {
            revert UnsupportedCall();
        }

        // execute low level call to issuer
        result = metaTx.to.functionCall(metaTx.data);

        if (functionSelector == IOrderProcessor.requestOrder.selector) {
            uint256 id = abi.decode(result, (uint256));
            // get order ID
            bytes32 orderId = IOrderProcessor(metaTx.to).getOrderId(metaTx.user, id);
            orderSigner[orderId] = metaTx.user;
        }

        // handle transaction payment
        if (functionSelector == IOrderProcessor.requestOrder.selector) {
            uint256 assetPriceInWei = getPaymentPriceInWei(metaTx.paymentToken);
            _handlePayment(metaTx.user, metaTx.paymentToken, assetPriceInWei, gasStart);
        }
    }

    /**
     * @dev Validates the forward request by checking the oracle price, target address, deadline,
     *      verifying the price attestation, checking the nonce, and ensuring that the signer of the request is valid.
     * @param metaTx The meta transaction containing the user address, target contract, encoded function call data,
     *      deadline, nonce, payment token oracle price, and the signature components (v, r, s).
     */
    function _validateForwardRequest(ForwardRequest calldata metaTx) internal {
        if (metaTx.deadline < block.timestamp) revert ExpiredRequest();
        if (!isSupportedModule[metaTx.to]) revert NotSupportedModule();
        // slither-disable-next-line unused-return
        _useCheckedNonce(metaTx.user, metaTx.nonce);

        if (paymentOracle[metaTx.paymentToken] == address(0)) revert UnsupportedToken();

        bytes32 typedDataHash = _hashTypedDataV4(forwardRequestHash(metaTx));

        address signer = ECDSA.recover(typedDataHash, metaTx.signature);
        if (signer != metaTx.user) revert InvalidSigner();

        // Verify that orderprocessor has approved this as forwarder
        if (!IOrderProcessor(metaTx.to).hasRole(IOrderProcessor(metaTx.to).FORWARDER_ROLE(), address(this))) {
            revert ForwarderNotApprovedByProcessor();
        }
    }

    /// @inheritdoc IForwarder
    function forwardRequestHash(ForwardRequest calldata metaTx) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                FORWARDREQUEST_TYPEHASH,
                metaTx.user,
                metaTx.to,
                metaTx.paymentToken,
                keccak256(metaTx.data),
                metaTx.deadline,
                metaTx.nonce
            )
        );
    }

    /**
     * @dev Prepares an order request by transferring tokens from the user to this contract,
     *      and approving the specified target contract to spend the tokens.
     *      This function supports preparation for both buying and selling orders.
     *
     * @param order The details of the order, including payment and asset tokens, and the quantity.
     * @param user The address of the user initiating the order.
     * @param target The address of the target contract (e.g. BuyProcessor or SellProcessor) that will execute the order.
     */
    function _requestOrderPreparation(IOrderProcessor.Order memory order, address user, address target) internal {
        // Pull tokens from user and approve module to spend
        if (order.sell) {
            // slither-disable-next-line arbitrary-send-erc20
            IERC20(order.assetToken).safeTransferFrom(user, address(this), order.assetTokenQuantity);
            IERC20(order.assetToken).safeIncreaseAllowance(target, order.assetTokenQuantity);
        } else {
            uint256 fees = IOrderProcessor(target).estimateTotalFeesForOrder(
                user, order.sell, order.paymentToken, order.paymentTokenQuantity
            );
            // slither-disable-next-line arbitrary-send-erc20
            IERC20(order.paymentToken).safeTransferFrom(user, address(this), order.paymentTokenQuantity + fees);
            IERC20(order.paymentToken).safeIncreaseAllowance(target, order.paymentTokenQuantity + fees);
        }
    }

    /**
     * @dev Handles the payment of transaction fees in the form of tokens. Calculates the
     *      gas used for the transaction and transfers the equivalent amount in tokens from
     *      the user to the relayer.
     *
     * @param user The address of the user who is paying the transaction fees.
     * @param paymentToken The address of the ERC20 token used for payment.
     * @param paymentTokenPrice The price of the payment token in terms of wei.
     * @param gasStart The amount of gas at the start of the transaction.
     */
    function _handlePayment(address user, address paymentToken, uint256 paymentTokenPrice, uint256 gasStart) internal {
        uint256 gasUsed = gasStart - gasleft();
        // Calculate total gas cost in wei
        uint256 totalGasCostInWei = (gasUsed + cancellationGasCost) * tx.gasprice;
        // Apply payment token price to calculate payment amount
        // Assumes payment token price includes token decimals
        uint256 paymentAmount = 0;
        try IERC20Metadata(paymentToken).decimals() returns (uint8 value) {
            paymentAmount = totalGasCostInWei * 10 ** value / paymentTokenPrice;
        } catch {
            paymentAmount = totalGasCostInWei / paymentTokenPrice;
        }

        // Apply forwarder fee
        // slither-disable-next-line divide-before-multiply
        uint256 fee = (paymentAmount * feeBps) / 10000;
        uint256 actualTokenCharge = paymentAmount + fee;

        emit UserOperationSponsored(user, paymentToken, actualTokenCharge, totalGasCostInWei, paymentTokenPrice);
        // Transfer the payment for gas fees
        // slither-disable-next-line arbitrary-send-erc20
        IERC20(paymentToken).safeTransferFrom(user, msg.sender, actualTokenCharge);
    }

    // slither-disable-next-line naming-convention
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
}
