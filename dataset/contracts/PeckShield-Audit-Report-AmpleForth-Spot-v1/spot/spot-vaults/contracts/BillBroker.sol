// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import { SafeCastUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import { SignedMathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/SignedMathUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ERC20BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IERC20MetadataUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import { IPerpetualTranche } from "@ampleforthorg/spot-contracts/contracts/_interfaces/IPerpetualTranche.sol";
import { ISpotPricingStrategy } from "./_interfaces/ISpotPricingStrategy.sol";
import { ReserveState, BillBrokerFees, Line, Range } from "./_interfaces/BillBrokerTypes.sol";
import { UnacceptableSwap, UnreliablePrice, UnexpectedDecimals, InvalidPerc, InvalidARBound, SlippageTooHigh, UnauthorizedCall, UnexpectedARDelta } from "./_interfaces/BillBrokerErrors.sol";

/**
 *  @title BillBroker
 *
 *  @notice The `BillBroker` contract (inspired by bill brokers in LombardSt) acts as an intermediary between
 *          parties who want to borrow and lend.
 *
 *          `BillBroker` LPs deposit perps and dollars as available liquidity into the contract.
 *          Any user can now sell/buy perps (swap) from the bill broker for dollars,
 *          at a "fair" exchange rate determined by the contract.
 *
 *          The contract charges a fee for swap operations.
 *          The fee is a function of available liquidity held in the contract, and goes to the LPs.
 *
 *          The ratio of value of dollar tokens vs perp tokens held by the contract is defined as it's `assetRatio`.
 *          => `assetRatio` = reserveValue(usd) / reserveValue(perp)
 *
 *          The owner can define hard limits on the system's assetRatio outside which swapping is disabled.
 *
 *          The contract relies on external data sources to price assets.
 *          If the data is unreliable, swaps are simply halted.
 *
 *          Intermediating borrowing:
 *          Borrowers who want to borrower dollars against their collateral,
 *          tranche their collateral, mint perps and sell it for dollars to the bill broker.
 *          When they want to close out their position they can buy back perps from the bill broker
 *          using dollars, and redeem their tranches for the original collateral.
 *          The spread is the "interest rate" paid for the loan, which goes to the bill broker LPs
 *          who take on the risk of holding perps through the duration of the loan.
 *
 *          Intermediating lending:
 *          Lenders can buy perps from the bill broker contract when it's under-priced,
 *          hold the perp tokens until the market price recovers and sell it back to the bill broker contract.
 *
 *          Single Sided deposits:
 *          The pool also supports single sided deposits with either perps or usd tokens
 *          insofar as it brings the pool back into balance.
 *
 */
contract BillBroker is
    ERC20BurnableUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    //-------------------------------------------------------------------------
    // Libraries

    // ERC20 operations
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IPerpetualTranche;

    // Math
    using MathUpgradeable for uint256;
    using SafeCastUpgradeable for uint256;
    using SafeCastUpgradeable for int256;
    using SignedMathUpgradeable for int256;

    //-------------------------------------------------------------------------
    // Constants & Immutables

    uint256 public constant DECIMALS = 18;
    uint256 public constant ONE = (10 ** DECIMALS);
    uint256 private constant INITIAL_RATE = 1000000;
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 22;

    //-------------------------------------------------------------------------
    // Storage

    /// @notice The perpetual senior tranche token.
    IPerpetualTranche public perp;

    /// @notice The USD token.
    IERC20Upgradeable public usd;

    /// @notice The fixed-point amount of usd tokens equivalent to 1.0 usd.
    uint256 public usdUnitAmt;

    /// @notice The fixed-point amount of perp tokens equivalent to 1.0 perp.
    uint256 public perpUnitAmt;

    /// @notice Reference to the address that has the ability to pause/unpause operations.
    /// @dev The keeper is meant for time-sensitive operations, and may be different from the owner address.
    /// @return The address of the keeper.
    address public keeper;

    /// @notice The pricing strategy.
    ISpotPricingStrategy public pricingStrategy;

    /// @notice All of the system fees.
    BillBrokerFees public fees;

    /// @notice The asset ratio bounds outside which swapping is disabled.
    Range public arHardBound;

    /// @notice The asset ratio bounds outside which swapping is still functional but,
    ///         the swap fees transition from a flat percentage fee to a linear function.
    Range public arSoftBound;

    //--------------------------------------------------------------------------
    // Events

    /// @notice Emitted when a user deposits USD tokens to mint LP tokens.
    /// @param usdAmtIn The amount of USD tokens deposited.
    /// @param preOpState The reserve state before the deposit operation.
    event DepositUSD(uint256 usdAmtIn, ReserveState preOpState);

    /// @notice Emitted when a user deposits Perp tokens to mint LP tokens.
    /// @param perpAmtIn The amount of Perp tokens deposited.
    /// @param preOpState The reserve state before the deposit operation.
    event DepositPerp(uint256 perpAmtIn, ReserveState preOpState);

    /// @notice Emitted when a user swaps Perp tokens for USD tokens.
    /// @param perpAmtIn The amount of Perp tokens swapped in.
    /// @param preOpState The reserve state before the swap operation.
    event SwapPerpsForUSD(uint256 perpAmtIn, ReserveState preOpState);

    /// @notice Emitted when a user swaps USD tokens for Perp tokens.
    /// @param usdAmtIn The amount of USD tokens swapped in.
    /// @param preOpState The reserve state before the swap operation.
    event SwapUSDForPerps(uint256 usdAmtIn, ReserveState preOpState);

    //--------------------------------------------------------------------------
    // Modifiers

    /// @dev Throws if called by any account other than the keeper.
    modifier onlyKeeper() {
        if (msg.sender != keeper) {
            revert UnauthorizedCall();
        }
        _;
    }

    //-----------------------------------------------------------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Contract initializer.
    /// @param name ERC-20 Name of the Bill broker LP token.
    /// @param symbol ERC-20 Symbol of the Bill broker LP token.
    /// @param usd_ Address of the usd token.
    /// @param perp_ Address of the perp token.
    /// @param pricingStrategy_ Address of the pricing strategy contract.
    function init(
        string memory name,
        string memory symbol,
        IERC20Upgradeable usd_,
        IPerpetualTranche perp_,
        ISpotPricingStrategy pricingStrategy_
    ) public initializer {
        // initialize dependencies
        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        usd = usd_;
        perp = perp_;

        usdUnitAmt = 10 ** IERC20MetadataUpgradeable(address(usd_)).decimals();
        perpUnitAmt = 10 ** IERC20MetadataUpgradeable(address(perp_)).decimals();

        updateKeeper(owner());
        updatePricingStrategy(pricingStrategy_);
        updateFees(
            BillBrokerFees({
                mintFeePerc: 0,
                burnFeePerc: 0,
                perpToUSDSwapFeePercs: Range({ lower: ONE, upper: ONE }),
                usdToPerpSwapFeePercs: Range({ lower: ONE, upper: ONE }),
                protocolSwapSharePerc: 0
            })
        );

        updateARBounds(
            // Soft bound
            Range({ lower: 0, upper: type(uint256).max }),
            // Hard bound
            Range({ lower: 0, upper: type(uint256).max })
        );
    }

    //--------------------------------------------------------------------------
    // Owner only methods

    /// @notice Updates the reference to the keeper.
    /// @param keeper_ The address of the new keeper.
    function updateKeeper(address keeper_) public onlyOwner {
        keeper = keeper_;
    }

    /// @notice Updates the reference to the pricing strategy.
    /// @param pricingStrategy_ The address of the new pricing strategy.
    function updatePricingStrategy(
        ISpotPricingStrategy pricingStrategy_
    ) public onlyOwner {
        if (pricingStrategy_.decimals() != DECIMALS) {
            revert UnexpectedDecimals();
        }
        pricingStrategy = pricingStrategy_;
    }

    /// @notice Updates the system fees.
    /// @param fees_ The new system fees.
    function updateFees(BillBrokerFees memory fees_) public onlyOwner {
        if (
            fees_.mintFeePerc > ONE ||
            fees_.burnFeePerc > ONE ||
            fees_.perpToUSDSwapFeePercs.lower > fees_.perpToUSDSwapFeePercs.upper ||
            fees_.usdToPerpSwapFeePercs.lower > fees_.usdToPerpSwapFeePercs.upper ||
            fees_.protocolSwapSharePerc > ONE
        ) {
            revert InvalidPerc();
        }

        fees = fees_;
    }

    /// @notice Updates the hard asset ratio bound.
    /// @dev Swaps are made expensive when the system is outside the defined soft bounds,
    ///      and swaps are disabled when the system is outside the defined hard bounds.
    /// @param arSoftBound_ The updated soft bounds.
    /// @param arHardBound_ The updated hard bounds.
    function updateARBounds(
        Range memory arSoftBound_,
        Range memory arHardBound_
    ) public onlyOwner {
        bool validBounds = (arHardBound_.lower <= arSoftBound_.lower &&
            arSoftBound_.lower <= arSoftBound_.upper &&
            arSoftBound_.upper <= arHardBound_.upper);
        if (!validBounds) {
            revert InvalidARBound();
        }
        arSoftBound = arSoftBound_;
        arHardBound = arHardBound_;
    }

    //--------------------------------------------------------------------------
    // Keeper only methods

    /// @notice Pauses deposits, withdrawals and swaps.
    /// @dev ERC-20 functions, like transfers will always remain operational.
    function pause() external onlyKeeper {
        _pause();
    }

    /// @notice Unpauses deposits, withdrawals and rollovers.
    /// @dev ERC-20 functions, like transfers will always remain operational.
    function unpause() external onlyKeeper {
        _unpause();
    }

    //--------------------------------------------------------------------------
    // External & Public write methods

    /// @notice Deposits usd tokens and perp tokens and mint LP tokens.
    /// @param usdAmtMax The amount of usd tokens maximum available to be deposited.
    /// @param perpAmtMax The amount of perp tokens maximum available to be deposited.
    /// @param usdAmtMin The minimum amount of usd tokens that are expected to be deposited.
    /// @param perpAmtMin The minimum amount of perp tokens that are expected to be deposited.
    /// @return mintAmt The amount of LP tokens minted.
    function deposit(
        uint256 usdAmtMax,
        uint256 perpAmtMax,
        uint256 usdAmtMin,
        uint256 perpAmtMin
    ) external nonReentrant whenNotPaused returns (uint256 mintAmt) {
        uint256 usdAmtIn;
        uint256 perpAmtIn;
        bool isFirstMint;
        (mintAmt, usdAmtIn, perpAmtIn, isFirstMint) = computeMintAmt(
            usdAmtMax,
            perpAmtMax
        );
        if (mintAmt <= 0) {
            return 0;
        }
        if (usdAmtIn < usdAmtMin || perpAmtIn < perpAmtMin) {
            revert SlippageTooHigh();
        }

        // Transfer perp and usd tokens from the user
        usd.safeTransferFrom(msg.sender, address(this), usdAmtIn);
        perp.safeTransferFrom(msg.sender, address(this), perpAmtIn);

        // Permanently lock the MINIMUM_LIQUIDITY tokens on first mint
        if (isFirstMint) {
            _mint(address(this), MINIMUM_LIQUIDITY);
            mintAmt -= MINIMUM_LIQUIDITY;
        }

        // mint LP tokens to the user
        _mint(msg.sender, mintAmt);
    }

    /// @notice Single sided usd token deposit and mint LP tokens.
    /// @param usdAmtIn The amount of usd tokens to be deposited.
    /// @param postOpAssetRatioMax The system asset ratio can be no higher than this value after deposit.
    /// @return mintAmt The amount of LP tokens minted.
    function depositUSD(
        uint256 usdAmtIn,
        uint256 postOpAssetRatioMax
    ) external nonReentrant whenNotPaused returns (uint256 mintAmt) {
        ReserveState memory preOpState = reserveState();
        uint256 preOpAssetRatio = assetRatio(preOpState);
        uint256 postOpAssetRatio = assetRatio(
            ReserveState({
                usdBalance: preOpState.usdBalance + usdAmtIn,
                perpBalance: preOpState.perpBalance,
                usdPrice: preOpState.usdPrice,
                perpPrice: preOpState.perpPrice
            })
        );

        // We allow minting only pool is underweight usd
        if (preOpAssetRatio >= ONE || postOpAssetRatio > ONE) {
            return 0;
        }

        mintAmt = computeMintAmtWithUSD(usdAmtIn, preOpState);
        if (mintAmt <= 0) {
            return 0;
        }
        if (postOpAssetRatio > postOpAssetRatioMax) {
            revert SlippageTooHigh();
        }

        // Transfer usd tokens from the user
        usd.safeTransferFrom(msg.sender, address(this), usdAmtIn);

        // mint LP tokens to the user
        _mint(msg.sender, mintAmt);

        // Emit deposit info
        emit DepositUSD(usdAmtIn, preOpState);
    }

    /// @notice Single sided perp token deposit and mint LP tokens.
    /// @param perpAmtIn The amount of perp tokens to be deposited.
    /// @param postOpAssetRatioMin The system asset ratio can be no lower than this value after deposit.
    /// @return mintAmt The amount of LP tokens minted.
    function depositPerp(
        uint256 perpAmtIn,
        uint256 postOpAssetRatioMin
    ) external nonReentrant whenNotPaused returns (uint256 mintAmt) {
        ReserveState memory preOpState = reserveState();
        uint256 preOpAssetRatio = assetRatio(preOpState);
        uint256 postOpAssetRatio = assetRatio(
            ReserveState({
                usdBalance: preOpState.usdBalance,
                perpBalance: preOpState.perpBalance + perpAmtIn,
                usdPrice: preOpState.usdPrice,
                perpPrice: preOpState.perpPrice
            })
        );

        // We allow minting only pool is underweight perp
        if (preOpAssetRatio <= ONE || postOpAssetRatio < ONE) {
            return 0;
        }

        mintAmt = computeMintAmtWithPerp(perpAmtIn, preOpState);
        if (mintAmt <= 0) {
            return 0;
        }
        if (postOpAssetRatio < postOpAssetRatioMin) {
            revert SlippageTooHigh();
        }

        // Transfer perp tokens from the user
        perp.safeTransferFrom(msg.sender, address(this), perpAmtIn);

        // mint LP tokens to the user
        _mint(msg.sender, mintAmt);

        // Emit deposit info
        emit DepositPerp(perpAmtIn, preOpState);
    }

    /// @notice Burns LP tokens and redeems usd and perp tokens.
    /// @param burnAmt The LP tokens to be burnt.
    /// @return usdAmtOut The amount usd tokens returned.
    /// @return perpAmtOut The amount perp tokens returned.
    function redeem(
        uint256 burnAmt
    )
        external
        nonReentrant
        whenNotPaused
        returns (uint256 usdAmtOut, uint256 perpAmtOut)
    {
        (usdAmtOut, perpAmtOut) = computeRedemptionAmts(burnAmt);
        if (usdAmtOut == 0 && perpAmtOut == 0) {
            return (0, 0);
        }

        // burn LP tokens
        _burn(msg.sender, burnAmt);

        // return funds
        usd.safeTransfer(msg.sender, usdAmtOut);
        perp.safeTransfer(msg.sender, perpAmtOut);
    }

    /// @notice Swaps usd tokens from the user for perp tokens from the reserve.
    /// @param usdAmtIn The amount of usd tokens swapped in.
    /// @param perpAmtMin The minimum amount of perp tokens that are expected out.
    /// @return perpAmtOut The amount perp tokens swapped out.
    function swapUSDForPerps(
        uint256 usdAmtIn,
        uint256 perpAmtMin
    ) external nonReentrant whenNotPaused returns (uint256 perpAmtOut) {
        // compute perp amount out
        ReserveState memory preOpState = reserveState();
        uint256 protocolFeePerpAmt;
        (perpAmtOut, , protocolFeePerpAmt) = computeUSDToPerpSwapAmt(
            usdAmtIn,
            preOpState
        );
        if (usdAmtIn <= 0 || perpAmtOut <= 0) {
            revert UnacceptableSwap();
        }
        if (perpAmtOut < perpAmtMin) {
            revert SlippageTooHigh();
        }

        // Transfer usd tokens from user
        usd.safeTransferFrom(msg.sender, address(this), usdAmtIn);

        // settle fees
        if (protocolFeePerpAmt > 0) {
            perp.safeTransfer(protocolFeeCollector(), protocolFeePerpAmt);
        }

        // transfer perps out to the user
        perp.safeTransfer(msg.sender, perpAmtOut);

        // Emit swap info
        emit SwapUSDForPerps(usdAmtIn, preOpState);
    }

    /// @notice Swaps perp tokens from the user for usd tokens from the reserve.
    /// @param perpAmtIn The amount of perp tokens swapped in.
    /// @param usdAmtMin The minimum amount of usd tokens that are expected out.
    /// @return usdAmtOut The amount usd tokens swapped out.
    function swapPerpsForUSD(
        uint256 perpAmtIn,
        uint256 usdAmtMin
    ) external nonReentrant whenNotPaused returns (uint256 usdAmtOut) {
        // Compute swap amount
        ReserveState memory preOpState = reserveState();
        uint256 protocolFeeUsdAmt;
        (usdAmtOut, , protocolFeeUsdAmt) = computePerpToUSDSwapAmt(perpAmtIn, preOpState);
        if (perpAmtIn <= 0 || usdAmtOut <= 0) {
            revert UnacceptableSwap();
        }
        if (usdAmtOut < usdAmtMin) {
            revert SlippageTooHigh();
        }

        // Transfer perp tokens from user
        perp.safeTransferFrom(msg.sender, address(this), perpAmtIn);

        // settle fees
        if (protocolFeeUsdAmt > 0) {
            usd.safeTransfer(protocolFeeCollector(), protocolFeeUsdAmt);
        }

        // transfer usd out to the user
        usd.safeTransfer(msg.sender, usdAmtOut);

        // Emit swap info
        emit SwapPerpsForUSD(perpAmtIn, preOpState);
    }

    //-----------------------------------------------------------------------------
    // Public methods

    /// @notice Computes the amount of LP tokens minted,
    ///         when the given number of usd tokens are deposited.
    /// @param usdAmtIn The amount of usd tokens deposited.
    /// @return mintAmt The amount of LP tokens minted.
    function computeMintAmtWithUSD(uint256 usdAmtIn) public returns (uint256 mintAmt) {
        return computeMintAmtWithUSD(usdAmtIn, reserveState());
    }

    /// @notice Computes the amount of LP tokens minted,
    ///         when the given number of perp tokens are deposited.
    /// @param perpAmtIn The amount of perp tokens deposited.
    /// @return mintAmt The amount of LP tokens minted.
    function computeMintAmtWithPerp(uint256 perpAmtIn) public returns (uint256 mintAmt) {
        return computeMintAmtWithPerp(perpAmtIn, reserveState());
    }

    /// @notice Computes the amount of usd tokens swapped out,
    ///         when the given number of perp tokens are sent in.
    /// @param perpAmtIn The amount of perp tokens swapped in.
    /// @return usdAmtOut The amount usd tokens swapped out.
    function computePerpToUSDSwapAmt(
        uint256 perpAmtIn
    ) public returns (uint256 usdAmtOut) {
        (usdAmtOut, , ) = computePerpToUSDSwapAmt(perpAmtIn, reserveState());
    }

    /// @notice Computes the amount of perp tokens swapped out,
    ///         when the given number of usd tokens are sent in.
    /// @param usdAmtIn The number of usd tokens sent in.
    /// @return perpAmtOut The amount of perp tokens swapped out.
    function computeUSDToPerpSwapAmt(
        uint256 usdAmtIn
    ) public returns (uint256 perpAmtOut) {
        (perpAmtOut, , ) = computeUSDToPerpSwapAmt(usdAmtIn, reserveState());
    }

    /// @return s The reserve usd and perp token balances and prices.
    function reserveState() public returns (ReserveState memory s) {
        return
            ReserveState({
                usdBalance: usd.balanceOf(address(this)),
                perpBalance: perp.balanceOf(address(this)),
                usdPrice: usdPrice(),
                perpPrice: perpPrice()
            });
    }

    /// @dev Reverts if the pricing strategy returns an invalid price.
    /// @return The price of usd tokens from the pricing strategy.
    function usdPrice() public returns (uint256) {
        (uint256 p, bool v) = pricingStrategy.usdPrice();
        if (!v) {
            revert UnreliablePrice();
        }
        return p;
    }

    /// @dev Reverts if the pricing strategy returns an invalid price.
    /// @return The price of perp tokens from the pricing strategy.
    function perpPrice() public returns (uint256) {
        (uint256 p, bool v) = pricingStrategy.perpPrice();
        if (!v) {
            revert UnreliablePrice();
        }
        return p;
    }

    //-----------------------------------------------------------------------------
    // External view methods

    /// @return The balance of usd tokens in the reserve.
    function usdBalance() external view returns (uint256) {
        return usd.balanceOf(address(this));
    }

    /// @return The balance of perp tokens in the reserve.
    function perpBalance() external view returns (uint256) {
        return perp.balanceOf(address(this));
    }

    //-----------------------------------------------------------------------------
    // Public view methods

    /// @notice Computes the amount of LP tokens minted,
    ///         when the given number of usd and perp tokens are deposited.
    /// @param usdAmtMax The maximum available usd tokens.
    /// @param perpAmtMax The maximum available perp tokens.
    /// @return mintAmt The amount of LP tokens minted.
    /// @return usdAmtIn The usd tokens to be deposited.
    /// @return perpAmtIn The perp tokens to be deposited.
    /// @return isFirstMint If the pool currently has no deposits.
    function computeMintAmt(
        uint256 usdAmtMax,
        uint256 perpAmtMax
    )
        public
        view
        returns (uint256 mintAmt, uint256 usdAmtIn, uint256 perpAmtIn, bool isFirstMint)
    {
        uint256 totalSupply_ = totalSupply();
        isFirstMint = (totalSupply_ <= 0);

        if (usdAmtMax <= 0 && perpAmtMax <= 0) {
            return (0, 0, 0, isFirstMint);
        }

        // During the initial deposit we deposit the entire available amounts.
        // The onus is on the depositor to ensure that the value of USD tokens and
        // perp tokens on first deposit are equivalent.
        if (isFirstMint) {
            usdAmtIn = usdAmtMax;
            perpAmtIn = perpAmtMax;
            mintAmt = (ONE.mulDiv(usdAmtIn, usdUnitAmt) +
                ONE.mulDiv(perpAmtIn, perpUnitAmt));
            mintAmt = mintAmt * INITIAL_RATE;
        } else {
            // Users can deposit assets proportional to the reserve.
            uint256 usdBalance_ = usd.balanceOf(address(this));
            uint256 perpBalance_ = perp.balanceOf(address(this));
            if (usdBalance_ == 0) {
                usdAmtIn = 0;
                perpAmtIn = perpAmtMax;
                mintAmt = totalSupply_.mulDiv(perpAmtIn, perpBalance_);
            } else if (perpBalance_ == 0) {
                perpAmtIn = 0;
                usdAmtIn = usdAmtMax;
                mintAmt = totalSupply_.mulDiv(usdAmtIn, usdBalance_);
            } else {
                usdAmtIn = usdAmtMax;
                perpAmtIn = perpBalance_.mulDiv(usdAmtIn, usdBalance_);
                if (perpAmtIn > perpAmtMax) {
                    perpAmtIn = perpAmtMax;
                    usdAmtIn = usdBalance_.mulDiv(perpAmtIn, perpBalance_);
                }
                mintAmt = totalSupply_.mulDiv(usdAmtIn, usdBalance_);
            }
        }

        mintAmt = mintAmt.mulDiv(ONE - fees.mintFeePerc, ONE);
    }

    /// @notice Computes the amount of LP tokens minted,
    ///         when the given number of usd tokens are deposited.
    /// @param usdAmtIn The amount of usd tokens deposited.
    /// @param s The current reserve state.
    /// @return mintAmt The amount of LP tokens minted.
    function computeMintAmtWithUSD(
        uint256 usdAmtIn,
        ReserveState memory s
    ) public view returns (uint256) {
        if (usdAmtIn <= 0) {
            return 0;
        }

        uint256 valueIn = s.usdPrice.mulDiv(usdAmtIn, usdUnitAmt);
        uint256 totalReserveVal = (s.usdPrice.mulDiv(s.usdBalance, usdUnitAmt) +
            s.perpPrice.mulDiv(s.perpBalance, perpUnitAmt));

        return
            (totalReserveVal > 0)
                ? valueIn.mulDiv(totalSupply(), totalReserveVal).mulDiv(
                    ONE - fees.mintFeePerc,
                    ONE
                )
                : 0;
    }

    /// @notice Computes the amount of LP tokens minted,
    ///         when the given number of perp tokens are deposited.
    /// @param perpAmtIn The amount of perp tokens deposited.
    /// @param s The current reserve state.
    /// @return mintAmt The amount of LP tokens minted.
    function computeMintAmtWithPerp(
        uint256 perpAmtIn,
        ReserveState memory s
    ) public view returns (uint256) {
        if (perpAmtIn <= 0) {
            return 0;
        }

        uint256 valueIn = s.perpPrice.mulDiv(perpAmtIn, perpUnitAmt);
        uint256 totalReserveVal = (s.usdPrice.mulDiv(s.usdBalance, usdUnitAmt) +
            s.perpPrice.mulDiv(s.perpBalance, perpUnitAmt));

        return
            (totalReserveVal > 0)
                ? valueIn.mulDiv(totalSupply(), totalReserveVal).mulDiv(
                    ONE - fees.mintFeePerc,
                    ONE
                )
                : 0;
    }

    /// @notice Computes the amount of usd and perp tokens redeemed,
    ///         when the given number of LP tokens are burnt.
    /// @param burnAmt The amount of LP tokens to be burnt.
    /// @return usdAmtOut The amount of usd tokens redeemed.
    /// @return perpAmtOut The amount of perp tokens redeemed.
    function computeRedemptionAmts(
        uint256 burnAmt
    ) public view returns (uint256 usdAmtOut, uint256 perpAmtOut) {
        if (burnAmt <= 0) {
            return (0, 0);
        }

        uint256 totalSupply_ = totalSupply();
        usdAmtOut = usd.balanceOf(address(this)).mulDiv(burnAmt, totalSupply_).mulDiv(
            ONE - fees.burnFeePerc,
            ONE
        );
        perpAmtOut = perp.balanceOf(address(this)).mulDiv(burnAmt, totalSupply_).mulDiv(
            ONE - fees.burnFeePerc,
            ONE
        );
    }

    /// @notice Computes the amount of usd tokens swapped out,
    ///         when the given number of perp tokens are sent in.
    /// @param perpAmtIn The number of perp tokens sent in.
    /// @param s The current reserve state.
    /// @dev Quoted usd token amount out includes the fees withheld.
    /// @return usdAmtOut The amount of usd tokens swapped out.
    /// @return lpFeeUsdAmt The amount of usd tokens charged as swap fees by LPs.
    /// @return protocolFeeUsdAmt The amount of usd tokens charged as protocol fees.
    function computePerpToUSDSwapAmt(
        uint256 perpAmtIn,
        ReserveState memory s
    )
        public
        view
        returns (uint256 usdAmtOut, uint256 lpFeeUsdAmt, uint256 protocolFeeUsdAmt)
    {
        // We compute equal value of usd tokens out given perp tokens in.
        usdAmtOut = perpAmtIn.mulDiv(s.perpPrice, s.usdPrice).mulDiv(
            usdUnitAmt,
            perpUnitAmt
        );

        // We compute the total fee percentage, lp fees and protocol fees
        uint256 totalFeePerc = computePerpToUSDSwapFeePerc(
            assetRatio(s),
            assetRatio(
                ReserveState({
                    usdBalance: s.usdBalance - usdAmtOut,
                    perpBalance: s.perpBalance + perpAmtIn,
                    usdPrice: s.usdPrice,
                    perpPrice: s.perpPrice
                })
            )
        );
        if (totalFeePerc >= ONE) {
            return (0, 0, 0);
        }
        uint256 totalFeeUsdAmt = usdAmtOut.mulDiv(totalFeePerc, ONE);
        usdAmtOut -= totalFeeUsdAmt;
        protocolFeeUsdAmt = totalFeeUsdAmt.mulDiv(fees.protocolSwapSharePerc, ONE);
        lpFeeUsdAmt = totalFeeUsdAmt - protocolFeeUsdAmt;
    }

    /// @notice Computes the amount of perp tokens swapped out,
    ///         when the given number of usd tokens are sent in.
    /// @param usdAmtIn The number of usd tokens sent in.
    /// @param s The current reserve state.
    /// @dev Quoted perp token amount out includes the fees withheld.
    /// @return perpAmtOut The amount of perp tokens swapped out.
    /// @return lpFeePerpAmt The amount of perp tokens charged as swap fees by LPs.
    /// @return protocolFeePerpAmt The amount of perp tokens charged as protocol fees.
    function computeUSDToPerpSwapAmt(
        uint256 usdAmtIn,
        ReserveState memory s
    )
        public
        view
        returns (uint256 perpAmtOut, uint256 lpFeePerpAmt, uint256 protocolFeePerpAmt)
    {
        // We compute equal value of perp tokens out given usd tokens in.
        perpAmtOut = usdAmtIn.mulDiv(s.usdPrice, s.perpPrice).mulDiv(
            perpUnitAmt,
            usdUnitAmt
        );
        // We compute the total fee percentage, lp fees and protocol fees
        uint256 totalFeePerc = computeUSDToPerpSwapFeePerc(
            assetRatio(s),
            assetRatio(
                ReserveState({
                    usdBalance: s.usdBalance + usdAmtIn,
                    perpBalance: s.perpBalance - perpAmtOut,
                    usdPrice: s.usdPrice,
                    perpPrice: s.perpPrice
                })
            )
        );
        if (totalFeePerc >= ONE) {
            return (0, 0, 0);
        }
        uint256 totalFeePerpAmt = perpAmtOut.mulDiv(totalFeePerc, ONE);
        perpAmtOut -= totalFeePerpAmt;
        protocolFeePerpAmt = totalFeePerpAmt.mulDiv(fees.protocolSwapSharePerc, ONE);
        lpFeePerpAmt = totalFeePerpAmt - protocolFeePerpAmt;
    }

    /// @notice Computes the swap fee percentage when swapping from perp to usd tokens.
    /// @dev Swapping from perp to usd tokens, leaves the system with more perp and fewer usd tokens
    ///      thereby decreasing the system's `assetRatio`. Thus arPost < arPre.
    /// @param arPre The asset ratio of the system before swapping.
    /// @param arPost The asset ratio of the system after swapping.
    /// @return The fee percentage.
    function computePerpToUSDSwapFeePerc(
        uint256 arPre,
        uint256 arPost
    ) public view returns (uint256) {
        if (arPost > arPre) {
            revert UnexpectedARDelta();
        }

        // When the ar decreases below the lower bound,
        // swaps are effectively halted by setting fees to 100%.
        if (arPost < arHardBound.lower) {
            return ONE;
        }
        // When the ar is between the soft and hard bound, a linear function is applied.
        // When the ar is above the soft bound, a flat percentage fee is applied.
        //
        //   fee
        //    ^
        //    |
        // fh |    \          |
        //    |     \         |
        //    |      \        |
        //    |       \       |
        //    |        \      |
        //    |         \     |
        // fl |          \__________
        //    |               |
        //    |               |
        //    |               |
        //    +---------------------------> ar
        //       arHL  arSL  1.0
        //
        Range memory swapFeePercs = fees.perpToUSDSwapFeePercs;
        return
            _computeFeePerc(
                Line({
                    x1: arHardBound.lower,
                    y1: swapFeePercs.upper,
                    x2: arSoftBound.lower,
                    y2: swapFeePercs.lower
                }),
                Line({ x1: 0, y1: swapFeePercs.lower, x2: ONE, y2: swapFeePercs.lower }),
                arPost,
                arPre,
                arSoftBound.lower
            );
    }

    /// @notice Computes the swap fee percentage when swapping from usd to perp tokens.
    /// @dev Swapping from usd to perp tokens, leaves the system with more usd and fewer perp tokens
    ///      thereby increasing the system's `assetRatio`. Thus arPost > arPre.
    /// @param arPre The asset ratio of the system before swapping.
    /// @param arPost The asset ratio of the system after swapping.
    /// @return The fee percentage.
    function computeUSDToPerpSwapFeePerc(
        uint256 arPre,
        uint256 arPost
    ) public view returns (uint256) {
        if (arPost < arPre) {
            revert UnexpectedARDelta();
        }

        // When the ar increases above the hard bound,
        // swaps are effectively halted by setting fees to 100%.
        if (arPost > arHardBound.upper) {
            return ONE;
        }

        // When the ar is between the soft and hard bound, a linear function is applied.
        // When the ar is below the soft bound, a flat percentage fee is applied.
        //
        //   fee
        //    ^
        //    |
        // fh |         |           /
        //    |         |          /
        //    |         |         /
        //    |         |        /
        //    |         |       /
        //    |         |      /
        // fl |     __________/
        //    |         |
        //    |         |
        //    |         |
        //    +---------------------------> ar
        //              1.0  arSU   arHU
        //
        Range memory swapFeePercs = fees.usdToPerpSwapFeePercs;
        return
            _computeFeePerc(
                Line({ x1: 0, y1: swapFeePercs.lower, x2: ONE, y2: swapFeePercs.lower }),
                Line({
                    x1: arSoftBound.upper,
                    y1: swapFeePercs.lower,
                    x2: arHardBound.upper,
                    y2: swapFeePercs.upper
                }),
                arPre,
                arPost,
                arSoftBound.upper
            );
    }

    /// @param s The system reserve state.
    /// @return The computed asset ratio of the system.
    function assetRatio(ReserveState memory s) public view returns (uint256) {
        return
            s.perpBalance > 0
                ? (
                    s.usdBalance.mulDiv(s.usdPrice, usdUnitAmt).mulDiv(
                        ONE,
                        s.perpBalance.mulDiv(s.perpPrice, perpUnitAmt)
                    )
                )
                : type(uint256).max;
    }

    /// @notice The address which holds any revenue extracted by protocol.
    /// @return Address of the fee collector.
    function protocolFeeCollector() public view returns (address) {
        return owner();
    }

    //-----------------------------------------------------------------------------
    // Private methods

    /// @dev The function assumes the fee curve is defined as a pair-wise linear function which merge at the cutoff point.
    ///      The swap fee is computed as avg height of the fee curve between {arL,arU}.
    function _computeFeePerc(
        Line memory fn1,
        Line memory fn2,
        uint256 arL,
        uint256 arU,
        uint256 cutoff
    ) private pure returns (uint256 feePerc) {
        if (arU <= cutoff) {
            feePerc = _avgY(fn1, arL, arU);
        } else if (arL >= cutoff) {
            feePerc = _avgY(fn2, arL, arU);
        } else {
            feePerc = (_avgY(fn1, arL, cutoff).mulDiv(cutoff - arL, arU - arL) +
                _avgY(fn2, cutoff, arU).mulDiv(arU - cutoff, arU - arL));
        }
        feePerc = MathUpgradeable.min(feePerc, ONE);
    }

    /// @dev We compute the average height of the line between {xL,xU}.
    function _avgY(
        Line memory fn,
        uint256 xL,
        uint256 xU
    ) private pure returns (uint256) {
        // if the line has a zero slope, return any y
        if (fn.y1 == fn.y2) {
            return fn.y2;
        }

        // m = dlY/dlX
        // c = y2 - m . x2
        // Avg height => (yL + yU) / 2
        //            => m . ( xL + xU ) / 2 + c
        int256 dlY = fn.y2.toInt256() - fn.y1.toInt256();
        int256 dlX = fn.x2.toInt256() - fn.x1.toInt256();
        int256 c = fn.y2.toInt256() - ((fn.x2.toInt256() * dlY) / dlX);
        return ((((xL + xU).toInt256() * dlY) / (2 * dlX)) + c).abs();
    }
}
