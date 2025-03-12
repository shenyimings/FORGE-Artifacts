// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

// interfaces
import {IgETH} from "../../interfaces/IgETH.sol";
import {ILiquidityModule} from "../../interfaces/modules/ILiquidityModule.sol";
// libraries
import {LiquidityModuleLib as LML} from "./libs/LiquidityModuleLib.sol";
import {AmplificationLib as AL} from "./libs/AmplificationLib.sol";
// contracts
import {ILPToken} from "../../interfaces/helpers/ILPToken.sol";
// external
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ERC1155HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title LM: Liquidity Module
 *
 * @notice A StableSwap implementation for ERC1155 staking derivatives, gETH.
 * * Users become an LP (Liquidity Provider) by depositing their tokens
 * * in desired ratios for an exchange of the pool token that represents their share of the pool.
 * * Users can burn pool tokens and withdraw their share of token(s).
 * * Each time a swap between the pooled tokens happens, a set fee incurs which effectively gets
 * * distributed to the LPs.
 * * In case of emergencies, admin can pause additional deposits, swaps, or single-asset withdraws - which
 * * stops the ratio of the tokens in the pool from changing.
 * * Users can always withdraw their tokens via multi-asset withdraws.
 *
 * @dev There are no additional functionalities implemented seperately from the library.
 * * However, this module inherits and implements nonReentrant & whenNotPaused modifiers.
 * * LM has pausability and expects inheriting contract to provide the access control mechanism.
 *
 * @dev review: this module delegates its functionality to LML (LiquidityModuleLib).
 *
 * @dev 7 functions need to be overriden with access control when inherited:
 * * pause, unpause, setSwapFee, setAdminFee, withdrawAdminFees, rampA, stopRampA.
 *
 * @dev __LiquidityModule_init (or _unchained) call is NECESSARY when inherited.
 *
 * note This module utilizes modifiers but does not implement necessary admin checks; or pausability overrides.
 * * If a package inherits LM, should implement it's own logic around those.
 *
 * @author Ice Bear & Crash Bandicoot
 */
abstract contract LiquidityModule is
  ILiquidityModule,
  ERC1155HolderUpgradeable,
  PausableUpgradeable,
  ReentrancyGuardUpgradeable
{
  using LML for LML.Swap;
  using AL for LML.Swap;

  /**
   * @custom:section                           ** VARIABLES **
   *
   * @dev Do not add any other variables here. Modules do NOT have a gap.
   * Library's main struct has a gap, providing up to 16 storage slots for this module.
   */
  LML.Swap internal LIQUIDITY;

  /**
   * @custom:section                           ** EVENTS **
   */
  event TokenSwap(
    address indexed buyer,
    uint256 tokensSold,
    uint256 tokensBought,
    uint128 soldId,
    uint128 boughtId
  );
  event AddLiquidity(
    address indexed provider,
    uint256[2] tokenAmounts,
    uint256[2] fees,
    uint256 invariant,
    uint256 lpTokenSupply
  );
  event RemoveLiquidity(address indexed provider, uint256[2] tokenAmounts, uint256 lpTokenSupply);
  event RemoveLiquidityOne(
    address indexed provider,
    uint256 lpTokenAmount,
    uint256 lpTokenSupply,
    uint256 boughtId,
    uint256 tokensBought
  );
  event RemoveLiquidityImbalance(
    address indexed provider,
    uint256[2] tokenAmounts,
    uint256[2] fees,
    uint256 invariant,
    uint256 lpTokenSupply
  );
  event NewAdminFee(uint256 newAdminFee);
  event NewSwapFee(uint256 newSwapFee);
  event NewWithdrawFee(uint256 newWithdrawFee);
  event RampA(uint256 oldA, uint256 newA, uint256 initialTime, uint256 futureTime);
  event StopRampA(uint256 currentA, uint256 time);

  /**
   * @custom:section                           ** MODIFIERS **
   */

  /**
   * @notice Modifier to check deadline against current timestamp
   * @param deadline latest timestamp to accept this transaction
   */
  modifier deadlineCheck(uint256 deadline) {
    require(block.timestamp <= deadline, "LM:Deadline not met");
    _;
  }

  /**
   * @custom:section                           ** ABSTRACT FUNCTIONS **
   *
   * @dev these functions MUST be overriden for admin functionality.
   */

  /**
   * @dev -> external
   */
  function pause() external virtual override;

  function unpause() external virtual override;

  /**
   * @notice Update the swap fee to be applied on swaps
   * @param newSwapFee new swap fee to be applied on future transactions
   */
  function setSwapFee(uint256 newSwapFee) external virtual override;

  /**
   * @notice Update the admin fee. Admin fee takes portion of the swap fee.
   * @param newAdminFee new admin fee to be applied on future transactions
   */
  function setAdminFee(uint256 newAdminFee) external virtual override;

  /**
   * @notice Withdraw all admin fees to the contract owner
   */
  function withdrawAdminFees(address receiver) external virtual override;

  /**
   * @notice Start ramping up or down A parameter towards given futureA and futureTime
   * Checks if the change is too rapid, and commits the new A value only when it falls under
   * the limit range.
   * @param futureA the new A to ramp towards
   * @param futureTime timestamp when the new A should be reached
   */
  function rampA(uint256 futureA, uint256 futureTime) external virtual override;

  /**
   * @notice Stop ramping A immediately. Reverts if ramp A is already stopped.
   */
  function stopRampA() external virtual override;

  /**
   * @custom:section                           ** INITIALIZING **
   */

  function __LiquidityModule_init(
    address _gETH_position,
    address _lpToken_referance,
    uint256 _pooledTokenId,
    uint256 _A,
    uint256 _swapFee,
    string memory _poolName
  ) internal onlyInitializing {
    __ReentrancyGuard_init();
    __Pausable_init();
    __ERC1155Holder_init();
    __LiquidityModule_init_unchained(
      _gETH_position,
      _lpToken_referance,
      _pooledTokenId,
      _A,
      _swapFee,
      _poolName
    );
  }

  function __LiquidityModule_init_unchained(
    address _gETH_position,
    address _lpToken_referance,
    uint256 _pooledTokenId,
    uint256 _A,
    uint256 _swapFee,
    string memory _poolName
  ) internal onlyInitializing {
    require(_gETH_position != address(0), "LM:_gETH_position can not be zero");
    require(_lpToken_referance != address(0), "LM:_lpToken_referance can not be zero");
    require(_pooledTokenId != 0, "LM:_pooledTokenId can not be zero");
    require(_A != 0, "LM:_A can not be zero");
    require(_A < AL.MAX_A, "LM:_A exceeds maximum");
    require(_swapFee < LML.MAX_SWAP_FEE, "LM:_swapFee exceeds maximum");

    // Clone and initialize a LPToken contract
    ILPToken _lpToken = ILPToken(Clones.clone(_lpToken_referance));
    string memory name_prefix = "Geode LP Token: ";
    string memory symbol_suffix = "-LP";
    _lpToken.initialize(
      string(abi.encodePacked(name_prefix, _poolName)),
      string(abi.encodePacked(_poolName, symbol_suffix))
    );

    LIQUIDITY.gETH = IgETH(_gETH_position);
    LIQUIDITY.lpToken = _lpToken;
    LIQUIDITY.pooledTokenId = _pooledTokenId;
    LIQUIDITY.initialA = _A * AL.A_PRECISION;
    LIQUIDITY.futureA = _A * AL.A_PRECISION;
    LIQUIDITY.swapFee = _swapFee;

    // Do not trust middlewares. Protect LPs, gETH tokens from
    // issues that can be surfaced with future middlewares.
    LIQUIDITY.gETH.avoidMiddlewares(_pooledTokenId, true);
  }

  /**
   * @custom:section                           ** GETTER FUNCTIONS **
   *
   * @custom:visibility -> view-external
   */

  function LiquidityParams()
    external
    view
    virtual
    override
    returns (
      address gETH,
      address lpToken,
      uint256 pooledTokenId,
      uint256 initialA,
      uint256 futureA,
      uint256 initialATime,
      uint256 futureATime,
      uint256 swapFee,
      uint256 adminFee
    )
  {
    gETH = address(LIQUIDITY.gETH);
    lpToken = address(LIQUIDITY.lpToken);
    pooledTokenId = LIQUIDITY.pooledTokenId;
    initialA = LIQUIDITY.initialA;
    futureA = LIQUIDITY.futureA;
    initialATime = LIQUIDITY.initialATime;
    futureATime = LIQUIDITY.futureATime;
    swapFee = LIQUIDITY.swapFee;
    adminFee = LIQUIDITY.adminFee;
  }

  /**
   * @notice Return A, the amplification coefficient * n * (n - 1)
   * @dev See the StableSwap paper for details
   * @return A parameter
   */
  function getA() external view virtual override returns (uint256) {
    return LIQUIDITY.getA();
  }

  /**
   * @notice Return A in its raw precision form
   * @dev See the StableSwap paper for details
   * @return A parameter in its raw precision form
   */
  function getAPrecise() external view virtual override returns (uint256) {
    return LIQUIDITY.getAPrecise();
  }

  /**
   * @notice Debt, The amount of buyback for stable pricing (1=1).
   * @return debt the half of the D StableSwap invariant when debt is needed to be payed.
   * @dev result might change when price is in.
   */
  function getDebt() external view virtual override returns (uint256) {
    return LIQUIDITY.getDebt();
  }

  /**
   * @notice Return current balance of the pooled token at given index
   * @param index the index of the token
   * @return current balance of the pooled token at given index with token's native precision
   */
  function getBalance(uint8 index) external view virtual override returns (uint256) {
    return LIQUIDITY.balances[index];
  }

  /**
   * @notice Get the virtual override price, to help calculate profit
   * @return the virtual override price
   */
  function getVirtualPrice() external view virtual override returns (uint256) {
    return LIQUIDITY.getVirtualPrice();
  }

  /**
   * @notice Reads the accumulated amount of admin fees of the token with given index
   * @param index Index of the pooled token
   * @return admin's token balance in the token's precision
   */
  function getAdminBalance(uint256 index) external view virtual override returns (uint256) {
    return LIQUIDITY.getAdminBalance(index);
  }

  /**
   * @custom:section                           ** HELPER FUNCTIONS **
   *
   * @custom:visibility -> view-external
   */

  /**
   * @notice Calculate amount of tokens you receive on swap
   * @param tokenIndexFrom the token the user wants to sell
   * @param tokenIndexTo the token the user wants to buy
   * @param dx the amount of tokens the user wants to sell. If the token charges
   * a fee on transfers, use the amount that gets transferred after the fee.
   * @return amount of tokens the user will receive
   */
  function calculateSwap(
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx
  ) external view virtual override returns (uint256) {
    return LIQUIDITY.calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
  }

  /**
   * @notice A simple method to calculate prices from deposits or
   * withdrawals, excluding fees but including slippage. This is
   * helpful as an input into the various "min" parameters on calls
   * to fight front-running
   *
   * @dev This shouldn't be used outside frontends for user estimates.
   *
   * @param amounts an array of token amounts to deposit or withdrawal,
   * corresponding to pooledTokens. The amount should be in each
   * pooled token's native precision. If a token charges a fee on transfers,
   * use the amount that gets transferred after the fee.
   * @param deposit whether this is a deposit or a withdrawal
   * @return token amount the user will receive
   */
  function calculateTokenAmount(
    uint256[2] calldata amounts,
    bool deposit
  ) external view virtual override returns (uint256) {
    return LIQUIDITY.calculateTokenAmount(amounts, deposit);
  }

  /**
   * @notice A simple method to calculate amount of each underlying
   * tokens that is returned upon burning given amount of LP tokens
   * @param amount the amount of LP tokens that would be burned on withdrawal
   * @return array of token balances that the user will receive
   */
  function calculateRemoveLiquidity(
    uint256 amount
  ) external view virtual override returns (uint256[2] memory) {
    return LIQUIDITY.calculateRemoveLiquidity(amount);
  }

  /**
   * @notice Calculate the amount of underlying token available to withdraw
   * when withdrawing via only single token
   * @param tokenAmount the amount of LP token to burn
   * @param tokenIndex index of which token will be withdrawn
   * @return availableTokenAmount calculated amount of underlying token
   * available to withdraw
   */
  function calculateRemoveLiquidityOneToken(
    uint256 tokenAmount,
    uint8 tokenIndex
  ) external view virtual override returns (uint256 availableTokenAmount) {
    return LIQUIDITY.calculateWithdrawOneToken(tokenAmount, tokenIndex);
  }

  /**
   * @custom:section                           ** STATE MODIFYING FUNCTIONS **
   *
   * @custom:visibility -> external
   */

  /**
   * @notice Swap two tokens using this pool
   * @param tokenIndexFrom the token the user wants to swap from
   * @param tokenIndexTo the token the user wants to swap to
   * @param dx the amount of tokens the user wants to swap from
   * @param minDy the min amount the user would like to receive, or revert.
   * @param deadline latest timestamp to accept this transaction
   */
  function swap(
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 dx,
    uint256 minDy,
    uint256 deadline
  )
    public
    payable
    virtual
    override
    nonReentrant
    whenNotPaused
    deadlineCheck(deadline)
    returns (uint256)
  {
    return LIQUIDITY.swap(tokenIndexFrom, tokenIndexTo, dx, minDy);
  }

  /**
   * @notice Add liquidity to the pool with the given amounts of tokens
   * @param amounts the amounts of each token to add, in their native precision
   * @param minToMint the minimum LP tokens adding this amount of liquidity
   * should mint, otherwise revert. Handy for front-running mitigation
   * @param deadline latest timestamp to accept this transaction
   * @return amount of LP token user minted and received
   */
  function addLiquidity(
    uint256[2] calldata amounts,
    uint256 minToMint,
    uint256 deadline
  )
    public
    payable
    virtual
    override
    nonReentrant
    whenNotPaused
    deadlineCheck(deadline)
    returns (uint256)
  {
    return LIQUIDITY.addLiquidity(amounts, minToMint);
  }

  /**
   * @notice Burn LP tokens to remove liquidity from the pool.
   * @dev Liquidity can always be removed, even when the pool is paused.
   * @param amount the amount of LP tokens to burn
   * @param minAmounts the minimum amounts of each token in the pool
   *        acceptable for this burn. Useful as a front-running mitigation
   * @param deadline latest timestamp to accept this transaction
   * @return amounts of tokens user received
   */
  function removeLiquidity(
    uint256 amount,
    uint256[2] calldata minAmounts,
    uint256 deadline
  ) public virtual override nonReentrant deadlineCheck(deadline) returns (uint256[2] memory) {
    return LIQUIDITY.removeLiquidity(amount, minAmounts);
  }

  /**
   * @notice Remove liquidity from the pool all in one token.
   * @param tokenAmount the amount of the token you want to receive
   * @param tokenIndex the index of the token you want to receive
   * @param minAmount the minimum amount to withdraw, otherwise revert
   * @param deadline latest timestamp to accept this transaction
   * @return amount of chosen token user received
   */
  function removeLiquidityOneToken(
    uint256 tokenAmount,
    uint8 tokenIndex,
    uint256 minAmount,
    uint256 deadline
  ) public virtual override nonReentrant whenNotPaused deadlineCheck(deadline) returns (uint256) {
    return LIQUIDITY.removeLiquidityOneToken(tokenAmount, tokenIndex, minAmount);
  }

  /**
   * @notice Remove liquidity from the pool, weighted differently than the
   * pool's current balances.
   * @param amounts how much of each token to withdraw
   * @param maxBurnAmount the max LP token provider is willing to pay to
   * remove liquidity. Useful as a front-running mitigation.
   * @param deadline latest timestamp to accept this transaction
   * @return amount of LP tokens burned
   */
  function removeLiquidityImbalance(
    uint256[2] calldata amounts,
    uint256 maxBurnAmount,
    uint256 deadline
  ) public virtual override nonReentrant whenNotPaused deadlineCheck(deadline) returns (uint256) {
    return LIQUIDITY.removeLiquidityImbalance(amounts, maxBurnAmount);
  }
}
