pragma solidity ^0.5.16;

import "./WLToken.sol";
import "./ErrorReporter.sol";
import "./PriceOracle.sol";
import "./ComptrollerInterface.sol";
import "./ComptrollerStorage.sol";
import "./Unitroller.sol";
import "./Governance/WEL.sol";

contract Comptroller is ComptrollerV1Storage, ComptrollerInterface, ComptrollerErrorReporter, ExponentialNoError {
    event MarketListed(WLToken wlToken);
    event MarketEntered(WLToken wlToken, address account);
    event MarketExited(WLToken wlToken, address account);
    event NewCloseFactor(uint oldCloseFactorMantissa, uint newCloseFactorMantissa);
    event NewCollateralFactor(WLToken wlToken, uint oldCollateralFactorMantissa, uint newCollateralFactorMantissa);
    event NewLiquidationIncentive(uint oldLiquidationIncentiveMantissa, uint newLiquidationIncentiveMantissa);
    event NewPriceOracle(PriceOracle oldPriceOracle, PriceOracle newPriceOracle);
    event NewPauseGuardian(address oldPauseGuardian, address newPauseGuardian);
    event ActionPaused(string action, bool pauseState);
    event ActionPaused(WLToken wlToken, string action, bool pauseState);
    event WelSpeedUpdated(WLToken indexed wlToken, uint newSpeed);
    event DistributedSupplierWel(WLToken indexed wlToken, address indexed supplier, uint welDelta, uint welSupplyIndex);
    event DistributedBorrowerWel(WLToken indexed wlToken, address indexed borrower, uint welDelta, uint welBorrowIndex);
    event ActionProtocolPaused(bool state);
    event NewBorrowCap(WLToken indexed wlToken, uint newBorrowCap);
    event NewBorrowCapGuardian(address oldBorrowCapGuardian, address newBorrowCapGuardian);
    event NewTreasuryGuardian(address oldTreasuryGuardian, address newTreasuryGuardian);
    event NewTreasuryAddress(address oldTreasuryAddress, address newTreasuryAddress);
    event NewTreasuryPercent(uint oldTreasuryPercent, uint newTreasuryPercent);
    uint224 public constant welInitialIndex = 1e36;
    uint internal constant closeFactorMinMantissa = 0.05e18; // 0.05
    uint internal constant closeFactorMaxMantissa = 0.9e18; // 0.9
    uint internal constant collateralFactorMaxMantissa = 0.9e18; // 0.9
    constructor() public {
        admin = msg.sender;
    }
    modifier onlyProtocolAllowed {
        require(!protocolPaused, "protocol is paused");
        _;
    }
    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin can");
        _;
    }
    modifier onlyListedMarket(WLToken wlToken) {
        require(markets[address(wlToken)].isListed, "wel market is not listed");
        _;
    }
    modifier validPauseState(bool state) {
        require(msg.sender == pauseGuardian || msg.sender == admin, "only pause guardian and admin can");
        require(msg.sender == admin || state == true, "only admin can unpause");
        _;
    }
    function getAssetsIn(address account) external view returns (WLToken[] memory) {
        return accountAssets[account];
    }
    function checkMembership(address account, WLToken wlToken) external view returns (bool) {
        return markets[address(wlToken)].accountMembership[account];
    }
    function enterMarkets(address[] calldata wlTokens) external returns (uint[] memory) {
        uint len = wlTokens.length;
        uint[] memory results = new uint[](len);
        for (uint i = 0; i < len; i++) {
            results[i] = uint(addToMarketInternal(WLToken(wlTokens[i]), msg.sender));
        }
        return results;
    }
    function addToMarketInternal(WLToken wlToken, address borrower) internal returns (Error) {
        Market storage marketToJoin = markets[address(wlToken)];
        if (!marketToJoin.isListed) {
            // market is not listed, cannot join
            return Error.MARKET_NOT_LISTED;
        }
        if (marketToJoin.accountMembership[borrower]) {
            // already joined
            return Error.NO_ERROR;
        }
        marketToJoin.accountMembership[borrower] = true;
        accountAssets[borrower].push(wlToken);
        emit MarketEntered(wlToken, borrower);
        return Error.NO_ERROR;
    }
    function exitMarket(address wlTokenAddress) external returns (uint) {
        WLToken wlToken = WLToken(wlTokenAddress);
        (uint oErr, uint tokensHeld, uint amountOwed, ) = wlToken.getAccountSnapshot(msg.sender);
        require(oErr == 0, "getAccountSnapshot failed"); // semi-opaque error code
        if (amountOwed != 0) {
            return fail(Error.NONZERO_BORROW_BALANCE, FailureInfo.EXIT_MARKET_BALANCE_OWED);
        }
        uint allowed = redeemAllowedInternal(wlTokenAddress, msg.sender, tokensHeld);
        if (allowed != 0) {
            return failOpaque(Error.REJECTION, FailureInfo.EXIT_MARKET_REJECTION, allowed);
        }
        Market storage marketToExit = markets[address(wlToken)];
        if (!marketToExit.accountMembership[msg.sender]) {
            return uint(Error.NO_ERROR);
        }
        delete marketToExit.accountMembership[msg.sender];
        WLToken[] storage userAssetList = accountAssets[msg.sender];
        uint len = userAssetList.length;
        uint i;
        for (; i < len; i++) {
            if (userAssetList[i] == wlToken) {
                userAssetList[i] = userAssetList[len - 1];
                userAssetList.length--;
                break;
            }
        }
        assert(i < len);
        emit MarketExited(wlToken, msg.sender);
        return uint(Error.NO_ERROR);
    }
    /*** Policy Hooks ***/
    function mintAllowed(address wlToken, address minter, uint mintAmount) external onlyProtocolAllowed returns (uint) {
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!mintGuardianPaused[wlToken], "mint is paused");
        mintAmount;
        if (!markets[wlToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }
        updateWelSupplyIndex(wlToken);
        distributeSupplierWel(wlToken, minter);
        return uint(Error.NO_ERROR);
    }
    function mintVerify(address wlToken, address minter, uint actualMintAmount, uint mintTokens) external {
        wlToken;
        minter;
        actualMintAmount;
        mintTokens;
    }
    function redeemAllowed(address wlToken, address redeemer, uint redeemTokens) external onlyProtocolAllowed returns (uint) {
        uint allowed = redeemAllowedInternal(wlToken, redeemer, redeemTokens);
        if (allowed != uint(Error.NO_ERROR)) {
            return allowed;
        }
        updateWelSupplyIndex(wlToken);
        distributeSupplierWel(wlToken, redeemer);
        return uint(Error.NO_ERROR);
    }
    function redeemAllowedInternal(address wlToken, address redeemer, uint redeemTokens) internal view returns (uint) {
        if (!markets[wlToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }
        if (!markets[wlToken].accountMembership[redeemer]) {
            return uint(Error.NO_ERROR);
        }
        (Error err, , uint shortfall) = getHypotheticalAccountLiquidityInternal(redeemer, WLToken(wlToken), redeemTokens, 0);
        if (err != Error.NO_ERROR) {
            return uint(err);
        }
        if (shortfall != 0) {
            return uint(Error.INSUFFICIENT_LIQUIDITY);
        }
        return uint(Error.NO_ERROR);
    }
    function redeemVerify(address wlToken, address redeemer, uint redeemAmount, uint redeemTokens) external {
        // Shh - currently unused
        wlToken;
        redeemer;
        require(redeemTokens != 0 || redeemAmount == 0, "redeemTokens zero");
    }
    function borrowAllowed(address wlToken, address borrower, uint borrowAmount) external onlyProtocolAllowed returns (uint) {
        require(!borrowGuardianPaused[wlToken], "borrow is paused");
        if (!markets[wlToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        if (!markets[wlToken].accountMembership[borrower]) {
            require(msg.sender == wlToken, "sender must be wlToken");
            Error err = addToMarketInternal(WLToken(wlToken), borrower);
            if (err != Error.NO_ERROR) {
                return uint(err);
            }
        }
        if (oracle.getUnderlyingPrice(WLToken(wlToken)) == 0) {
            return uint(Error.PRICE_ERROR);
        }
        uint borrowCap = borrowCaps[wlToken];
        if (borrowCap != 0) {
            uint totalBorrows = WLToken(wlToken).totalBorrows();
            uint nextTotalBorrows = add_(totalBorrows, borrowAmount);
            require(nextTotalBorrows < borrowCap, "market borrow cap reached");
        }
        (Error err, , uint shortfall) = getHypotheticalAccountLiquidityInternal(borrower, WLToken(wlToken), 0, borrowAmount);
        if (err != Error.NO_ERROR) {
            return uint(err);
        }
        if (shortfall != 0) {
            return uint(Error.INSUFFICIENT_LIQUIDITY);
        }
        Exp memory borrowIndex = Exp({mantissa: WLToken(wlToken).borrowIndex()});
        updateWelBorrowIndex(wlToken, borrowIndex);
        distributeBorrowerWel(wlToken, borrower, borrowIndex);
        return uint(Error.NO_ERROR);
    }
    function borrowVerify(address wlToken, address borrower, uint borrowAmount) external {
        wlToken;
        borrower;
        borrowAmount;
        if (false) {
            maxAssets = maxAssets;
        }
    }
    function repayBorrowAllowed(
        address wlToken,
        address payer,
        address borrower,
        uint repayAmount) external onlyProtocolAllowed returns (uint) {
        payer;
        borrower;
        repayAmount;
        if (!markets[wlToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }
        Exp memory borrowIndex = Exp({mantissa: WLToken(wlToken).borrowIndex()});
        updateWelBorrowIndex(wlToken, borrowIndex);
        distributeBorrowerWel(wlToken, borrower, borrowIndex);
        return uint(Error.NO_ERROR);
    }
    function repayBorrowVerify(
        address wlToken,
        address payer,
        address borrower,
        uint actualRepayAmount,
        uint borrowerIndex) external {
        // Shh - currently unused
        wlToken;
        payer;
        borrower;
        actualRepayAmount;
        borrowerIndex;
        if (false) {
            maxAssets = maxAssets;
        }
    }
    function liquidateBorrowAllowed(
        address wlTokenBorrowed,
        address wlTokenCollateral,
        address liquidator,
        address borrower,
        uint repayAmount) external onlyProtocolAllowed returns (uint) {
        liquidator;
        if (!markets[wlTokenCollateral].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }
        (Error err, , uint shortfall) = getHypotheticalAccountLiquidityInternal(borrower, WLToken(0), 0, 0);
        if (err != Error.NO_ERROR) {
            return uint(err);
        }
        if (shortfall == 0) {
            return uint(Error.INSUFFICIENT_SHORTFALL);
        }
        uint borrowBalance = WLToken(wlTokenBorrowed).borrowBalanceStored(borrower);
        uint maxClose = mul_ScalarTruncate(Exp({mantissa: closeFactorMantissa}), borrowBalance);
        if (repayAmount > maxClose) {
            return uint(Error.TOO_MUCH_REPAY);
        }
        return uint(Error.NO_ERROR);
    }
    function liquidateBorrowVerify(
        address wlTokenBorrowed,
        address wlTokenCollateral,
        address liquidator,
        address borrower,
        uint actualRepayAmount,
        uint seizeTokens) external {
        // Shh - currently unused
        wlTokenBorrowed;
        wlTokenCollateral;
        liquidator;
        borrower;
        actualRepayAmount;
        seizeTokens;
        if (false) {
            maxAssets = maxAssets;
        }
    }
    function seizeAllowed(
        address wlTokenCollateral,
        address wlTokenBorrowed,
        address liquidator,
        address borrower,
        uint seizeTokens) external onlyProtocolAllowed returns (uint) {
        require(!seizeGuardianPaused, "seize is paused");
        seizeTokens;
        if (!markets[wlTokenCollateral].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }
        if (WLToken(wlTokenCollateral).comptroller() != WLToken(wlTokenBorrowed).comptroller()) {
            return uint(Error.COMPTROLLER_MISMATCH);
        }
        updateWelSupplyIndex(wlTokenCollateral);
        distributeSupplierWel(wlTokenCollateral, borrower);
        distributeSupplierWel(wlTokenCollateral, liquidator);
        return uint(Error.NO_ERROR);
    }
    function seizeVerify(
        address wlTokenCollateral,
        address wlTokenBorrowed,
        address liquidator,
        address borrower,
        uint seizeTokens) external {
        // Shh - currently unused
        wlTokenCollateral;
        wlTokenBorrowed;
        liquidator;
        borrower;
        seizeTokens;
        if (false) {
            maxAssets = maxAssets;
        }
    }
    function transferAllowed(address wlToken, address src, address dst, uint transferTokens) external onlyProtocolAllowed returns (uint) {
        require(!transferGuardianPaused, "transfer is paused");
        uint allowed = redeemAllowedInternal(wlToken, src, transferTokens);
        if (allowed != uint(Error.NO_ERROR)) {
            return allowed;
        }
        updateWelSupplyIndex(wlToken);
        distributeSupplierWel(wlToken, src);
        distributeSupplierWel(wlToken, dst);
        return uint(Error.NO_ERROR);
    }
    function transferVerify(address wlToken, address src, address dst, uint transferTokens) external {
        // Shh - currently unused
        wlToken;
        src;
        dst;
        transferTokens;
        if (false) {
            maxAssets = maxAssets;
        }
    }
    struct AccountLiquidityLocalVars {
        uint sumCollateral;
        uint sumBorrowPlusEffects;
        uint wlTokenBalance;
        uint borrowBalance;
        uint exchangeRateMantissa;
        uint oraclePriceMantissa;
        Exp collateralFactor;
        Exp exchangeRate;
        Exp oraclePrice;
        Exp tokensToDenom;
    }
    function getAccountLiquidity(address account) public view returns (uint, uint, uint) {
        (Error err, uint liquidity, uint shortfall) = getHypotheticalAccountLiquidityInternal(account, WLToken(0), 0, 0);
        return (uint(err), liquidity, shortfall);
    }
    function getHypotheticalAccountLiquidity(
        address account,
        address wlTokenModify,
        uint redeemTokens,
        uint borrowAmount) public view returns (uint, uint, uint) {
        (Error err, uint liquidity, uint shortfall) = getHypotheticalAccountLiquidityInternal(account, WLToken(wlTokenModify), redeemTokens, borrowAmount);
        return (uint(err), liquidity, shortfall);
    }
    function getHypotheticalAccountLiquidityInternal(
        address account,
        WLToken wlTokenModify,
        uint redeemTokens,
        uint borrowAmount) internal view returns (Error, uint, uint) {
        AccountLiquidityLocalVars memory vars; // Holds all our calculation results
        uint oErr;
        WLToken[] memory assets = accountAssets[account];
        for (uint i = 0; i < assets.length; i++) {
            WLToken asset = assets[i];
            (oErr, vars.wlTokenBalance, vars.borrowBalance, vars.exchangeRateMantissa) = asset.getAccountSnapshot(account);
            if (oErr != 0) {
                return (Error.SNAPSHOT_ERROR, 0, 0);
            }
            vars.collateralFactor = Exp({mantissa: markets[address(asset)].collateralFactorMantissa});
            vars.exchangeRate = Exp({mantissa: vars.exchangeRateMantissa});
            vars.oraclePriceMantissa = oracle.getUnderlyingPrice(asset);
            if (vars.oraclePriceMantissa == 0) {
                return (Error.PRICE_ERROR, 0, 0);
            }
            vars.oraclePrice = Exp({mantissa: vars.oraclePriceMantissa});
           vars.tokensToDenom = mul_(mul_(vars.collateralFactor, vars.exchangeRate), vars.oraclePrice);
            vars.sumCollateral = mul_ScalarTruncateAddUInt(vars.tokensToDenom, vars.wlTokenBalance, vars.sumCollateral);
            vars.sumBorrowPlusEffects = mul_ScalarTruncateAddUInt(vars.oraclePrice, vars.borrowBalance, vars.sumBorrowPlusEffects);
            if (asset == wlTokenModify) {
                vars.sumBorrowPlusEffects = mul_ScalarTruncateAddUInt(vars.tokensToDenom, redeemTokens, vars.sumBorrowPlusEffects);
                vars.sumBorrowPlusEffects = mul_ScalarTruncateAddUInt(vars.oraclePrice, borrowAmount, vars.sumBorrowPlusEffects);
            }
        }
        if (vars.sumCollateral > vars.sumBorrowPlusEffects) {
            return (Error.NO_ERROR, vars.sumCollateral - vars.sumBorrowPlusEffects, 0);
        } else {
            return (Error.NO_ERROR, 0, vars.sumBorrowPlusEffects - vars.sumCollateral);
        }
    }
    function liquidateCalculateSeizeTokens(address wlTokenBorrowed, address wlTokenCollateral, uint actualRepayAmount) external view returns (uint, uint) {
        uint priceBorrowedMantissa = oracle.getUnderlyingPrice(WLToken(wlTokenBorrowed));
        uint priceCollateralMantissa = oracle.getUnderlyingPrice(WLToken(wlTokenCollateral));
        if (priceBorrowedMantissa == 0 || priceCollateralMantissa == 0) {
            return (uint(Error.PRICE_ERROR), 0);
        }
        uint exchangeRateMantissa = WLToken(wlTokenCollateral).exchangeRateStored(); // Note: reverts on error
        uint seizeTokens;
        Exp memory numerator;
        Exp memory denominator;
        Exp memory ratio;
        numerator = mul_(Exp({mantissa: liquidationIncentiveMantissa}), Exp({mantissa: priceBorrowedMantissa}));
        denominator = mul_(Exp({mantissa: priceCollateralMantissa}), Exp({mantissa: exchangeRateMantissa}));
        ratio = div_(numerator, denominator);
        seizeTokens = mul_ScalarTruncate(ratio, actualRepayAmount);
        return (uint(Error.NO_ERROR), seizeTokens);
    }
    function _setPriceOracle(PriceOracle newOracle) public returns (uint) {
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_PRICE_ORACLE_OWNER_CHECK);
        }
        PriceOracle oldOracle = oracle;
        oracle = newOracle;
        emit NewPriceOracle(oldOracle, newOracle);
        return uint(Error.NO_ERROR);
    }
    function _setCloseFactor(uint newCloseFactorMantissa) external returns (uint) {
        require(msg.sender == admin, "only admin can set close factor");
        uint oldCloseFactorMantissa = closeFactorMantissa;
        closeFactorMantissa = newCloseFactorMantissa;
        emit NewCloseFactor(oldCloseFactorMantissa, newCloseFactorMantissa);
        return uint(Error.NO_ERROR);
    }
    function _setCollateralFactor(WLToken wlToken, uint newCollateralFactorMantissa) external returns (uint) {
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_COLLATERAL_FACTOR_OWNER_CHECK);
        }
        Market storage market = markets[address(wlToken)];
        if (!market.isListed) {
            return fail(Error.MARKET_NOT_LISTED, FailureInfo.SET_COLLATERAL_FACTOR_NO_EXISTS);
        }
        Exp memory newCollateralFactorExp = Exp({mantissa: newCollateralFactorMantissa});
        Exp memory highLimit = Exp({mantissa: collateralFactorMaxMantissa});
        if (lessThanExp(highLimit, newCollateralFactorExp)) {
            return fail(Error.INVALID_COLLATERAL_FACTOR, FailureInfo.SET_COLLATERAL_FACTOR_VALIDATION);
        }
        if (newCollateralFactorMantissa != 0 && oracle.getUnderlyingPrice(wlToken) == 0) {
            return fail(Error.PRICE_ERROR, FailureInfo.SET_COLLATERAL_FACTOR_WITHOUT_PRICE);
        }
        uint oldCollateralFactorMantissa = market.collateralFactorMantissa;
        market.collateralFactorMantissa = newCollateralFactorMantissa;
        emit NewCollateralFactor(wlToken, oldCollateralFactorMantissa, newCollateralFactorMantissa);
        return uint(Error.NO_ERROR);
    }
    function _setLiquidationIncentive(uint newLiquidationIncentiveMantissa) external returns (uint) {
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_LIQUIDATION_INCENTIVE_OWNER_CHECK);
        }
        uint oldLiquidationIncentiveMantissa = liquidationIncentiveMantissa;
        liquidationIncentiveMantissa = newLiquidationIncentiveMantissa;
        emit NewLiquidationIncentive(oldLiquidationIncentiveMantissa, newLiquidationIncentiveMantissa);
        return uint(Error.NO_ERROR);
    }
    function _supportMarket(WLToken wlToken) external returns (uint) {
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SUPPORT_MARKET_OWNER_CHECK);
        }
        if (markets[address(wlToken)].isListed) {
            return fail(Error.MARKET_ALREADY_LISTED, FailureInfo.SUPPORT_MARKET_EXISTS);
        }
        wlToken.isWLToken(); // Sanity check to make sure its really a WLToken
        markets[address(wlToken)] = Market({isListed: true, isWel: false, collateralFactorMantissa: 0});
        _addMarketInternal(wlToken);
        emit MarketListed(wlToken);
        return uint(Error.NO_ERROR);
    }
    function _addMarketInternal(WLToken wlToken) internal {
        for (uint i = 0; i < allMarkets.length; i ++) {
            require(allMarkets[i] != wlToken, "market already added");
        }
        allMarkets.push(wlToken);
    }
    function _setPauseGuardian(address newPauseGuardian) public returns (uint) {
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_PAUSE_GUARDIAN_OWNER_CHECK);
        }
        address oldPauseGuardian = pauseGuardian;
        pauseGuardian = newPauseGuardian;
        emit NewPauseGuardian(oldPauseGuardian, newPauseGuardian);
        return uint(Error.NO_ERROR);
    }
    function _setMarketBorrowCaps(WLToken[] calldata wlTokens, uint[] calldata newBorrowCaps) external {
    	require(msg.sender == admin || msg.sender == borrowCapGuardian, "only admin or borrow cap guardian can set borrow caps");

        uint numMarkets = wlTokens.length;
        uint numBorrowCaps = newBorrowCaps.length;

        require(numMarkets != 0 && numMarkets == numBorrowCaps, "invalid input");

        for(uint i = 0; i < numMarkets; i++) {
            borrowCaps[address(wlTokens[i])] = newBorrowCaps[i];
            emit NewBorrowCap(wlTokens[i], newBorrowCaps[i]);
        }
    }
    function _setBorrowCapGuardian(address newBorrowCapGuardian) external onlyAdmin {
        // Save current value for inclusion in log
        address oldBorrowCapGuardian = borrowCapGuardian;

        // Store borrowCapGuardian with value newBorrowCapGuardian
        borrowCapGuardian = newBorrowCapGuardian;

        // Emit NewBorrowCapGuardian(OldBorrowCapGuardian, NewBorrowCapGuardian)
        emit NewBorrowCapGuardian(oldBorrowCapGuardian, newBorrowCapGuardian);
    }
    function _setProtocolPaused(bool state) public validPauseState(state) returns(bool) {
        protocolPaused = state;
        emit ActionProtocolPaused(state);
        return state;
    }
    function _setTreasuryData(address newTreasuryGuardian, address newTreasuryAddress, uint newTreasuryPercent) external returns (uint) {
        if (!(msg.sender == admin || msg.sender == treasuryGuardian)) {
            return fail(Error.UNAUTHORIZED, FailureInfo.SET_TREASURY_OWNER_CHECK);
        }
        require(newTreasuryPercent < 1e18, "treasury percent cap overflow");
        address oldTreasuryGuardian = treasuryGuardian;
        address oldTreasuryAddress = treasuryAddress;
        uint oldTreasuryPercent = treasuryPercent;
        treasuryGuardian = newTreasuryGuardian;
        treasuryAddress = newTreasuryAddress;
        treasuryPercent = newTreasuryPercent;
        emit NewTreasuryGuardian(oldTreasuryGuardian, newTreasuryGuardian);
        emit NewTreasuryAddress(oldTreasuryAddress, newTreasuryAddress);
        emit NewTreasuryPercent(oldTreasuryPercent, newTreasuryPercent);
        return uint(Error.NO_ERROR);
    }
    function _become(Unitroller unitroller) public {
        require(msg.sender == unitroller.admin(), "only unitroller admin can");
        require(unitroller._acceptImplementation() == 0, "not authorized");
    }
    function adminOrInitializing() internal view returns (bool) {
        return msg.sender == admin || msg.sender == comptrollerImplementation;
    }
    function setWelSpeedInternal(WLToken wlToken, uint welSpeed) internal {
        uint currentWelSpeed = welSpeeds[address(wlToken)];
        if (currentWelSpeed != 0) {
            // note that WEL speed could be set to 0 to halt liquidity rewards for a market
            Exp memory borrowIndex = Exp({mantissa: wlToken.borrowIndex()});
            updateWelSupplyIndex(address(wlToken));
            updateWelBorrowIndex(address(wlToken), borrowIndex);
        } else if (welSpeed != 0) {
            // Add the WEL market
            Market storage market = markets[address(wlToken)];
            require(market.isListed == true, "wel market is not listed");
            if (welSupplyState[address(wlToken)].index == 0 && welSupplyState[address(wlToken)].block == 0) {
                welSupplyState[address(wlToken)] = WelMarketState({
                    index: welInitialIndex,
                    block: safe32(getBlockNumber(), "block number exceeds 32 bits")
                });
            }
        if (welBorrowState[address(wlToken)].index == 0 && welBorrowState[address(wlToken)].block == 0) {
                welBorrowState[address(wlToken)] = WelMarketState({
                    index: welInitialIndex,
                    block: safe32(getBlockNumber(), "block number exceeds 32 bits")
                });
            }
        }
        if (currentWelSpeed != welSpeed) {
            welSpeeds[address(wlToken)] = welSpeed;
            emit WelSpeedUpdated(wlToken, welSpeed);
        }
    }
    function updateWelSupplyIndex(address wlToken) internal {
        WelMarketState storage supplyState = welSupplyState[wlToken];
        uint supplySpeed = welSpeeds[wlToken];
        uint blockNumber = getBlockNumber();
        uint deltaBlocks = sub_(blockNumber, uint(supplyState.block));
        if (deltaBlocks > 0 && supplySpeed > 0) {
            uint supplyTokens = WLToken(wlToken).totalSupply();
            uint welAccrued = mul_(deltaBlocks, supplySpeed);
            Double memory ratio = supplyTokens > 0 ? fraction(welAccrued, supplyTokens) : Double({mantissa: 0});
            Double memory index = add_(Double({mantissa: supplyState.index}), ratio);
            welSupplyState[wlToken] = WelMarketState({
                index: safe224(index.mantissa, "new index overflows"),
                block: safe32(blockNumber, "block number overflows")
            });
        } else if (deltaBlocks > 0) {
            supplyState.block = safe32(blockNumber, "block number overflows");
        }
    }
    function updateWelBorrowIndex(address wlToken, Exp memory marketBorrowIndex) internal {
        WelMarketState storage borrowState = welBorrowState[wlToken];
        uint borrowSpeed = welSpeeds[wlToken];
        uint blockNumber = getBlockNumber();
        uint deltaBlocks = sub_(blockNumber, uint(borrowState.block));
        if (deltaBlocks > 0 && borrowSpeed > 0) {
            uint borrowAmount = div_(WLToken(wlToken).totalBorrows(), marketBorrowIndex);
            uint welAccrued = mul_(deltaBlocks, borrowSpeed);
            Double memory ratio = borrowAmount > 0 ? fraction(welAccrued, borrowAmount) : Double({mantissa: 0});
            Double memory index = add_(Double({mantissa: borrowState.index}), ratio);
            welBorrowState[wlToken] = WelMarketState({
                index: safe224(index.mantissa, "new index overflows"),
                block: safe32(blockNumber, "block number overflows")
            });
        } else if (deltaBlocks > 0) {
            borrowState.block = safe32(blockNumber, "block number overflows");
        }
    }

    function distributeSupplierWel(address wlToken, address supplier) internal {
        WelMarketState storage supplyState = welSupplyState[wlToken];
        Double memory supplyIndex = Double({mantissa: supplyState.index});
        Double memory supplierIndex = Double({mantissa: welSupplierIndex[wlToken][supplier]});
        welSupplierIndex[wlToken][supplier] = supplyIndex.mantissa;
        if (supplierIndex.mantissa == 0 && supplyIndex.mantissa > 0) {
            supplierIndex.mantissa = welInitialIndex;
        }
        Double memory deltaIndex = sub_(supplyIndex, supplierIndex);
        uint supplierTokens = WLToken(wlToken).balanceOf(supplier);
        uint supplierDelta = mul_(supplierTokens, deltaIndex);
        uint supplierAccrued = add_(welAccrued[supplier], supplierDelta);
        welAccrued[supplier] = supplierAccrued;
        emit DistributedSupplierWel(WLToken(wlToken), supplier, supplierDelta, supplyIndex.mantissa);
    }

    function distributeBorrowerWel(address wlToken, address borrower, Exp memory marketBorrowIndex) internal {
        WelMarketState storage borrowState = welBorrowState[wlToken];
        Double memory borrowIndex = Double({mantissa: borrowState.index});
        Double memory borrowerIndex = Double({mantissa: welBorrowerIndex[wlToken][borrower]});
        welBorrowerIndex[wlToken][borrower] = borrowIndex.mantissa;
        if (borrowerIndex.mantissa > 0) {
            Double memory deltaIndex = sub_(borrowIndex, borrowerIndex);
            uint borrowerAmount = div_(WLToken(wlToken).borrowBalanceStored(borrower), marketBorrowIndex);
            uint borrowerDelta = mul_(borrowerAmount, deltaIndex);
            uint borrowerAccrued = add_(welAccrued[borrower], borrowerDelta);
            welAccrued[borrower] = borrowerAccrued;
            emit DistributedBorrowerWel(WLToken(wlToken), borrower, borrowerDelta, borrowIndex.mantissa);
        }
    }
    function claimWel(address holder) public {
        return claimWel(holder, allMarkets);
    }
    function claimWel(address holder, WLToken[] memory wlTokens) public {
        address[] memory holders = new address[](1);
        holders[0] = holder;
        claimWel(holders, wlTokens, true, true);
    }
    function claimWel(address[] memory holders, WLToken[] memory wlTokens, bool borrowers, bool suppliers) public {
        uint j;
        for (j = 0; j < holders.length; j++) {
            welAccrued[holders[j]] = grantWELInternal(holders[j], welAccrued[holders[j]]);
        }
        for (uint i = 0; i < wlTokens.length; i++) {
            WLToken wlToken = wlTokens[i];
            require(markets[address(wlToken)].isListed, "not listed market");
            if (borrowers) {
                Exp memory borrowIndex = Exp({mantissa: wlToken.borrowIndex()});
                updateWelBorrowIndex(address(wlToken), borrowIndex);
                for (j = 0; j < holders.length; j++) {
                    distributeBorrowerWel(address(wlToken), holders[j], borrowIndex);
                    welAccrued[holders[j]] = grantWELInternal(holders[j], welAccrued[holders[j]]);
                }
            }
            if (suppliers) {
                updateWelSupplyIndex(address(wlToken));
                for (j = 0; j < holders.length; j++) {
                    distributeSupplierWel(address(wlToken), holders[j]);
                    welAccrued[holders[j]] = grantWELInternal(holders[j], welAccrued[holders[j]]);
                }
            }
        }
    }
    function grantWELInternal(address user, uint amount) internal returns (uint) {
        WEL wel = WEL(getWelAddress());
        uint welRemaining = wel.balanceOf(address(this));
        if (amount > 0 && amount <= welRemaining) {
            wel.transfer(user, amount);
            return 0;
        }
        return amount;
    }
    /*** Wel Distribution Admin ***/
    function _setWelSpeed(WLToken wlToken, uint welSpeed) public {
        require(adminOrInitializing(), "only admin can set wel speed");
        setWelSpeedInternal(wlToken, welSpeed);
    }
    function getAllMarkets() public view returns (WLToken[] memory) {
        return allMarkets;
    }
    function getBlockNumber() public view returns (uint) {
        return block.number;
    }
    function getWelAddress() public view returns (address) {
        // WEL
        return 0xFaCb71312B1e928a33a65B2657423415Cd15Ab15;
    }
}
