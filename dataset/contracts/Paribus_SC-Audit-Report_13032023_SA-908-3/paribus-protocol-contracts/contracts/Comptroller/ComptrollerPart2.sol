// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.5.17;

import "../PriceOracle/PriceOracleInterface.sol";
import "../Interfaces/EIP20Interface.sol";
import "./ComptrollerCommonImpl.sol";

/**
 * @title Compound's Comptroller Part2 Contract
 * @author Compound, Paribus
 */
contract ComptrollerPart2 is ComptrollerPart2Interface, ComptrollerCommonImpl {
    /*** Assets You Are In ***/

    /**
     * @notice Add assets to be included in account liquidity calculation
     * @param pTokens The list of addresses of the pToken markets to be enabled
     * @return Success indicator for whether each corresponding market was entered
     */
    function enterMarkets(address[] calldata pTokens) external returns (uint[] memory) {
        uint len = pTokens.length;

        uint[] memory results = new uint[](len);
        for (uint i = 0; i < len; i++) {
            PToken pToken = PToken(pTokens[i]);
            results[i] = uint(addToMarketInternal(pToken, msg.sender));
        }

        return results;
    }

    /**
     * @notice Removes asset from sender's account liquidity calculation
     * @dev Sender must not have an outstanding borrow balance in the asset,
     *  or be providing necessary collateral for an outstanding borrow.
     * @param pTokenAddress The address of the asset to be removed
     * @return Whether or not the account successfully exited the market
     */
    function exitMarket(address pTokenAddress) external returns (uint) {
        PToken pToken = PToken(pTokenAddress);
        require(pToken.isPToken(), "incorrect asset");

        /* Get sender tokensHeld and amountOwed underlying from the pToken */
        (uint tokensHeld, uint borrowBalance, ) = pToken.getAccountSnapshot(msg.sender);

        /* Fail if the sender has a borrow balance */
        if (borrowBalance != 0) {
            return fail(Error.NONZERO_BORROW_BALANCE, FailureInfo.EXIT_MARKET_BALANCE_OWED);
        }

        /* Fail if the sender is not permitted to redeem all of their tokens */
        uint allowed = redeemAllowedInternal(pTokenAddress, msg.sender, tokensHeld);
        if (allowed != 0) {
            return failOpaque(Error.REJECTION, FailureInfo.EXIT_MARKET_REJECTION, allowed);
        }

        Market storage marketToExit = markets[address(pToken)];

        /* Return true if the sender is not already ‘in’ the market */
        if (!marketToExit.accountMembership[msg.sender]) {
            return uint(Error.NO_ERROR);
        }

        /* Set pToken account membership to false */
        delete marketToExit.accountMembership[msg.sender];

        /* Delete pToken from the account’s list of assets */
        // load into memory for faster iteration
        PToken[] memory userAssetList = accountAssets[msg.sender];
        uint len = userAssetList.length;
        uint assetIndex = len;
        for (uint i = 0; i < len; i++) {
            if (userAssetList[i] == pToken) {
                assetIndex = i;
                break;
            }
        }

        // We *must* have found the asset in the list or our redundant data structure is broken
        assert(assetIndex < len);

        // copy last item in list to location of item to be removed, reduce length by 1
        PToken[] storage storedList = accountAssets[msg.sender];
        storedList[assetIndex] = storedList[storedList.length - 1];
        storedList.length--;

        emit MarketExited(address(pToken), msg.sender);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Add the market to the borrower's "assets in" for liquidity calculations
     * @param pToken The market to enter
     * @param borrower The address of the account to modify
     * @return Success indicator for whether the market was entered
     */
    function addToMarketInternal(PToken pToken, address borrower) internal returns (Error) {
        require(pToken.isPToken(), "incorrect asset");
        Market storage marketToJoin = markets[address(pToken)];

        if (!marketToJoin.isListed) { // market is not listed, cannot join
            return Error.MARKET_NOT_LISTED;
        }

        if (marketToJoin.accountMembership[borrower]) { // already joined
            return Error.NO_ERROR;
        }

        // survived the gauntlet, add to list
        // NOTE: we store these somewhat redundantly as a significant optimization
        //  this avoids having to iterate through the list for the most common use cases
        //  that is, only when we need to perform liquidity checks
        //  and not whenever we want to check if an account is in a particular market
        marketToJoin.accountMembership[borrower] = true;
        accountAssets[borrower].push(pToken);

        emit MarketEntered(address(pToken), borrower);
        return Error.NO_ERROR;
    }

    /*** Liquidity/Liquidation Calculations ***/

    /**
     * @dev Local vars for avoiding stack-depth limits in calculating account liquidity.
     *  Note that `pTokenBalance` is the number of pTokens the account owns in the market,
     *  whereas `borrowBalance` is the amount of underlying that the account has borrowed.
     */
    struct AccountLiquidityLocalVars {
        uint sumCollateral;
        uint sumBorrowPlusEffects;
        uint pTokenBalance;
        uint borrowBalance;
        uint exchangeRateMantissa;
        uint oraclePriceMantissa;
        Exp collateralFactor;
        Exp exchangeRate;
        Exp oraclePrice;
        Exp tokensToDenom;
    }

    /**
     * @notice Determine the current account liquidity wrt collateral requirements
     * @return (possible error code (semi-opaque),
                account liquidity in excess of collateral requirements,
     *          account shortfall below collateral requirements)
     */
    function getAccountLiquidity(address account) external view returns (uint, uint, uint) {
        return getHypotheticalAccountLiquidityInternal(account, address(0), 0, 0, 0);
    }

    /**
    * @return (standard assets collateral worth sum including collateral factor,
    *          0,
    *          borrow value)
    */
    function getCollateralBorrowValues(address account) external view returns (uint, uint, uint) {
        AccountLiquidityLocalVars memory vars; // Holds all our calculation results

        Error err = getHypotheticalAccountLiquidityInternalImpl(account, address(0), 0, 0, vars);
        require(err == Error.NO_ERROR, "getHypotheticalAccountLiquidity error");

        return (vars.sumCollateral, 0, vars.sumBorrowPlusEffects);
    }

    /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param pTokenModify The market to hypothetically redeem/borrow in
     * @param account The account to determine liquidity for
     * @param redeemTokens The number of tokens to hypothetically redeem (if PToken)
     * @param borrowAmount The amount of underlying to hypothetically borrow (if PToken)
     * @param redeemTokenId Unused, reserved for NFT code
     * @return (possible error code (semi-opaque),
                hypothetical account liquidity in excess of collateral requirements,
     *          hypothetical account shortfall below collateral requirements)
     */
    function getHypotheticalAccountLiquidity(address account, address pTokenModify, uint redeemTokens, uint borrowAmount, uint redeemTokenId) external view returns (uint, uint, uint) {
        return getHypotheticalAccountLiquidityInternal(account, pTokenModify, redeemTokens, borrowAmount, redeemTokenId);
    }

    /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param pTokenModify The market to hypothetically redeem/borrow in
     * @param account The account to determine liquidity for
     * @param redeemTokens The number of tokens to hypothetically redeem
     * @param borrowAmount The amount of underlying to hypothetically borrow
     * @param redeemTokenId Unused, reserved for NFT code
     * @dev Note that we calculate the exchangeRateStored for each collateral pToken using stored data,
     *  without calculating accumulated interest.
     * @return (possible error code,
                hypothetical account liquidity in excess of collateral requirements,
     *          hypothetical account shortfall below collateral requirements)
     */
    function getHypotheticalAccountLiquidityInternal(address account, address pTokenModify, uint redeemTokens, uint borrowAmount, uint redeemTokenId) internal view returns (uint, uint, uint) {
        AccountLiquidityLocalVars memory vars; // Holds all our calculation results

        Error err = getHypotheticalAccountLiquidityInternalImpl(account, pTokenModify, redeemTokens, borrowAmount, vars);
        if (err != Error.NO_ERROR) return (uint(err), 0, 0);

        // These are safe, as the underflow condition is checked first
        if (vars.sumCollateral > vars.sumBorrowPlusEffects) {
            return (uint(Error.NO_ERROR), sub_(vars.sumCollateral, vars.sumBorrowPlusEffects), 0);
        } else {
            return (uint(Error.NO_ERROR), 0, sub_(vars.sumBorrowPlusEffects, vars.sumCollateral));
        }
    }

    /**
    * @dev returns liquidity for standard assets (by vars param)
    */
    function getHypotheticalAccountLiquidityInternalImpl(address account, address pTokenModify, uint redeemTokens, uint borrowAmount, AccountLiquidityLocalVars memory vars) internal view returns (Error) {
        // For each asset the account is in
        PToken[] memory assets = accountAssets[account];
        for (uint i = 0; i < assets.length; i++) {
            PToken asset = assets[i];

            // Read the balances and exchange rate from the pToken
            (vars.pTokenBalance, vars.borrowBalance, vars.exchangeRateMantissa) = asset.getAccountSnapshot(account);
            vars.collateralFactor = Exp({mantissa : markets[address(asset)].collateralFactorMantissa});
            vars.exchangeRate = Exp({mantissa : vars.exchangeRateMantissa});

            // Get the normalized price of the asset
            vars.oraclePriceMantissa = oracle.getUnderlyingPrice(asset);
            if (vars.oraclePriceMantissa == 0) {
                return Error.PRICE_ERROR;
            }
            vars.oraclePrice = Exp({mantissa : vars.oraclePriceMantissa});

            // Pre-compute a conversion factor from tokens -> ether (normalized price value)
            vars.tokensToDenom = mul_(mul_(vars.collateralFactor, vars.exchangeRate), vars.oraclePrice);

            // sumCollateral += tokensToDenom * pTokenBalance
            vars.sumCollateral = mul_ScalarTruncateAddUInt(vars.tokensToDenom, vars.pTokenBalance, vars.sumCollateral);

            // sumBorrowPlusEffects += oraclePrice * borrowBalance
            vars.sumBorrowPlusEffects = mul_ScalarTruncateAddUInt(vars.oraclePrice, vars.borrowBalance, vars.sumBorrowPlusEffects);

            // Calculate effects of interacting with pTokenModify
            if (address(asset) == pTokenModify) {
                // redeem effect
                // sumBorrowPlusEffects += tokensToDenom * redeemTokens
                vars.sumBorrowPlusEffects = mul_ScalarTruncateAddUInt(vars.tokensToDenom, redeemTokens, vars.sumBorrowPlusEffects);

                // borrow effect
                // sumBorrowPlusEffects += oraclePrice * borrowAmount
                vars.sumBorrowPlusEffects = mul_ScalarTruncateAddUInt(vars.oraclePrice, borrowAmount, vars.sumBorrowPlusEffects);
            }
        }

        return Error.NO_ERROR;
    }

    /**
     * @notice Calculate number of tokens of collateral asset to seize given an underlying amount
     * @dev Used in liquidation (called in pToken.liquidateBorrowFresh)
     * @param pTokenBorrowed The address of the borrowed pToken
     * @param pTokenCollateral The address of the collateral pToken
     * @param actualRepayAmount The amount of pTokenBorrowed underlying to convert into pTokenCollateral tokens
     * @return (errorCode, number of pTokenCollateral tokens to be seized in a liquidation)
     */
    function liquidateCalculateSeizeTokens(address pTokenBorrowed, address pTokenCollateral, uint actualRepayAmount) external view returns (uint, uint) {
        require(PToken(pTokenBorrowed).isPToken(), "incorrect asset");
        require(PToken(pTokenCollateral).isPToken(), "incorrect asset");

        /* Read oracle prices for borrowed and collateral markets */
        uint priceBorrowedMantissa = oracle.getUnderlyingPrice(PToken(pTokenBorrowed));
        uint priceCollateralMantissa = oracle.getUnderlyingPrice(PToken(pTokenCollateral));
        if (priceBorrowedMantissa == 0 || priceCollateralMantissa == 0) {
            return (uint(Error.PRICE_ERROR), 0);
        }

        /*
         * Get the exchange rate and calculate the number of collateral tokens to seize:
         *  seizeAmount = actualRepayAmount * liquidationIncentive * priceBorrowed / priceCollateral
         *  seizeTokens = seizeAmount / exchangeRate
         *   = actualRepayAmount * (liquidationIncentive * priceBorrowed) / (priceCollateral * exchangeRate)
         */
        uint exchangeRateMantissa = PToken(pTokenCollateral).exchangeRateStored();
        // Note: reverts on error
        Exp memory numerator = mul_(Exp({mantissa : liquidationIncentiveMantissa}), Exp({mantissa : priceBorrowedMantissa}));
        Exp memory denominator = mul_(Exp({mantissa : priceCollateralMantissa}), Exp({mantissa : exchangeRateMantissa}));
        Exp memory ratio = div_(numerator, denominator);
        uint seizeTokens = mul_ScalarTruncate(ratio, actualRepayAmount);

        return (uint(Error.NO_ERROR), seizeTokens);
    }

    /*** Policy Hooks, should not be marked as pure, view ***/

    /**
     * @notice Checks if the liquidation should be allowed to occur
     * @param pTokenBorrowed Asset which was borrowed by the borrower
     * @param pTokenCollateral Asset which was used as collateral and will be seized
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param repayAmount The amount of underlying being repaid
     */
    function liquidateBorrowAllowed(address pTokenBorrowed, address pTokenCollateral, address liquidator, address borrower, uint repayAmount) external returns (uint) {
        require(PToken(pTokenBorrowed).isPToken(), "incorrect asset");

        liquidator; // Shh - currently unused

        if (!markets[pTokenBorrowed].isListed || !markets[pTokenCollateral].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        /* The borrower must have shortfall in order to be liquidatable */
        (uint err, , uint shortfall) = getHypotheticalAccountLiquidityInternal(borrower, address(0), 0, 0, 0);
        if (err != uint(Error.NO_ERROR)) {
            return uint(err);
        }
        if (shortfall == 0) {
            return uint(Error.INSUFFICIENT_SHORTFALL);
        }

        /* The liquidator may not repay more than what is allowed by the closeFactor */
        uint borrowBalance = PToken(pTokenBorrowed).borrowBalanceStored(borrower);
        uint maxClose = mul_ScalarTruncate(Exp({mantissa : closeFactorMantissa}), borrowBalance);
        if (repayAmount > maxClose) {
            return uint(Error.TOO_MUCH_REPAY);
        }

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the account should be allowed to redeem tokens in the given market
     * @param pToken The market to verify the redeem against
     * @param redeemer The account which would redeem the tokens
     * @param redeemTokens The number of pTokens to exchange for the underlying asset in the market
     * @return 0 if the redeem is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function redeemAllowed(address pToken, address redeemer, uint redeemTokens) external returns (uint) {
        require(PToken(pToken).isPToken(), "incorrect asset");

        uint allowed = redeemAllowedInternal(pToken, redeemer, redeemTokens);
        if (allowed != uint(Error.NO_ERROR)) {
            return allowed;
        }

        // Keep the flywheel moving
        updatePBXSupplyIndex(pToken);
        distributeSupplierPBX(pToken, redeemer);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the account should be allowed to borrow the underlying asset of the given market
     * @param pToken The market to verify the borrow against
     * @param borrower The account which would borrow the asset
     * @param borrowAmount The amount of underlying the account would borrow
     * @return 0 if the borrow is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function borrowAllowed(address pToken, address borrower, uint borrowAmount) external returns (uint) {
        require(PToken(pToken).isPToken(), "incorrect asset");

        // Pausing is a very serious situation - we revert to sound the alarms
        require(!borrowGuardianPaused[pToken] && !borrowGuardianPausedGlobal, "borrow is paused");

        if (!markets[pToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        if (!markets[pToken].accountMembership[borrower]) {
            // only pTokens may call borrowAllowed if borrower not in market
            require(msg.sender == pToken, "sender must be pToken");

            // attempt to add borrower to the market
            Error err = addToMarketInternal(PToken(msg.sender), borrower);
            if (err != Error.NO_ERROR) {
                return uint(err);
            }

            // it should be impossible to break the important invariant
            assert(markets[pToken].accountMembership[borrower]);
        }

        if (oracle.getUnderlyingPrice(PToken(pToken)) == 0) {
            return uint(Error.PRICE_ERROR);
        }


        uint borrowCap = borrowCaps[pToken];
        // Borrow cap of 0 corresponds to unlimited borrowing
        if (borrowCap != 0) {
            uint totalBorrows = PToken(pToken).totalBorrows();
            uint nextTotalBorrows = add_(totalBorrows, borrowAmount);
            require(nextTotalBorrows < borrowCap, "market borrow cap reached");
        }

        (uint err, , uint shortfall) = getHypotheticalAccountLiquidityInternal(borrower, pToken, 0, borrowAmount, 0);
        if (err != uint(Error.NO_ERROR)) {
            return uint(err);
        }
        if (shortfall > 0) {
            return uint(Error.INSUFFICIENT_LIQUIDITY);
        }

        // Keep the flywheel moving
        Exp memory borrowIndex = Exp({mantissa : PToken(pToken).borrowIndex()});
        updatePBXBorrowIndex(pToken, borrowIndex);
        distributeBorrowerPBX(pToken, borrower, borrowIndex);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the account should be allowed to transfer tokens in the given market
     * @param pToken The market to verify the transfer against
     * @param src The account which sources the tokens
     * @param dst The account which receives the tokens
     * @param transferTokens The number of pTokens to transfer
     * @return 0 if the transfer is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function transferAllowed(address pToken, address src, address dst, uint transferTokens) external returns (uint) {
        require(PToken(pToken).isPToken(), "incorrect asset");

        // Pausing is a very serious situation - we revert to sound the alarms
        require(!transferGuardianPausedGlobal, "transfer is paused");

        // Currently the only consideration is whether or not
        //  the src is allowed to redeem this many tokens
        uint allowed = redeemAllowedInternal(pToken, src, transferTokens);
        if (allowed != uint(Error.NO_ERROR)) {
            return allowed;
        }

        // Keep the flywheel moving
        updatePBXSupplyIndex(pToken);
        distributeSupplierPBX(pToken, src);
        distributeSupplierPBX(pToken, dst);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the account should be allowed to mint tokens in the given market
     * @param pToken The market to verify the mint against
     * @param minter The account which would get the minted tokens
     * @param mintAmount The amount of underlying being supplied to the market in exchange for tokens
     * @return 0 if the mint is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function mintAllowed(address pToken, address minter, uint mintAmount) external returns (uint) {
        require(PToken(pToken).isPToken(), "incorrect asset");

        // Pausing is a very serious situation - we revert to sound the alarms
        require(!mintGuardianPaused[pToken] && !mintGuardianPausedGlobal, "mint is paused");

        // Shh - currently unused
        minter;
        mintAmount;

        if (!markets[pToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        // Keep the flywheel moving
        updatePBXSupplyIndex(pToken);
        distributeSupplierPBX(pToken, minter);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the account should be allowed to repay a borrow in the given market
     * @param pToken The market to verify the repay against
     * @param payer The account which would repay the asset
     * @param borrower The account which would borrowed the asset
     * @param repayAmount The amount of the underlying asset the account would repay
     * @return 0 if the repay is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function repayBorrowAllowed(address pToken, address payer, address borrower, uint repayAmount) external returns (uint) {
        require(PToken(pToken).isPToken(), "incorrect asset");

        // Shh - currently unused
        payer;
        borrower;
        repayAmount;

        if (!markets[pToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        // Keep the flywheel moving
        Exp memory borrowIndex = Exp({mantissa : PToken(pToken).borrowIndex()});
        updatePBXBorrowIndex(pToken, borrowIndex);
        distributeBorrowerPBX(pToken, borrower, borrowIndex);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the seizing of assets should be allowed to occur
     * @param pTokenCollateral Asset which was used as collateral and will be seized
     * @param pTokenBorrowed Asset which was borrowed by the borrower
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param seizeTokens The number of collateral tokens to seize
     */
    function seizeAllowed(address pTokenCollateral, address pTokenBorrowed, address liquidator, address borrower, uint seizeTokens) external returns (uint) {
        require(PToken(pTokenCollateral).isPToken(), "incorrect asset");
        require(PToken(pTokenBorrowed).isPToken(), "incorrect asset");

        // Pausing is a very serious situation - we revert to sound the alarms
        require(!seizeGuardianPausedGlobal, "seize is paused");

        seizeTokens; // Shh - currently unused

        if (!markets[pTokenCollateral].isListed || !markets[pTokenBorrowed].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        if (PToken(pTokenCollateral).comptroller() != PToken(pTokenBorrowed).comptroller()) {
            return uint(Error.COMPTROLLER_MISMATCH);
        }

        // Keep the flywheel moving
        updatePBXSupplyIndex(pTokenCollateral);
        distributeSupplierPBX(pTokenCollateral, borrower);
        distributeSupplierPBX(pTokenCollateral, liquidator);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Checks if the account should be allowed to redeem tokens in the given market. Integral part of the redeemAllowed() function.
     * @param pToken The market to verify the redeem against=
     * @param redeemer The account which would redeem the tokens
     * @param redeemTokens The number of pTokens to exchange for the underlying asset in the market
     * @return 0 if the redeem is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function redeemAllowedInternal(address pToken, address redeemer, uint redeemTokens) internal view returns (uint) {
        require(PToken(pToken).isPToken(), "incorrect asset");

        if (!markets[pToken].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        /* If the redeemer is not 'in' the market, then we can bypass the liquidity check */
        if (markets[pToken].accountMembership[redeemer]) {
            /* Otherwise, perform a hypothetical liquidity check to guard against shortfall */
            (uint err, , uint shortfall) = getHypotheticalAccountLiquidityInternal(redeemer, pToken, redeemTokens, 0, 0);
            if (err != uint(Error.NO_ERROR)) {
                return uint(err);
            }
            if (shortfall > 0) {
                return uint(Error.INSUFFICIENT_LIQUIDITY);
            }
        }

        return uint(Error.NO_ERROR);
    }

    /*** PBX Distribution ***/

    /**
     * @notice Calculate additional accrued PBX for a contributor since last accrual
     * @param contributor The address to calculate contributor rewards for
     */
    function updateContributorRewards(address contributor) public {
        uint PBXSpeed = PBXContributorSpeeds[contributor];
        uint blockNumber = getBlockNumber();
        uint deltaBlocks = sub_(blockNumber, lastContributorBlock[contributor]);
        if (deltaBlocks > 0 && PBXSpeed > 0) {
            uint newAccrued = mul_(deltaBlocks, PBXSpeed);
            uint contributorAccrued = add_(PBXAccrued[contributor], newAccrued);

            PBXAccrued[contributor] = contributorAccrued;
            lastContributorBlock[contributor] = blockNumber;
        }
    }

    /**
    * @notice Claim all the PBX accrued by holder in all markets
    * @param holder The address to claim PBX for
    */
    function claimPBXReward(address holder) external {
        return claimPBXSingle(holder, allMarkets);
    }

    /**
     * @notice Claim all the PBX accrued by holder in the specified markets
     * @param holder The address to claim PBX for
     * @param pTokens The list of markets to claim PBX in
     */
    function claimPBXSingle(address holder, PToken[] memory pTokens) public {
        address[] memory holders = new address[](1);
        holders[0] = holder;
        claimPBX(holders, pTokens, true, true);
    }

    /**
     * @notice Claim all PBX accrued by the holders
     * @param holders The addresses to claim PBX for
     * @param pTokens The list of markets to claim PBX in
     * @param borrowers Whether or not to claim PBX earned by borrowing
     * @param suppliers Whether or not to claim PBX earned by supplying
     */
    function claimPBX(address[] memory holders, PToken[] memory pTokens, bool borrowers, bool suppliers) public {
        for (uint i = 0; i < pTokens.length; i++) {
            PToken pToken = pTokens[i];
            require(pToken.isPToken(), "incorrect asset");

            require(markets[address(pToken)].isListed, "market must be listed");
            if (borrowers) {
                Exp memory borrowIndex = Exp({mantissa: pToken.borrowIndex()});
                updatePBXBorrowIndex(address(pToken), borrowIndex);
                for (uint j = 0; j < holders.length; j++) {
                    distributeBorrowerPBX(address(pToken), holders[j], borrowIndex);
                }
            }
            if (suppliers) {
                updatePBXSupplyIndex(address(pToken));
                for (uint j = 0; j < holders.length; j++) {
                    distributeSupplierPBX(address(pToken), holders[j]);
                }
            }
        }
        for (uint j = 0; j < holders.length; j++) {
            PBXAccrued[holders[j]] = grantPBXInternal(holders[j], PBXAccrued[holders[j]]);
        }
    }

    /**
     * @notice Transfer PBX to the user
     * @dev Note: If there is not enough PBX, we do not perform the transfer all.
     * @param user The address of the user to transfer PBX to
     * @param amount The amount of PBX to (possibly) transfer
     * @return The amount of PBX which was NOT transferred to the user
     */
    function grantPBXInternal(address user, uint amount) internal returns (uint) {
        EIP20Interface PBX = EIP20Interface(PBXToken);
        uint PBXRemaining = PBX.balanceOf(address(this));
        if (amount > 0 && amount <= PBXRemaining) {
            PBX.transfer(user, amount);
            return 0;
        }
        return amount;
    }

    /*** PBX Distribution Admin ***/

    /**
     * @notice Set PBX speed for a single market
     * @param pToken The market whose PBX speed to update
     * @param supplySpeed New supply-side PBX speed for market
     * @param borrowSpeed New borrow-side PBX speed for market
     */
    function setPBXSpeedInternal(PToken pToken, uint supplySpeed, uint borrowSpeed) internal {
        Market storage market = markets[address(pToken)];
        require(market.isListed, "market is not listed");

        if (PBXSupplySpeeds[address(pToken)] != supplySpeed) {
            // Supply speed updated so let's update supply state to ensure that
            //  1. PBX accrued properly for the old speed, and
            //  2. PBX accrued at the new speed starts after this block.
            updatePBXSupplyIndex(address(pToken));

            // Update speed and emit event
            PBXSupplySpeeds[address(pToken)] = supplySpeed;
            emit PBXSupplySpeedUpdated(pToken, supplySpeed);
        }

        if (PBXBorrowSpeeds[address(pToken)] != borrowSpeed) {
            // Borrow speed updated so let's update borrow state to ensure that
            //  1. PBX accrued properly for the old speed, and
            //  2. PBX accrued at the new speed starts after this block.
            Exp memory borrowIndex = Exp({mantissa: pToken.borrowIndex()});
            updatePBXBorrowIndex(address(pToken), borrowIndex);

            // Update speed and emit event
            PBXBorrowSpeeds[address(pToken)] = borrowSpeed;
            emit PBXBorrowSpeedUpdated(pToken, borrowSpeed);
        }
    }

    /**
     * @notice Transfer PBX to the recipient
     * @dev Note: If there is not enough PBX, we do not perform the transfer all.
     * @param recipient The address of the recipient to transfer PBX to
     * @param amount The amount of PBX to (possibly) transfer
     */
    function _grantPBX(address recipient, uint amount) external {
        adminOrInitializing();

        uint amountLeft = grantPBXInternal(recipient, amount);
        require(amountLeft == 0, "insufficient PBX for grant");
        emit PBXGranted(recipient, amount);
    }

    /**
     * @notice Set PBX borrow and supply speeds for the specified markets.
     * @param pTokens The market whose PBX speed to update
     * @param supplySpeeds New supply-side PBX speed for the corresponding market.
     * @param borrowSpeeds New borrow-side PBX speed for the corresponding market.
     */
    function _setPBXSpeeds(PToken[] calldata pTokens, uint[] calldata supplySpeeds, uint[] calldata borrowSpeeds) external {
        adminOrInitializing();

        uint numTokens = pTokens.length;
        require(numTokens == supplySpeeds.length && numTokens == borrowSpeeds.length, "invalid argument");

        for (uint i = 0; i < numTokens; ++i) {
            setPBXSpeedInternal(pTokens[i], supplySpeeds[i], borrowSpeeds[i]);
        }
    }

    /**
     * @notice Set PBX speed for a single contributor
     * @param contributor The contributor whose PBX speed to update
     * @param PBXSpeed New PBX speed for contributor
     */
    function _setContributorPBXSpeed(address contributor, uint PBXSpeed) external {
        adminOrInitializing();

        // note that PBX speed could be set to 0 to halt liquidity rewards for a contributor
        updateContributorRewards(contributor);
        if (PBXSpeed == 0) {
            // release storage
            delete lastContributorBlock[contributor];
        } else {
            lastContributorBlock[contributor] = getBlockNumber();
        }
        PBXContributorSpeeds[contributor] = PBXSpeed;

        emit ContributorPBXSpeedUpdated(contributor, PBXSpeed);
    }

    /**
     * @notice Accrue PBX to the market by updating the supply index
     * @param pToken The market whose supply index to update
     * @dev Index is a cumulative sum of the PBX per pToken accrued
     */
    function updatePBXSupplyIndex(address pToken) internal {
        PBXMarketState storage supplyState = PBXSupplyState[pToken];
        uint supplySpeed = PBXSupplySpeeds[pToken];
        uint32 blockNumber = safe32(getBlockNumber(), "block number exceeds 32 bits");
        uint deltaBlocks = sub_(uint(blockNumber), uint(supplyState.block));
        if (deltaBlocks > 0 && supplySpeed > 0) {
            uint totalSupply = PToken(pToken).totalSupply();
            uint supplyTokens = totalSupply > 0 ? sub_(totalSupply, PToken(pToken).MINIMUM_LIQUIDITY()) : 0;
            uint newPBXAccrued = mul_(deltaBlocks, supplySpeed);
            Double memory ratio = supplyTokens > 0 ? fraction(newPBXAccrued, supplyTokens) : Double({mantissa : 0});
            supplyState.index = safe224(add_(Double({mantissa : supplyState.index}), ratio).mantissa, "new index exceeds 224 bits");
            supplyState.block = blockNumber;
        } else if (deltaBlocks > 0) {
            supplyState.block = blockNumber;
        }
    }

    /**
     * @notice Calculate PBX accrued by a supplier and possibly transfer it to them
     * @param pToken The market in which the supplier is interacting
     * @param supplier The address of the supplier to distribute PBX to
     */
    function distributeSupplierPBX(address pToken, address supplier) internal {
        PBXMarketState storage supplyState = PBXSupplyState[pToken];
        uint supplyIndex = supplyState.index;
        uint supplierIndex = PBXSupplierIndex[pToken][supplier];

        // Update supplier's index to the current index since we are distributing accrued PBX
        PBXSupplierIndex[pToken][supplier] = supplyIndex;

        if (supplierIndex == 0 && supplyIndex >= PBXInitialIndex) {
            // Covers the case where users supplied tokens before the market's supply state index was set.
            // Rewards the user with PBX accrued from the start of when supplier rewards were first
            // set for the market.
            supplierIndex = PBXInitialIndex;
        }

        // Calculate change in the cumulative sum of the PBX per pToken accrued
        Double memory deltaIndex = Double({mantissa : sub_(supplyIndex, supplierIndex)});

        uint supplierTokens = PToken(pToken).balanceOf(supplier);

        // Calculate PBX accrued: pTokenAmount * accruedPerPToken
        uint supplierDelta = mul_(supplierTokens, deltaIndex);

        uint supplierAccrued = add_(PBXAccrued[supplier], supplierDelta);
        PBXAccrued[supplier] = supplierAccrued;

        emit DistributedSupplierPBX(PToken(pToken), supplier, supplierDelta, supplyIndex);
    }

    /**
     * @notice Accrue PBX to the market by updating the borrow index
     * @param pToken The market whose borrow index to update
     * @dev Index is a cumulative sum of the PBX per pToken accrued.
     */
    function updatePBXBorrowIndex(address pToken, Exp memory marketBorrowIndex) internal {
        require(PToken(pToken).isPToken(), "incorrect asset");

        PBXMarketState storage borrowState = PBXBorrowState[pToken];
        uint borrowSpeed = PBXBorrowSpeeds[pToken];
        uint32 blockNumber = safe32(getBlockNumber(), "block number exceeds 32 bits");
        uint deltaBlocks = sub_(uint(blockNumber), uint(borrowState.block));
        if (deltaBlocks > 0 && borrowSpeed > 0) {
            uint borrowAmount = div_(PToken(pToken).totalBorrows(), marketBorrowIndex);
            uint newPBXAccrued = mul_(deltaBlocks, borrowSpeed);
            Double memory ratio = borrowAmount > 0 ? fraction(newPBXAccrued, borrowAmount) : Double({mantissa: 0});
            borrowState.index = safe224(add_(Double({mantissa: borrowState.index}), ratio).mantissa, "new index exceeds 224 bits");
            borrowState.block = blockNumber;
        } else if (deltaBlocks > 0) {
            borrowState.block = blockNumber;
        }
    }

    /**
    * @notice Calculate PBX accrued by a borrower and possibly transfer it to them
     * @dev Borrowers will not begin to accrue until after the first interaction with the protocol.
     * @param pToken The market in which the borrower is interacting
     * @param borrower The address of the borrower to distribute PBX to
     */
    function distributeBorrowerPBX(address pToken, address borrower, Exp memory marketBorrowIndex) internal {
        require(PToken(pToken).isPToken(), "incorrect asset");

        PBXMarketState storage borrowState = PBXBorrowState[pToken];
        uint borrowIndex = borrowState.index;
        uint borrowerIndex = PBXBorrowerIndex[pToken][borrower];

        // Update borrowers's index to the current index since we are distributing accrued PBX
        PBXBorrowerIndex[pToken][borrower] = borrowIndex;

        if (borrowerIndex == 0 && borrowIndex >= PBXInitialIndex) {
            // Covers the case where users borrowed tokens before the market's borrow state index was set.
            // Rewards the user with PBX accrued from the start of when borrower rewards were first
            // set for the market.
            borrowerIndex = PBXInitialIndex;
        }

        // Calculate change in the cumulative sum of the PBX per borrowed unit accrued
        Double memory deltaIndex = Double({mantissa: sub_(borrowIndex, borrowerIndex)});

        uint borrowerAmount = div_(PToken(pToken).borrowBalanceStored(borrower), marketBorrowIndex);

        // Calculate PBX accrued: pTokenAmount * accruedPerBorrowedUnit
        uint borrowerDelta = mul_(borrowerAmount, deltaIndex);

        uint borrowerAccrued = add_(PBXAccrued[borrower], borrowerDelta);
        PBXAccrued[borrower] = borrowerAccrued;

        emit DistributedBorrowerPBX(PToken(pToken), borrower, borrowerDelta, borrowIndex);
    }
}
