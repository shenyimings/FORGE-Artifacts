// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { TimelockController } from '@openzeppelin/contracts/governance/TimelockController.sol';
import { AccessControl } from '@openzeppelin/contracts/access/AccessControl.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { IERC20Permit } from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { ReentrancyGuard } from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import { IFundSwapEvents, IFundSwapErrors } from './IFundSwap.sol';
import { PublicOrder, SwapResult, OrderFillRequest } from './OrderStructs.sol';
import { FundSwapOrderManager } from './FundSwapOrderManager.sol';
import { OrderLib } from './libraries/OrderLib.sol';
import { PluginBase } from './plugins/PluginBase.sol';
import { PluginLib, PluginsToRun } from './libraries/PluginLib.sol';
import { OrderSignatureVerifierLib } from './libraries/OrderSignatureVerifierLib.sol';
import { TokenTreasuryLib, Treasury } from './libraries/TokenTreasuryLib.sol';
import { EnumerableSet } from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @notice FundSwap is a non-custodial spot exchange for ERC-20 tokens compatible with EVM chains.
 * It allows to create orders that are represented as ERC-721 tokens. There is a couple of periphery
 * contracts that allow to create off-chain private or fill multiple orders in a single batch.
 * FundSwap is easily extendable, it has a plugin system that allows to hook into the transaction lifecycle
 * and execute custom logic when orders are created, filled or cancelled. The exchange also supports
 * routing through a chain of orders.
 */
contract FundSwap is IFundSwapEvents, IFundSwapErrors, AccessControl, ReentrancyGuard {
  using SafeERC20 for IERC20;
  using TokenTreasuryLib for Treasury;
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @dev manager for public orders (ERC721)
  FundSwapOrderManager public immutable orderManager;
  /// @dev list of plugins
  EnumerableSet.AddressSet private plugins;
  /// @dev computed plugin call configs stored in a more query-friendly way
  PluginsToRun private pluginCallConfigs;
  /// @dev treasury state that keeps track of all tokens needed for orders to be fully backed
  Treasury private tokenTreasury;

  /// @dev role that allows the entity to withdraw fees
  bytes32 public constant TREASURY_OWNER = keccak256('TREASURY_OWNER');

  constructor() {
    orderManager = new FundSwapOrderManager();
    _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _grantRole(TREASURY_OWNER, _msgSender());
  }

  // ======== PLUGIN FUNCTIONS ========

  /**
   * @return list of currently enabled plugins
   */
  function getPlugins() external view returns (address[] memory) {
    return plugins.values();
  }

  /**
   * @notice Allows to enable a plugin
   * @param plugin a plugin address to be enabled
   * @param initData additional init data. Bytes format is used so it can be abi decoded on the plugin side.
   */
  function enablePlugin(
    PluginBase plugin,
    bytes memory initData
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (!plugins.add(address(plugin))) return;

    PluginLib.storePluginCallConfig(pluginCallConfigs, plugin);
    plugin.enable(initData);
    emit PluginEnabled(address(plugin));
  }

  /**
   * @notice Allows to disable a plugin
   * @param plugin a plugin address to be disabled
   * @param data additional data for disable function. Bytes format is used so it can be abi decoded
   * on the plugin side.
   */
  function disablePlugin(
    PluginBase plugin,
    bytes memory data
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (!plugins.remove(address(plugin))) return;

    PluginLib.removePluginCallConfig(pluginCallConfigs, plugin);
    plugin.disable(data);
    emit PluginDisabled(address(plugin));
  }

  // ======== TREASURY FUNCTIONS ========

  /**
   * Withdraws tokens from the contract. Treasury keeps track of all tokens needed for orders to be fully backed so
   * owner cannot drain the contract. Owner can only withdraw tokens that contract holds on top of what is needed
   * for the contract to be fully backed. Usefull for collecting fees and rescuing tokens that were sent to the
   * contract by mistake.
   * @param token token to withdraw
   * @param amount amount to withdraw
   */
  function withdraw(
    address token,
    uint256 amount
  ) external nonReentrant onlyRole(TREASURY_OWNER) {
    uint256 tokensNeededForOrdersToBeFullyBacked = tokenTreasury.getBalance(token);
    uint256 tokensAvailibleToWithdraw = IERC20(token).balanceOf(address(this)) -
      tokensNeededForOrdersToBeFullyBacked;

    if (amount > tokensAvailibleToWithdraw) {
      revert FundSwap__WithdrawalViolatesFullBackingRequirement();
    }

    IERC20(token).safeTransfer(_msgSender(), amount);
  }

  /**
   * @notice Allows to check what amount of a given token is needed for all orders to be fully backed.
   * @param token token to check
   * @return amount of tokens needed for all orders to be fully backed
   */
  function getRequiredTreasuryBalance(address token) external view returns (uint256) {
    return tokenTreasury.getBalance(token);
  }

  // ======== PUBLIC ORDER FUNCTIONS ========

  /**
   * @notice Gets the public order ID by hashing the order data.
   * @param order public order data
   * @return hash of the order
   */
  function getPublicOrderHash(PublicOrder memory order) public view returns (bytes32) {
    return OrderSignatureVerifierLib.hashPublicOrder(order);
  }

  /**
   * @notice Creates a public order with a permit signature so that the public order can be created
   * in a single transaction.
   * @param order public order data
   * @param deadline deadline for the permit signature
   * @param v signature parameter
   * @param r signature parameter
   * @param s signature parameter
   * @return orderId ID of the created order
   */
  function createPublicOrderWithPermit(
    PublicOrder calldata order,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (bytes32 orderId) {
    IERC20Permit(order.makerSellToken).permit(
      _msgSender(),
      address(this),
      order.makerSellTokenAmount,
      deadline,
      v,
      r,
      s
    );
    return createPublicOrder(order);
  }

  /**
   * @notice Creates a public order. The token that maker sells must be approved for transfer to
   * the exchange. Only whitelisted tokens can be used.
   * @param order public order data
   * @return orderHash ID of the created order
   */
  function createPublicOrder(
    PublicOrder memory order
  ) public nonReentrant returns (bytes32 orderHash) {
    if (order.makerSellTokenAmount == 0) revert FundSwap__MakerSellTokenAmountIsZero();
    if (order.makerBuyTokenAmount == 0) revert FundSwap__MakerBuyTokenAmountIsZero();
    if (order.makerBuyToken == order.makerSellToken) revert FundSwap__InvalidPath();

    order = PluginLib.runBeforeOrderCreation(pluginCallConfigs, order);

    orderHash = getPublicOrderHash(order);

    orderManager.safeMint(_msgSender(), order);

    uint256 initialFundswapBalanceOfMakerSellToken = IERC20(order.makerSellToken)
      .balanceOf(address(this));

    IERC20(order.makerSellToken).safeTransferFrom(
      _msgSender(),
      address(this),
      order.makerSellTokenAmount
    );

    if (
      initialFundswapBalanceOfMakerSellToken + order.makerSellTokenAmount !=
      IERC20(order.makerSellToken).balanceOf(address(this))
    ) {
      revert FundSwap__TransferFeeTokensNotSupported(order.makerSellToken);
    }

    tokenTreasury.add(order.makerSellToken, order.makerSellTokenAmount);

    emit PublicOrderCreated(
      orderHash,
      orderManager.orderHashTotokenId(orderHash),
      order.makerSellToken,
      order.makerBuyToken,
      order.makerSellTokenAmount,
      order.makerBuyTokenAmount,
      _msgSender(),
      order.deadline,
      order.creationTimestamp
    );

    order = PluginLib.runAfterOrderCreation(pluginCallConfigs, order);
  }

  /**
   * @notice Cancels a public order. Only the order owner can cancel it. The token that maker sells
   * is transferred back to the order owner.
   * @param orderHash Hash of the order to fill
   */
  function cancelOrder(bytes32 orderHash) external nonReentrant {
    PublicOrder memory order = orderManager.getOrder(orderHash);
    address orderOwner = orderManager.ownerOfByHash(orderHash);
    if (orderOwner != _msgSender()) revert FundSwap__NotAnOwner();

    order = PluginLib.runBeforeOrderCancel(pluginCallConfigs, order);

    IERC20(order.makerSellToken).safeTransfer(_msgSender(), order.makerSellTokenAmount);
    tokenTreasury.subtract(order.makerSellToken, order.makerSellTokenAmount);

    emit PublicOrderCancelled(
      orderHash,
      orderManager.orderHashTotokenId(orderHash),
      order.makerSellToken,
      order.makerBuyToken,
      orderOwner
    );

    orderManager.burn(orderHash);

    order = PluginLib.runAfterOrderCancel(pluginCallConfigs, order);
  }

  /**
   * @notice Fills a public order with permit signature so that the public order can be filled in a
   * single transaction. Only whitelisted tokens can be used.
   * @param orderHash Hash of an order to fill
   * @param tokenDestination a recipient of the output token
   * @param deadline deadline for the permit signature
   * @param v signature parameter
   * @param r signature parameter
   * @param s signature parameter
   * @return result swap result with data like the amount of output token received and amount of input token spent
   */
  function fillPublicOrderWithPermit(
    bytes32 orderHash,
    address tokenDestination,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (SwapResult memory result) {
    PublicOrder memory order = orderManager.getOrder(orderHash);
    IERC20Permit(order.makerBuyToken).permit(
      _msgSender(),
      address(this),
      order.makerBuyTokenAmount,
      deadline,
      v,
      r,
      s
    );
    return _fillPublicOrder(orderHash, order, tokenDestination);
  }

  /**
   * @notice Fills a public order. The maker buy token of the order must be approved for transfer
   * to the exchange. Only whitelisted tokens can be used.
   * @param orderHash hash of an order to fill
   * @param tokenDestination a recipient of the output token
   * @return result swap result with data like the amount of output token received and amount
   * of input token spent
   */
  function fillPublicOrder(
    bytes32 orderHash,
    address tokenDestination
  ) public returns (SwapResult memory result) {
    PublicOrder memory order = orderManager.getOrder(orderHash);
    return _fillPublicOrder(orderHash, order, tokenDestination);
  }

  function _fillPublicOrder(
    bytes32 orderHash,
    PublicOrder memory order,
    address tokenDestination
  ) internal nonReentrant returns (SwapResult memory result) {
    if (order.makerBuyToken == address(0)) {
      if (order.makerSellToken == address(0)) {
        revert FundSwap__OrderDoesNotExist();
      }
    }
    if (order.deadline != 0) {
      if (block.timestamp > order.deadline) {
        revert FundSwap__OrderExpired();
      }
    }

    address orderOwner = orderManager.ownerOfByHash(orderHash);

    tokenTreasury.subtract(order.makerSellToken, order.makerSellTokenAmount);

    order = PluginLib.runBeforeOrderFill(pluginCallConfigs, order);

    result = SwapResult({
      outputToken: order.makerSellToken,
      outputAmount: order.makerSellTokenAmount,
      inputToken: order.makerBuyToken,
      inputAmount: order.makerBuyTokenAmount
    });

    // transfer tokens on behalf of the order filler to the order owner
    IERC20(order.makerBuyToken).safeTransferFrom(
      _msgSender(),
      orderOwner,
      order.makerBuyTokenAmount
    );

    // Transfer tokens to the taker on behalf of the order owner that were
    // deposited to this contract when the order was created.
    IERC20(order.makerSellToken).safeTransfer(
      tokenDestination,
      order.makerSellTokenAmount
    );

    uint256 tokenId = orderManager.orderHashTotokenId(orderHash);

    orderManager.burn(orderHash);

    emit PublicOrderFilled(
      orderHash,
      tokenId,
      order.makerSellToken,
      order.makerBuyToken,
      orderOwner,
      _msgSender()
    );

    order = PluginLib.runAfterOrderFill(pluginCallConfigs, order);
  }

  /**
   * @notice Fills a public order partially with permit signature so that the public order can be filled in a
   * single transaction. Only whitelisted tokens can be used.
   * @param orderFillRequest Order fill request data
   * @param tokenDestination a recipient of the output token
   * @param deadline deadline for the permit signature
   * @param v signature parameter
   * @param r signature parameter
   * @param s signature parameter
   * @return result swap result with data like the amount of output token received and amount of input token spent
   */
  function fillPublicOrderPartiallyWithPermit(
    OrderFillRequest memory orderFillRequest,
    address tokenDestination,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (SwapResult memory result) {
    PublicOrder memory order = orderManager.getOrder(orderFillRequest.orderHash);
    uint256 amountToApprove = orderFillRequest.amountIn;
    IERC20Permit(order.makerBuyToken).permit(
      _msgSender(),
      address(this),
      amountToApprove,
      deadline,
      v,
      r,
      s
    );
    return _fillPublicOrderPartially(orderFillRequest, order, tokenDestination);
  }

  /**
   * @notice Fills a public order partially. The maker buy token of the order must be approved
   * for transfer to the exchange. Only whitelisted tokens can be used.
   * @param orderFillRequest Order fill request data
   * @return result swap result with data like the amount of output token received and amount
   * of input token spent
   */
  function fillPublicOrderPartially(
    OrderFillRequest memory orderFillRequest,
    address tokenDestination
  ) external returns (SwapResult memory result) {
    PublicOrder memory order = orderManager.getOrder(orderFillRequest.orderHash);
    return _fillPublicOrderPartially(orderFillRequest, order, tokenDestination);
  }

  function _fillPublicOrderPartially(
    OrderFillRequest memory orderFillRequest,
    PublicOrder memory order,
    address tokenDestination
  ) internal nonReentrant returns (SwapResult memory result) {
    if (order.deadline != 0) {
      if (block.timestamp > order.deadline) {
        revert FundSwap__OrderExpired();
      }
    }
    if (orderFillRequest.amountIn >= order.makerBuyTokenAmount) {
      revert FundSwap__AmountInExceededLimit();
    }

    (
      uint256 newMakerBuyTokenAmount,
      uint256 newMakerSellTokenAmount,
      uint256 outputAmount
    ) = _fillExactInputPublicOrderPartially(orderFillRequest, order, tokenDestination);
    order.makerBuyTokenAmount = newMakerBuyTokenAmount;
    order.makerSellTokenAmount = newMakerSellTokenAmount;

    result = SwapResult({
      outputToken: order.makerSellToken,
      outputAmount: outputAmount,
      inputToken: order.makerBuyToken,
      inputAmount: orderFillRequest.amountIn
    });

    orderManager.updateOrder(orderFillRequest.orderHash, order);

    emit PublicOrderPartiallyFilled(
      orderFillRequest.orderHash,
      orderManager.orderHashTotokenId(orderFillRequest.orderHash),
      _msgSender(),
      result.inputAmount,
      result.outputAmount,
      order.makerSellTokenAmount,
      order.makerBuyTokenAmount
    );

    return result;
  }

  function _fillExactInputPublicOrderPartially(
    OrderFillRequest memory orderFillRequest,
    PublicOrder memory order,
    address tokenDestination
  )
    internal
    returns (
      uint256 newMakerBuyTokenAmount,
      uint256 newMakerSellTokenAmount,
      uint256 fillAmountOut
    )
  {
    (newMakerBuyTokenAmount, newMakerSellTokenAmount, , fillAmountOut) = OrderLib
      .calculateOrderAmountsAfterFill(orderFillRequest, order);

    if (fillAmountOut < orderFillRequest.minAmountOut) {
      revert FundSwap__InsufficientOutputAmount(
        orderFillRequest.minAmountOut,
        fillAmountOut
      );
    }

    tokenTreasury.subtract(order.makerSellToken, fillAmountOut);

    PublicOrder memory modifiedOrder = PluginLib.runBeforeOrderFill(
      pluginCallConfigs,
      // for partial fill we need to prepare a hypotetical order with the acutal amount of tokens that will be filled
      // in order for plugins to calculate data correctly
      PublicOrder({
        makerSellToken: order.makerSellToken,
        makerBuyToken: order.makerBuyToken,
        makerSellTokenAmount: fillAmountOut,
        makerBuyTokenAmount: orderFillRequest.amountIn,
        deadline: order.deadline,
        creationTimestamp: order.creationTimestamp
      })
    );
    fillAmountOut = modifiedOrder.makerSellTokenAmount;

    // pay the order owner
    IERC20(modifiedOrder.makerBuyToken).safeTransferFrom(
      _msgSender(),
      orderManager.ownerOfByHash(orderFillRequest.orderHash),
      orderFillRequest.amountIn
    );

    IERC20(modifiedOrder.makerSellToken).safeTransfer(tokenDestination, fillAmountOut);

    modifiedOrder = PluginLib.runAfterOrderFill(pluginCallConfigs, modifiedOrder);
  }
}
