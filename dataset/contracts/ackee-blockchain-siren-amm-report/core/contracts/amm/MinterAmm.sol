// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "../libraries/Math.sol";
import "../proxy/Proxiable.sol";
import "../proxy/Proxy.sol";
import "./IAmmDataProvider.sol";
import "../series/IPriceOracle.sol";
import "../swap/ILight.sol";
import "../token/IERC20Lib.sol";
import "../oz/EnumerableSet.sol";
import "../series/SeriesLibrary.sol";
import "./MinterAmmStorage.sol";
import "../series/IVolatilityOracle.sol";
import "./IBlackScholes.sol";
import "./IWTokenVault.sol";

/// This is an implementation of a minting/redeeming AMM (Automated Market Maker) that trades a list of series with the same
/// collateral token. For example, a single WBTC Call AMM contract can trade all strikes of WBTC calls using
/// WBTC as the collateral, and a single WBTC Put AMM contract can trade all strikes of WBTC puts, using
/// USDC as the collateral.
///
/// Each AMM uses a triplet of ERC20 tokens to define the option asset whose price determines the option's value
/// (the underlyingToken), the token used to denominate the strike price (the priceToken) and the token used
/// as collateral writing the option (the collateralToken). The collateralToken also determines the units used
/// in pricing the option's premiums.
///
/// It uses an on-chain Black-Scholes approximation to calculate the price of a single option (which we represent by an
/// ERC1155 token we call "bToken"). The Black-Scholes approximation uses an on-chain oracle price feed to get the
/// current series price of the underlying asset. By using an on-chain oracle the AMM's bonding curve is aware of the
/// time-dependent nature of options pricing (a.k.a. theta-decay), and can price options better than a naive constant
/// product bonding curve such as Uniswap.
///
/// In addition, it uses a novel "mint aware bonding curve" to allow for infinite depth when buying options. A user
/// pays for options in units of the AMM's collateral token, and the AMM uses this collateral to mint additional bTokens
/// to satisfy the user's trade size
///
/// External users can buy bTokens with collateral (wToken trading is disabled in this version).
/// When they do this, the AMM will mint new bTokens and wTokens, sell the wToken to the AMM for more bToken,
/// and transfer the bToken to the user.
///
/// External users can sell bTokens for collateral. When they do this, the AMM will sell a partial amount of assets
/// to get a 50/50 split between bTokens and wTokens, then redeem them for collateral and transfer the collateral back to
/// the user.
///
/// If fees are enabled (3 params are configured: trade fee, max fee, and fee destination) a trade fee will be collected and
/// sent to an external acct.  Fee calculations mimic the Deribit fee schedule (see https://www.deribit.com/pages/information/fees for
/// their explanation with examples of BTC/ETH options). Each buy/sell has a trade fee percentage
/// based on the number of underlying option contracts (bToken amt) priced in the collateral token.
/// Additionally, there is a max fee percentage based on the option value being bought or sold (collateral paid or received).
/// The lower of the 2 fees calculated will be used.  Fees are paid out on each buy or sell of bTokens to a configured address.
///
/// Fee Example: If trade fee is 3 basis points and max fee is 1250 basis points and a buy of bTokens is priced at 0.0001 collateral
/// tokens, the fee will be 0.0000125 collateral tokens (using the max fee). If the option prices are much higher then 0.0003
/// of collateral would be the fee for each bToken.
///
/// LPs can provide collateral for liquidity. All collateral will be used to mint bTokens/wTokens for each trade.
/// They will be given a corresponding amount of lpTokens to track ownership. The amount of lpTokens is calculated based on
/// total pool value which includes collateral token, active b/wTokens and expired/unclaimed b/wTokens
///
/// LPs can withdraw collateral from liquidity. When withdrawing user can specify if they want their pro-rata b/wTokens
/// to be automatically sold to the pool for collateral. If the chose not to sell then they get pro-rata of all tokens
/// in the pool (collateral, bToken, wToken). If they chose to sell then their bTokens and wTokens will be sold
/// to the pool for collateral incurring slippage.
///
/// All expired unclaimed wTokens are automatically claimed on each deposit or withdrawal
///
/// All conversions between bToken and wToken in the AMM will generate fees that will be send to the protocol fees pool
/// (disabled in this version)
contract MinterAmm is
    Proxiable,
    ERC1155HolderUpgradeable,
    OwnableUpgradeable,
    MinterAmmStorageV3
{
    /// @dev NOTE: No local variables should be added here.  Instead see MinterAmmStorageV*.sol

    /// Use safe ERC20 functions for any token transfers since people don't follow the ERC20 standard */
    using SafeERC20 for IERC20;
    using SafeERC20 for ISimpleToken;

    using EnumerableSet for EnumerableSet.UintSet;

    /// Emitted when the amm is created
    event AMMInitialized(ISimpleToken lpToken, address controller);

    /// Emitted when an LP deposits collateral
    event LpTokensMinted(
        address minter,
        uint256 collateralAdded,
        uint256 lpTokensMinted
    );

    /// Emitted when an LP withdraws collateral
    event LpTokensBurned(
        address redeemer,
        uint256 collateralRemoved,
        uint256 lpTokensBurned
    );

    /// Emitted when a user buys bTokens from the AMM
    event BTokensBought(
        address buyer,
        uint64 seriesId,
        uint256 bTokensBought,
        uint256 collateralPaid
    );

    /// Emitted when a user sells bTokens to the AMM
    event BTokensSold(
        address seller,
        uint64 seriesId,
        uint256 bTokensSold,
        uint256 collateralPaid
    );

    /// Emitted when a user sells wTokens to the AMM
    event WTokensSold(
        address seller,
        uint64 seriesId,
        uint256 wTokensSold,
        uint256 collateralPaid
    );

    /// @notice Emitted when an expired series has been removed
    event SeriesEvicted(uint64 seriesId);

    /// Emitted when the owner updates fee params
    event TradeFeesUpdated(
        uint16 newTradeFeeBasisPoints,
        uint16 newMaxOptionFeeBasisPoints,
        address newFeeDestinationAddress
    );

    event ConfigUpdated(
        int256 ivShift,
        bool dynamicIvEnabled,
        uint16 ivDriftRate
    );

    // Emitted when fees are paid
    event TradeFeesPaid(address indexed feePaidTo, uint256 feeAmount);

    //Emitted when AddressesProvider is updated
    event AddressesProviderUpdated(address addressesProvider);

    // Error codes. We only use error code because we need to reduce the size of this contract's deployed
    // bytecode in order for it to be deployable

    // E02: Invalid _sirenPriceOracle
    // E03: Invalid _underlyingToken
    // E04: Invalid _priceToken
    // E05: Invalid _collateralToken
    // E06: _underlyingToken cannot equal _priceToken
    // E07: Invalid _tokenImplementation
    // E08: Contract can only be initialized once
    // E09: VolatilityFactor is too low
    // E10: Invalid _newImplementation
    // E11: Can only be called by SeriesController
    // E12: withdrawCapital: collateralMinimum must be set
    // E13: Series does not exist on this AMM
    // E14: Invalid _newAmmDataProvider
    // E15: Invalid _ammDataProvider
    // E16: Invalid lightAirswapAddress
    // E17: Option price is 0
    // E18: Invalid expirationId
    // E19: Negative IV
    // E20: Slippage exceeded
    // E21: Last LP can't sell wTokens to the pool
    // E22: Series has expired
    // E23: Trade amount is too low
    // E24: Too many open series

    /// @dev Prevents a contract from calling itself, directly or indirectly.
    /// Calling a `nonReentrant` function from another `nonReentrant`
    /// function is not supported. It is possible to prevent this from happening
    /// by making the `nonReentrant` function external, and make it call a
    /// `private` function that does the actual work.
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /// Initialize the contract, and create an lpToken to track ownership
    function initialize(
        ISeriesController _seriesController,
        IAddressesProvider _addressesProvider,
        IERC20 _underlyingToken,
        IERC20 _priceToken,
        IERC20 _collateralToken,
        ISimpleToken _lpToken,
        uint16 _tradeFeeBasisPoints
    ) public override {
        // AMMs are created only by the AmmFactory contract which already checks these
        // So we can remove them to reduce contract size
        // require(address(_underlyingToken) != address(0x0), "E03");
        // require(address(_priceToken) != address(0x0), "E04");
        // require(address(_collateralToken) != address(0x0), "E05");
        // require(address(_underlyingToken) != address(_priceToken), "E06");
        // require(_tokenImplementation != address(0x0), "E07");

        // Enforce initialization can only happen once
        require(!initialized, "E08");
        initialized = true;

        // Save off state variables
        seriesController = _seriesController;
        addressesProvider = _addressesProvider;
        erc1155Controller = IERC1155(_seriesController.erc1155Controller());

        // Approve seriesController to move tokens
        erc1155Controller.setApprovalForAll(address(seriesController), true);

        tradeFeeBasisPoints = _tradeFeeBasisPoints;

        // Save off series tokens
        underlyingToken = _underlyingToken;
        priceToken = _priceToken;
        collateralToken = _collateralToken;
        lpToken = _lpToken;

        __Ownable_init();

        emit AMMInitialized(lpToken, address(_seriesController));
    }

    function updateAddressesProvider(address _addressesProvider)
        external
        override
        onlyOwner
    {
        //How do we want to handle when we update the addressProvider that it has the proper contracts set
        addressesProvider = IAddressesProvider(_addressesProvider);
        emit AddressesProviderUpdated(_addressesProvider);
    }

    /// Get volatility of a series
    function getVolatility(uint64 _seriesId)
        public
        view
        override
        returns (uint256)
    {
        SeriesVolatility memory seriesVolatility = seriesVolatilities[
            _seriesId
        ];

        uint256 targetVolatility = getBaselineVolatility();
        int256 iv;

        if (
            seriesVolatility.updatedAt == 0 ||
            seriesVolatility.volatility == targetVolatility
        ) {
            // Volatility hasn't been initialized for this series
            iv = int256(targetVolatility);
        } else {
            if (ivDriftRate == 0) return seriesVolatility.volatility;

            int256 ivDrift = ((int256(targetVolatility) -
                int256(seriesVolatility.volatility)) *
                int256(block.timestamp - seriesVolatility.updatedAt)) /
                int256(ivDriftRate);
            iv = int256(seriesVolatility.volatility) + ivDrift;

            if (
                (ivDrift > 0 && iv > int256(targetVolatility)) ||
                (ivDrift < 0 && iv < int256(targetVolatility))
            ) {
                iv = int256(targetVolatility);
            }
        }

        return uint256(iv);
    }

    /// Each time a trade happens we update the volatility
    function updateVolatility(
        uint64 _seriesId,
        int256 priceImpact,
        uint256 currentIV,
        uint256 vega
    ) internal returns (uint256) {
        int256 newIV = int256(currentIV) + (priceImpact * 1e18) / int256(vega);

        // TODO: ability to set IV range
        int256 MAX_IV = 4e18; // 400%
        int256 MIN_IV = 5e17; // 50%
        if (newIV > MAX_IV) {
            newIV = MAX_IV;
        } else if (newIV < MIN_IV) {
            newIV = MIN_IV;
        }
        SeriesVolatility storage seriesVolatility = seriesVolatilities[
            _seriesId
        ];
        seriesVolatility.volatility = uint256(newIV);
        seriesVolatility.updatedAt = block.timestamp;
    }

    function getBaselineVolatility() public view override returns (uint256) {
        int256 iv = int256(
            IVolatilityOracle(addressesProvider.getVolatilityOracle())
                .annualizedVol(address(underlyingToken), address(priceToken))
        ) *
            1e10 + // oracle stores volatility in 8 decimals precision, here we operate at 18 decimals
            ivShift;

        require(iv > 3e17, "E19"); // 30% minimum

        return uint256(iv);
    }

    /// The owner can set the trade fee params - if any are set to 0/0x0 then trade fees are disabled
    function setTradingFeeParams(
        uint16 _tradeFeeBasisPoints,
        uint16 _maxOptionFeeBasisPoints,
        address _feeDestinationAddress
    ) public onlyOwner {
        tradeFeeBasisPoints = _tradeFeeBasisPoints;
        maxOptionFeeBasisPoints = _maxOptionFeeBasisPoints;
        feeDestinationAddress = _feeDestinationAddress;
        emit TradeFeesUpdated(
            tradeFeeBasisPoints,
            maxOptionFeeBasisPoints,
            feeDestinationAddress
        );
    }

    /// Owner can set volatility config
    function setAmmConfig(
        int256 _ivShift,
        bool _dynamicIvEnabled,
        uint16 _ivDriftRate
    ) external override onlyOwner {
        ivShift = _ivShift;
        dynamicIvEnabled = _dynamicIvEnabled;
        ivDriftRate = _ivDriftRate;

        emit ConfigUpdated(ivShift, dynamicIvEnabled, ivDriftRate);
    }

    /// @notice update the logic contract for this proxy contract
    /// @param _newImplementation the address of the new MinterAmm implementation
    /// @dev only the admin address may call this function
    function updateImplementation(address _newImplementation)
        external
        onlyOwner
    {
        require(_newImplementation != address(0x0), "E10");

        _updateCodeAddress(_newImplementation);
    }

    function getAmmDataProvider() public view returns (IAmmDataProvider) {
        return IAmmDataProvider(addressesProvider.getAmmDataProvider());
    }

    /// LP allows collateral to be used to mint new options
    /// bTokens and wTokens will be held in this contract and can be traded back and forth.
    /// The amount of lpTokens is calculated based on total pool value
    function provideCapital(uint256 collateralAmount, uint256 lpTokenMinimum)
        external
        nonReentrant
    {
        // Move collateral into this contract
        collateralToken.safeTransferFrom(
            msg.sender,
            address(this),
            collateralAmount
        );

        // If first LP, mint options, mint LP tokens, and send back any redemption amount
        if (IERC20Lib(address(lpToken)).totalSupply() == 0) {
            // Mint lp tokens to the user
            lpToken.mint(msg.sender, collateralAmount);

            // Emit event
            LpTokensMinted(msg.sender, collateralAmount, collateralAmount);

            // Bail out after initial tokens are minted - nothing else to do
            return;
        }

        // At any given moment the AMM can have the following reserves:
        // * collateral token
        // * active bTokens and wTokens for any series
        // * expired bTokens and wTokens for any series
        // In order to calculate correct LP amount we do the following:
        // 1. Claim expired wTokens and bTokens
        // 2. Add value of all active bTokens and wTokens at current prices
        // 3. Add value of collateral

        claimAllExpiredTokens();

        uint256 poolValue = getAmmDataProvider().getTotalPoolValue(
            false,
            getAllSeries(),
            collateralBalance(),
            address(this),
            getBaselineVolatility()
        );

        // Mint LP tokens - the percentage added to bTokens should be same as lp tokens added
        uint256 lpTokenExistingSupply = IERC20Lib(address(lpToken))
            .totalSupply();

        uint256 lpTokensNewSupply = (poolValue * lpTokenExistingSupply) /
            (poolValue - collateralAmount);
        uint256 lpTokensToMint = lpTokensNewSupply - lpTokenExistingSupply;
        require(lpTokensToMint >= lpTokenMinimum, "E20");
        lpToken.mint(msg.sender, lpTokensToMint);

        // Emit event
        emit LpTokensMinted(msg.sender, collateralAmount, lpTokensToMint);
    }

    /// LP can redeem their LP tokens in exchange for collateral
    /// If `sellTokens` is true pro-rata active b/wTokens will be sold to the pool in exchange for collateral
    /// All expired wTokens will be claimed
    /// LP will get pro-rata collateral asset
    function withdrawCapital(
        uint256 lpTokenAmount,
        bool sellTokens,
        uint256 collateralMinimum
    ) public nonReentrant {
        require(!sellTokens || collateralMinimum > 0, "E12");
        // First get starting numbers
        uint256 redeemerCollateralBalance = collateralToken.balanceOf(
            msg.sender
        );

        // Get the lpToken supply
        uint256 lpTokenSupply = IERC20Lib(address(lpToken)).totalSupply();

        // Burn the lp tokens
        lpToken.burn(msg.sender, lpTokenAmount);

        // Claim all expired wTokens
        claimAllExpiredTokens();

        uint256 collateralTokenBalance = collateralBalance();

        // Withdraw pro-rata collateral token
        // We withdraw this collateral here instead of at the end,
        // because when we sell the residual tokens to the pool we want
        // to exclude the withdrawn collateral
        uint256 ammCollateralBalance = collateralTokenBalance -
            ((collateralTokenBalance * lpTokenAmount) / lpTokenSupply);

        if (sellTokens) {
            // Sell pro-rata active tokens
            require(lpTokenAmount < lpTokenSupply, "E21");
            ammCollateralBalance = _sellActiveTokens(
                lpTokenAmount,
                lpTokenSupply,
                ammCollateralBalance
            );
        } else {
            // Lock tokens
            IWTokenVault(addressesProvider.getWTokenVault()).lockActiveWTokens(
                lpTokenAmount,
                lpTokenSupply,
                msg.sender,
                getBaselineVolatility()
            );
        }

        // Send all accumulated collateralTokens
        collateralToken.safeTransfer(
            msg.sender,
            collateralTokenBalance - ammCollateralBalance
        );

        uint256 collateralTokenSent = collateralToken.balanceOf(msg.sender) -
            redeemerCollateralBalance;
        require(!sellTokens || collateralTokenSent >= collateralMinimum, "E20");

        // Emit the event
        emit LpTokensBurned(msg.sender, collateralTokenSent, lpTokenAmount);
    }

    /// Withdraws locked collateral
    function withdrawLockedCollateral(uint64[] memory expirationIds)
        external
        nonReentrant
    {
        // Claim all expired tokens
        claimAllExpiredTokens();

        uint256 claimableCollateral;

        for (uint256 i = 0; i < expirationIds.length; i++) {
            uint64 expirationId = expirationIds[i];
            uint256 expiration = seriesController.allowedExpirationsList(
                expirationId
            );
            require(expiration > 0, "E18");

            claimableCollateral += IWTokenVault(
                addressesProvider.getWTokenVault()
            ).redeemCollateral(expirationId, msg.sender);
        }

        lockedCollateral -= claimableCollateral;

        collateralToken.safeTransfer(msg.sender, claimableCollateral);
    }

    function lockCollateral(
        uint64 seriesId,
        uint256 collateralAmountMax,
        uint256 wTokenAmountMax
    ) internal {
        IWTokenVault wTokenVault = IWTokenVault(
            addressesProvider.getWTokenVault()
        );

        uint256 lockedWTokenBalance = wTokenVault.getWTokenBalance(
            address(this),
            seriesId
        );

        if (lockedWTokenBalance == 0) return;

        uint256 closedWTokens = Math.min(lockedWTokenBalance, wTokenAmountMax);
        uint256 collateralToLock = (collateralAmountMax * closedWTokens) /
            wTokenAmountMax;

        wTokenVault.lockCollateral(seriesId, collateralToLock, closedWTokens);

        lockedCollateral += collateralToLock;
    }

    /// @notice Claims any remaining collateral from all expired series whose wToken is held by the AMM, and removes
    /// the expired series from the AMM's collection of series
    function claimAllExpiredTokens() public {
        for (uint256 i = 0; i < openSeries.length(); i++) {
            uint64 seriesId = uint64(openSeries.at(i));
            while (
                seriesController.state(seriesId) ==
                ISeriesController.SeriesState.EXPIRED
            ) {
                claimExpiredTokens(seriesId);

                // Handle edge case: If, prior to removing the Series, i was the index of the last Series
                // in openSeries, then after the removal `i` will point to one beyond the end of the array.
                // This means we've iterated through all of the Series in `openSeries`, and we should break
                // out of the while loop. At this point i == openSeries.length(), so the outer for loop
                // will end as well
                if (i == openSeries.length()) {
                    break;
                } else {
                    seriesId = uint64(openSeries.at(i));
                }
            }
        }
    }

    /// @notice Claims any remaining collateral from expired series whose wToken is held by the AMM, and removes
    /// the expired series from the AMM's collection of series
    function claimExpiredTokens(uint64 seriesId) public {
        // claim the expired series' wTokens, which means it can now be safely removed
        uint256 bTokenIndex = SeriesLibrary.bTokenIndex(seriesId);
        uint256 wTokenIndex = SeriesLibrary.wTokenIndex(seriesId);

        uint256 bTokenBalance = erc1155Controller.balanceOf(
            address(this),
            bTokenIndex
        );
        if (bTokenBalance > 0) {
            seriesController.exerciseOption(seriesId, bTokenBalance, false);
        }

        uint256 wTokenBalance = erc1155Controller.balanceOf(
            address(this),
            wTokenIndex
        );
        if (wTokenBalance > 0) {
            uint256 collateralClaimed = seriesController.claimCollateral(
                seriesId,
                wTokenBalance
            );

            lockCollateral(seriesId, collateralClaimed, wTokenBalance);
        }
        // Remove the expired series to free storage and reduce gas fee
        // NOTE: openSeries.remove will remove the series from the iâ€™th position in the EnumerableSet by
        // swapping it with the last element in EnumerableSet and then calling .pop on the internal array.
        // We are relying on this undocumented behavior of EnumerableSet, which is acceptable because once
        // deployed we will never change the EnumerableSet logic.
        openSeries.remove(seriesId);

        emit SeriesEvicted(seriesId);
    }

    /// During liquidity withdrawal pro-rata active tokens back to the pool
    function _sellActiveTokens(
        uint256 lpTokenAmount,
        uint256 lpTokenSupply,
        uint256 collateralLeft
    ) internal view returns (uint256) {
        IWTokenVault wTokenVault = IWTokenVault(
            addressesProvider.getWTokenVault()
        );

        for (uint256 i = 0; i < openSeries.length(); i++) {
            uint64 seriesId = uint64(openSeries.at(i));
            if (
                seriesController.state(seriesId) ==
                ISeriesController.SeriesState.OPEN
            ) {
                uint256 wTokenIndex = SeriesLibrary.wTokenIndex(seriesId);

                // Get wToken balance excluding locked tokens
                uint256 wTokenAmount = ((erc1155Controller.balanceOf(
                    address(this),
                    wTokenIndex
                ) - wTokenVault.getWTokenBalance(address(this), seriesId)) *
                    lpTokenAmount) / lpTokenSupply;

                if (wTokenAmount > 0) {
                    // The LP sells their bToken and wToken to the AMM. The AMM
                    // pays the LP by reducing collateralLeft, which is what the
                    // AMM's collateral balance will be after executing this
                    // transaction (see MinterAmm.withdrawCapital to see where
                    // _sellActiveTokens gets called)
                    uint256 bTokenPrice = getPriceForSeries(seriesId);

                    // Note! It's possible that either of the two subraction operations
                    // below will underflow and return an error. This will only
                    // happen if the AMM does not have sufficient collateral
                    // balance to buy the bToken and wToken from the LP. If this
                    // happens, this transaction will revert with a
                    // "revert" error message
                    uint256 collateralAmountW = optionTokenGetCollateralOutInternal(
                            seriesId,
                            wTokenAmount,
                            collateralLeft,
                            bTokenPrice,
                            false
                        );
                    collateralLeft -= collateralAmountW;
                }
            }
        }

        return collateralLeft;
    }

    /// @notice List the Series ids this AMM trades
    /// @notice Warning: there is no guarantee that the indexes
    /// of any individual Series will remain constant between blocks. At any
    /// point the indexes of a particular Series may change, so do not rely on
    /// the indexes obtained from this function
    /// @return an array of all the series IDs
    function getAllSeries() public view override returns (uint64[] memory) {
        uint64[] memory series = new uint64[](openSeries.length());
        for (uint256 i = 0; i < openSeries.length(); i++) {
            series[i] = uint64(openSeries.at(i));
        }
        return series;
    }

    /// @notice Get a specific Series that this AMM trades
    /// @notice Warning: there is no guarantee that the indexes
    /// of any individual Series will remain constant between blocks. At any
    /// point the indexes of a particular Series may change, so do not rely on
    /// the indexes obtained from this function
    /// @param seriesId the ID of the Series
    /// @return an ISeries, if it exists
    function getSeries(uint64 seriesId)
        external
        view
        returns (ISeriesController.Series memory)
    {
        require(openSeries.contains(seriesId), "E13");
        return seriesController.series(seriesId);
    }

    /// @dev Get the current series price of the underlying token with units of priceToken,
    /// always with 8 decimals
    /// @dev For example, if underlying == WBTC and price == USDC, then this function will return
    /// 4500000000000 ($45_000 in human readable units)
    function getCurrentUnderlyingPrice()
        public
        view
        override
        returns (uint256)
    {
        return
            IPriceOracle(addressesProvider.getPriceOracle()).getCurrentPrice(
                address(underlyingToken),
                address(priceToken)
            );
    }

    /// @notice Get the bToken price for given Series, in units of the collateral token
    /// and normalized to 1e18. We use a normalization factor of 1e18 because we need
    /// to represent fractional values, yet Solidity does not support floating point numerics.
    /// @notice For example, if this is a WBTC Call option pool and so
    /// the collateral token is WBTC, then a return value of 0.5e18 means X units of bToken
    /// have a price of 0.5 * X units of WBTC. Another example; if this were a WBTC Put
    /// option pool, and so the collateral token is USDC, then a return value of 0.1e18 means
    /// X units of bToken have a price of 0.1 * X * strikePrice units of USDC.
    /// @notice This value will always be between 0 and 1e18, so you can think of it as
    /// representing the price as a fraction of 1 collateral token unit
    function getPriceForSeries(uint64 seriesId) public view returns (uint256) {
        require(openSeries.contains(seriesId), "E13");

        return
            getAmmDataProvider().getPriceForSeries(
                seriesId,
                getVolatility(seriesId)
            );
    }

    /// @dev Calculate the fee amount for a buy/sell
    /// If params are not set, the fee amount will be 0
    /// See contract comments above for logic explanation of fee calculations.
    function calculateFees(uint256 bTokenAmount, uint256 collateralAmount)
        public
        view
        override
        returns (uint256)
    {
        // Check if fees are enabled
        if (
            tradeFeeBasisPoints > 0 &&
            maxOptionFeeBasisPoints > 0 &&
            feeDestinationAddress != address(0x0)
        ) {
            uint256 tradeFee = 0;

            // The default fee is the basis points of the number of options being bought (e.g. bToken amount)
            uint256 defaultFee = (bTokenAmount * tradeFeeBasisPoints) / 10_000;

            // The max fee is based on the maximum percentage of the collateral being paid to buy the options
            uint256 maxFee = (collateralAmount * maxOptionFeeBasisPoints) /
                10_000;

            // Use the smaller of the 2
            if (defaultFee < maxFee) {
                tradeFee = defaultFee;
            } else {
                tradeFee = maxFee;
            }

            return tradeFee;
        }

        // Fees are not enabled
        return 0;
    }

    /// @dev Allows an owner to invoke a Direct Buy against the AMM
    /// A direct buy allows a signer wallet to predetermine a number of option
    ///     tokens to buy (senderAmount) with the specified number of collateral payment tokens (signerTokens).
    /// The direct buy will first use the collateral in the AMM to mint the options and
    ///     then execute a swap with the signer using Airswap protocol.
    /// Only the owner should be allowed to execute a direct buy as this is a "guarded" call.
    /// Sender address in the Airswap protocol will be this contract address.
    function bTokenDirectBuy(
        uint64 seriesId,
        uint256 nonce, // Nonce on the airswap sig for the signer
        uint256 expiry, // Date until swap is valid
        address signerWallet, // Address of the buyer (signer)
        uint256 signerAmount, // Amount of collateral that will be paid for options by the signer
        uint256 senderAmount, // Amount of options to buy from the AMM
        uint8 v, // Sig of signer wallet for Airswap
        bytes32 r, // Sig of signer wallet for Airswap
        bytes32 s // Sig of signer wallet for Airswap
    ) external nonReentrant {
        require(
            msg.sender == addressesProvider.getDirectBuyManager(),
            "!manager"
        );
        require(openSeries.contains(seriesId), "E13");

        address airswapLight = addressesProvider.getAirswapLight();
        require(airswapLight != address(0x0), "E16");

        // Get the bToken balance of the AMM
        uint256 bTokenIndex = SeriesLibrary.bTokenIndex(seriesId);
        uint256 bTokenBalance = erc1155Controller.balanceOf(
            address(this),
            bTokenIndex
        );

        // Mint required number of bTokens for the direct buy (if required)
        if (bTokenBalance < senderAmount) {
            // Approve the collateral to mint bTokenAmount of new options
            uint256 bTokenCollateralAmount = seriesController
                .getCollateralPerOptionToken(
                    seriesId,
                    senderAmount - bTokenBalance
                );

            collateralToken.approve(
                address(seriesController),
                bTokenCollateralAmount
            );

            // If the AMM does not have enough collateral to mint tokens, expect revert.
            seriesController.mintOptions(
                seriesId,
                senderAmount - bTokenBalance
            );
        }

        // Approve the bTokens to be swapped
        erc1155Controller.setApprovalForAll(airswapLight, true);

        // Now that the contract has enough bTokens, swap with the buyer
        ILight(airswapLight).swap(
            nonce, // Signer's nonce
            expiry, // Expiration date of swap
            signerWallet, // Buyer of the options
            address(collateralToken), // Payment made by buyer
            signerAmount, // Amount of collateral paid for options
            address(erc1155Controller), // Address of erc1155 contract
            bTokenIndex, // Token ID for options
            senderAmount, // Num options to sell
            v,
            r,
            s
        ); // Sig of signer for swap

        // Remove approval
        erc1155Controller.setApprovalForAll(airswapLight, false);

        // Calculate trade fees if they are enabled with all params set
        uint256 tradeFee = calculateFees(senderAmount, signerAmount);

        // If fees were taken, move them to the destination
        if (tradeFee > 0) {
            collateralToken.safeTransfer(feeDestinationAddress, tradeFee);
            emit TradeFeesPaid(feeDestinationAddress, tradeFee);
        }

        // Emit the event
        emit BTokensBought(signerWallet, seriesId, senderAmount, signerAmount);
    }

    /// @dev Buy bToken of a given series.
    /// We supply series index instead of series address to ensure that only supported series can be traded using this AMM
    /// collateralMaximum is used for slippage protection.
    /// @notice Trade fees are added to the collateral amount moved from the buyer's account to pay for the bToken
    function bTokenBuy(
        uint64 seriesId,
        uint256 bTokenAmount,
        uint256 collateralMaximum
    ) external override nonReentrant returns (uint256) {
        require(openSeries.contains(seriesId), "E13");

        require(
            seriesController.state(seriesId) ==
                ISeriesController.SeriesState.OPEN,
            "E22" // Series has expired
        );
        uint256 collateralAmount;
        {
            uint256 underlyingPrice = getCurrentUnderlyingPrice();
            (uint256 price, uint256 vega) = calculatePriceAndVega(
                seriesId,
                underlyingPrice
            );
            require(price > 0, "E17");

            collateralAmount = getAmmDataProvider().bTokenGetCollateralIn(
                seriesId,
                address(this),
                bTokenAmount,
                collateralBalance(),
                price
            );
            require(
                collateralAmount * 1e18 >=
                    seriesController.getCollateralPerUnderlying(
                        seriesId,
                        price * bTokenAmount,
                        underlyingPrice
                    ),
                "E23" // Buy amount is too low
            );

            if (dynamicIvEnabled) {
                uint256 priceImpact;
                if (seriesController.isPutOption(seriesId)) {
                    priceImpact =
                        (collateralAmount * 1e26) /
                        seriesController.getCollateralPerUnderlying(
                            seriesId,
                            bTokenAmount,
                            1e8
                        ) /
                        underlyingPrice -
                        price;
                } else {
                    priceImpact =
                        (collateralAmount * 1e18) /
                        bTokenAmount -
                        price;
                }

                updateVolatility(
                    seriesId,
                    int256(priceImpact),
                    getVolatility(seriesId),
                    vega
                );
            }
        }

        // Calculate trade fees if they are enabled with all params set
        uint256 tradeFee = calculateFees(bTokenAmount, collateralAmount);
        require(
            collateralAmount + tradeFee <= collateralMaximum,
            "E20" // Slippage exceeded
        );

        // Move collateral into this contract
        collateralToken.safeTransferFrom(
            msg.sender,
            address(this),
            collateralAmount + tradeFee
        );

        // If fees were taken, move them to the destination
        if (tradeFee > 0) {
            collateralToken.safeTransfer(feeDestinationAddress, tradeFee);
            emit TradeFeesPaid(feeDestinationAddress, tradeFee);
        }

        // Approve the collateral to mint bTokenAmount of new options
        uint256 bTokenCollateralAmount = seriesController
            .getCollateralPerOptionToken(seriesId, bTokenAmount);

        collateralToken.approve(
            address(seriesController),
            bTokenCollateralAmount
        );
        seriesController.mintOptions(seriesId, bTokenAmount);

        // Send all bTokens back
        bytes memory data;
        erc1155Controller.safeTransferFrom(
            address(this),
            msg.sender,
            SeriesLibrary.bTokenIndex(seriesId),
            bTokenAmount,
            data
        );

        // Emit the event
        emit BTokensBought(
            msg.sender,
            seriesId,
            bTokenAmount,
            collateralAmount + tradeFee
        );

        // Return the amount of collateral required to buy
        return collateralAmount + tradeFee;
    }

    /// @notice Sell the bToken of a given series to the AMM in exchange for collateral token
    /// @notice This call will fail if the caller tries to sell a bToken amount larger than the amount of
    /// wToken held by the AMM
    /// @notice Trade fees are subracted from the collateral amount moved to the seller's account in exchange for bTokens
    /// @param seriesId The ID of the Series to buy bToken on
    /// @param bTokenAmount The amount of bToken to sell (bToken has the same decimals as the underlying)
    /// @param collateralMinimum The lowest amount of collateral the caller is willing to receive as payment
    /// for their bToken. The actual amount of bToken received may be lower than this due to slippage
    function bTokenSell(
        uint64 seriesId,
        uint256 bTokenAmount,
        uint256 collateralMinimum
    ) external override nonReentrant returns (uint256) {
        require(openSeries.contains(seriesId), "E13");

        require(
            seriesController.state(seriesId) ==
                ISeriesController.SeriesState.OPEN,
            "E22" // Series has expired
        );
        uint256 collateralAmount;
        {
            uint256 underlyingPrice = getCurrentUnderlyingPrice();
            (uint256 price, uint256 vega) = calculatePriceAndVega(
                seriesId,
                underlyingPrice
            );
            require(price > 0, "E17");

            collateralAmount = optionTokenGetCollateralOutInternal(
                seriesId,
                bTokenAmount,
                collateralBalance(),
                price,
                true
            );
            require(
                collateralAmount * 1e18 <=
                    seriesController.getCollateralPerUnderlying(
                        seriesId,
                        price * bTokenAmount,
                        underlyingPrice
                    ),
                "E23" // Sell amount is too low
            );

            if (dynamicIvEnabled) {
                uint256 priceImpact;
                if (seriesController.isPutOption(seriesId)) {
                    priceImpact =
                        price -
                        (collateralAmount * 1e26) /
                        seriesController.getCollateralPerUnderlying(
                            seriesId,
                            bTokenAmount,
                            1e8
                        ) /
                        underlyingPrice;
                } else {
                    priceImpact =
                        price -
                        (collateralAmount * 1e18) /
                        bTokenAmount;
                }

                updateVolatility(
                    seriesId,
                    -int256(priceImpact),
                    getVolatility(seriesId),
                    vega
                );
            }
        }

        // Calculate trade fees if they are enabled with all params set
        uint256 tradeFee = calculateFees(bTokenAmount, collateralAmount);

        require(
            collateralAmount - tradeFee >= collateralMinimum,
            "E20" // Slippage exceeded
        );

        uint256 bTokenIndex = SeriesLibrary.bTokenIndex(seriesId);

        // Move bToken into this contract
        bytes memory data;
        erc1155Controller.safeTransferFrom(
            msg.sender,
            address(this),
            bTokenIndex,
            bTokenAmount,
            data
        );

        // at this point we know it's worth calling closePosition because
        // the close amount is greater than 0, so let's call it and burn
        // excess option tokens in order to receive collateral tokens
        // and lock collateral in the WTokenVault
        lockCollateral(
            seriesId,
            seriesController.closePosition(seriesId, bTokenAmount) -
                collateralAmount,
            bTokenAmount
        );

        // Send the tokens to the seller
        collateralToken.safeTransfer(msg.sender, collateralAmount - tradeFee);

        // If fees were taken, move them to the destination
        if (tradeFee > 0) {
            collateralToken.safeTransfer(feeDestinationAddress, tradeFee);
            emit TradeFeesPaid(feeDestinationAddress, tradeFee);
        }

        // Emit the event
        emit BTokensSold(
            msg.sender,
            seriesId,
            bTokenAmount,
            collateralAmount - tradeFee
        );

        // Return the amount of collateral received during sale
        return collateralAmount - tradeFee;
    }

    /// @dev Calculates the amount of collateral token a seller will receive for selling their option tokens,
    /// taking into account the AMM's level of reserves
    /// @param seriesId The ID of the Series
    /// @param optionTokenAmount The amount of option tokens (either bToken or wToken) to be sold
    /// @param _collateralTokenBalance The amount of collateral token held by this AMM
    /// @param isBToken true if the option token is bToken, and false if it's wToken. Depending on which
    /// of the two it is, the equation for calculating the final collateral token is a little different
    /// @return The amount of collateral token the seller will receive in exchange for their option token
    function optionTokenGetCollateralOutInternal(
        uint64 seriesId,
        uint256 optionTokenAmount,
        uint256 _collateralTokenBalance,
        uint256 bTokenPrice,
        bool isBToken
    ) private view returns (uint256) {
        return
            getAmmDataProvider().optionTokenGetCollateralOut(
                seriesId,
                address(this),
                optionTokenAmount,
                _collateralTokenBalance,
                bTokenPrice,
                isBToken
            );
    }

    /// @notice Adds the address of series to the amm
    /// @dev Only the associated SeriesController may call this function
    /// @dev The SeriesController calls this function when it is creating a Series
    /// and adds the Series to this AMM
    function addSeries(uint64 _seriesId) external override {
        require(msg.sender == address(seriesController), "E11");
        // Prevents out of gas error, occuring at 250 series, from locking
        // in LPs when we cycle over openSeries in _sellActiveTokens.
        // We further lower the limit to 60 series for extra safety.
        require(openSeries.length() <= 60, "E24"); // Too many open series
        openSeries.add(_seriesId);
    }

    /// @notice Returns true when interfaceId is the ID of the addSeries function or the ERC165
    /// standard, and false otherwise
    /// @dev This function exists only so the SeriesController can tell when to try to add
    /// Series it has created to the MinterAmm
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return
            interfaceId == this.addSeries.selector ||
            super.supportsInterface(interfaceId);
    }

    function calculatePriceAndVega(uint64 seriesId, uint256 underlyingPrice)
        internal
        view
        returns (uint256 price, uint256 vega)
    {
        ISeriesController.Series memory series = seriesController.series(
            seriesId
        );
        IBlackScholes blackScholes = IBlackScholes(
            addressesProvider.getBlackScholes()
        );

        IBlackScholes.PricesStdVega memory pricesStdVega = blackScholes
            .pricesStdVegaInUnderlying(
                series.expirationDate - block.timestamp,
                getVolatility(seriesId),
                underlyingPrice,
                series.strikePrice,
                0,
                series.isPutOption
            );
        return (pricesStdVega.price, pricesStdVega.stdVega);
    }

    function collateralBalance() public view override returns (uint256) {
        return collateralToken.balanceOf(address(this)) - lockedCollateral;
    }
}
