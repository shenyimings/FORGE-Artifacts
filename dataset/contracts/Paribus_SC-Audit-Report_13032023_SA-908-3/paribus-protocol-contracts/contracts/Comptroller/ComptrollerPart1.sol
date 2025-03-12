// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.5.17;

import "../PriceOracle/PriceOracleInterface.sol";
import "../Interfaces/EIP20Interface.sol";
import "./ComptrollerCommonImpl.sol";

/**
 * @title Compound's Comptroller Part1 Contract
 * @author Compound, Paribus
 */
contract ComptrollerPart1 is ComptrollerPart1Interface, ComptrollerCommonImpl {
    /*** Assets You Are In ***/

    /**
     * @notice Returns the assets an account has entered
     * @param account The address of the account to pull assets for
     * @return A dynamic list with the assets the account has entered
     */
    function getAssetsIn(address account) external view returns (PToken[] memory) {
        return accountAssets[account];
    }

    /**
     * @notice Returns whether the given account is entered in the given asset
     * @param account The address of the account to check
     * @param pToken The pToken to check
     * @return True if the account is in the asset, otherwise false.
     */
    function checkMembership(address account, address pToken) external view returns (bool) {
        return markets[pToken].accountMembership[account];
    }

    /**
     * @notice Return all of the markets
     * @dev The automatic getter may be used to access an individual market.
     * @return The list of market addresses
     */
    function getAllMarkets() external view returns (PToken[] memory) {
        return allMarkets;
    }

    /**
     * @notice Returns deposit, borrow balance for a given account
     * @param account The address of the account to check
     * @return (deposit value, 0, borrow value)
     */
    function getDepositBorrowValues(address account) external view returns (uint, uint, uint) {
        (uint standardAssetsSumDeposit, uint sumBorrowPlusEffects) = getStandardAssetsDepositBorrowValuesInternal(account);
        return (standardAssetsSumDeposit, 0, sumBorrowPlusEffects);
    }

    function getStandardAssetsDepositBorrowValuesInternal(address account) internal view returns (uint, uint) {
        uint sumDeposit = 0;
        uint sumBorrowPlusEffects = 0;

        // For every supported market (no matter whether user is in (enter market) or not)
        PToken[] memory assets = allMarkets;
        for (uint i = 0; i < assets.length; i++) {
            PToken asset = assets[i];

            // Read the balances and exchange rate from the pToken
            (uint pTokenBalance, uint borrowBalance, uint exchangeRateMantissa) = asset.getAccountSnapshot(account);
            Exp memory exchangeRate = Exp({mantissa : exchangeRateMantissa});

            // Get the normalized price of the asset
            uint oraclePriceMantissa = oracle.getUnderlyingPrice(asset);
            require(oraclePriceMantissa > 0, "Error.PRICE_ERROR");

            Exp memory oraclePrice = Exp({mantissa : oraclePriceMantissa});

            // Pre-compute a conversion factor from tokens -> ether (normalized price value)
            Exp memory tokensToDenom = mul_(oraclePrice, exchangeRate);

            // sumDeposit += tokensToDenom * pTokenBalance
            sumDeposit = mul_ScalarTruncateAddUInt(tokensToDenom, pTokenBalance, sumDeposit);

            // sumBorrowPlusEffects += oraclePrice * borrowBalance
            sumBorrowPlusEffects = mul_ScalarTruncateAddUInt(oraclePrice, borrowBalance, sumBorrowPlusEffects);
        }

        return (sumDeposit, sumBorrowPlusEffects);
    }

    /*** Admin Functions ***/

    /**
      * @notice Sets a new price oracle for the comptroller
      * @dev Admin function to set a new price oracle
      */
    function _setPriceOracle(PriceOracleInterface newOracle) external {
        onlyAdmin();
        require(newOracle.isPriceOracle(), "incorrect oracle");

        emit NewPriceOracle(oracle, newOracle);
        oracle = newOracle;
    }

    /**
      * @notice Sets the closeFactor used when liquidating borrows
      * @dev Admin function to set closeFactor
      * @param newCloseFactorMantissa New close factor, scaled by 1e18
      */
    function _setCloseFactor(uint newCloseFactorMantissa) external {
        onlyAdmin();
        require(newCloseFactorMantissa <= 10 ** 18, "invalid argument");

        emit NewCloseFactor(closeFactorMantissa, newCloseFactorMantissa);
        closeFactorMantissa = newCloseFactorMantissa;
    }

    /**
      * @notice Sets the collateralFactor for a market
      * @dev Admin function to set per-market collateralFactor
      * @param pToken The market to set the factor on
      * @param newCollateralFactorMantissa The new collateral factor, scaled by 1e18
      * @return uint 0=success, otherwise a failure. (See ErrorReporter for details)
      */
    function _setCollateralFactor(PToken pToken, uint newCollateralFactorMantissa) external returns (uint) {
        require(newCollateralFactorMantissa <= 10 ** 18, "invalid argument");
        require(pToken.isPToken(), "incorrect asset");

        // If collateral factor != 0, fail if price == 0
        if (newCollateralFactorMantissa != 0 && oracle.getUnderlyingPrice(pToken) == 0) {
            return fail(Error.PRICE_ERROR, FailureInfo.SET_COLLATERAL_FACTOR_WITHOUT_PRICE);
        }

        return _setCollateralFactorInternal(address(pToken), newCollateralFactorMantissa);
    }

    function _setCollateralFactorInternal(address pToken, uint newCollateralFactorMantissa) internal returns (uint) {
        onlyAdmin();

        // Verify market is listed
        Market storage market = markets[pToken];
        if (!market.isListed) {
            return fail(Error.MARKET_NOT_LISTED, FailureInfo.SET_COLLATERAL_FACTOR_NO_EXISTS);
        }

        Exp memory newCollateralFactorExp = Exp({mantissa : newCollateralFactorMantissa});

        // Check collateral factor <= 0.9
        Exp memory highLimit = Exp({mantissa : collateralFactorMaxMantissa});
        if (lessThanExp(highLimit, newCollateralFactorExp)) {
            return fail(Error.INVALID_COLLATERAL_FACTOR, FailureInfo.SET_COLLATERAL_FACTOR_VALIDATION);
        }

        emit NewCollateralFactor(pToken, market.collateralFactorMantissa, newCollateralFactorMantissa);
        market.collateralFactorMantissa = newCollateralFactorMantissa;
        return uint(Error.NO_ERROR);
    }

    /**
      * @notice Sets liquidationIncentive
      * @dev Admin function to set liquidationIncentive
      * @param newLiquidationIncentiveMantissa New liquidationIncentive scaled by 1e18
      */
    function _setLiquidationIncentive(uint newLiquidationIncentiveMantissa) external {
        onlyAdmin();
        require(newLiquidationIncentiveMantissa >= 10 ** 18, "invalid argument");

        emit NewLiquidationIncentive(liquidationIncentiveMantissa, newLiquidationIncentiveMantissa);
        liquidationIncentiveMantissa = newLiquidationIncentiveMantissa;
    }

    /**
      * @notice Add the market to the markets mapping and set it as listed
      * @dev Admin function to set isListed and add support for the market
      * @param pToken The address of the market (token) to list
      * @return uint 0=success, otherwise a failure. (See enum Error for details)
      */
    function _supportMarket(PToken pToken) external returns (uint) {
        require(pToken.isPToken(), "incorrect asset");

        uint err = _supportMarketInternal(address(pToken));
        if (err != uint(Error.NO_ERROR)) return err;

        for (uint i = 0; i < allMarkets.length; i++) {
            require(allMarkets[i] != pToken, "market already added");
        }

        allMarkets.push(pToken);

        _initializeMarket(address(pToken));
        emit MarketListed(address(pToken), 0, address(0));
        return uint(Error.NO_ERROR);
    }

    function _supportMarketInternal(address pToken) internal returns (uint) {
        onlyAdmin();

        if (markets[pToken].isListed) {
            return fail(Error.MARKET_ALREADY_LISTED, FailureInfo.SUPPORT_MARKET_EXISTS);
        }

        markets[pToken] = Market({isListed : true, collateralFactorMantissa : 0});
        return uint(Error.NO_ERROR);
    }

    function _initializeMarket(address pToken) internal {
        uint32 blockNumber = safe32(getBlockNumber(), "block number exceeds 32 bits");

        PBXMarketState storage supplyState = PBXSupplyState[pToken];
        PBXMarketState storage borrowState = PBXBorrowState[pToken];

        /*
         * Update market state indices
         */
        if (supplyState.index == 0) {
            // Initialize supply state index with default value
            supplyState.index = PBXInitialIndex;
        }

        if (borrowState.index == 0) {
            // Initialize borrow state index with default value
            borrowState.index = PBXInitialIndex;
        }

        /*
         * Update market state block numbers
         */
        supplyState.block = borrowState.block = blockNumber;
    }

    /**
      * @notice Set the given borrow caps for the given pToken markets. Borrowing that brings total borrows to or above borrow cap will revert.
      * @dev Admin or borrowCapGuardian function to set the borrow caps. A borrow cap of 0 corresponds to unlimited borrowing.
      * @param pTokens The addresses of the markets (tokens) to change the borrow caps for
      * @param newBorrowCaps The new borrow cap values in underlying to be set. A value of 0 corresponds to unlimited borrowing.
      */
    function _setMarketBorrowCaps(PToken[] calldata pTokens, uint[] calldata newBorrowCaps) external {
    	require(msg.sender == admin || msg.sender == borrowCapGuardian, "only admin or borrow cap guardian can set borrow caps");

        uint numMarkets = pTokens.length;
        uint numBorrowCaps = newBorrowCaps.length;

        require(numMarkets != 0 && numMarkets == numBorrowCaps, "invalid input");

        for (uint i = 0; i < numMarkets; i++) {
            require(pTokens[i].isPToken(), "incorrect asset");
            borrowCaps[address(pTokens[i])] = newBorrowCaps[i];
            emit NewBorrowCap(pTokens[i], newBorrowCaps[i]);
        }
    }

    /**
     * @notice Admin function to change the Borrow Cap Guardian
     * @param newBorrowCapGuardian The address of the new Borrow Cap Guardian
     */
    function _setBorrowCapGuardian(address newBorrowCapGuardian) external {
        onlyAdmin();

        emit NewBorrowCapGuardian(borrowCapGuardian, newBorrowCapGuardian);
        borrowCapGuardian = newBorrowCapGuardian;
    }

    /**
     * @notice Admin function to change the Pause Guardian
     * @param newPauseGuardian The address of the new Pause Guardian
     */
    function _setPauseGuardian(address newPauseGuardian) external {
        onlyAdmin();

        emit NewPauseGuardian(pauseGuardian, newPauseGuardian);
        pauseGuardian = newPauseGuardian;
    }

    /**
     * @notice Admin function to pause / unpause the token mint feature for all markets
     * @param state true if paused, false if unpaused
     * @return new state
     */
    function _setMintPausedGlobal(bool state) external returns (bool) {
        require(msg.sender == pauseGuardian || msg.sender == admin, "only pause guardian and admin can pause");
        require(msg.sender == admin || state, "only admin can unpause");

        mintGuardianPausedGlobal = state;
        emit ActionPaused(address(0), "Mint", state);
        return state;
    }

    /**
     * @notice Admin function to pause / unpause the token mint feature for a given market
     * @param state true if paused, false if unpaused
     * @param pToken the market to pause / unpause
     * @return new state
     */
    function _setMintPaused(address pToken, bool state) external returns (bool) {
        require(markets[pToken].isListed, "cannot pause a market that is not listed");
        require(msg.sender == pauseGuardian || msg.sender == admin, "only pause guardian and admin can pause");
        require(msg.sender == admin || state, "only admin can unpause");

        mintGuardianPaused[pToken] = state;
        emit ActionPaused(pToken, "Mint", state);
        return state;
    }

    /**
     * @notice Admin function to pause / unpause the token borrow feature for a given market
     * @param state true if paused, false if unpaused
     * @param pToken the market to pause / unpause
     * @return new state
     */
    function _setBorrowPaused(address pToken, bool state) external returns (bool) {
        require(markets[pToken].isListed, "cannot pause a market that is not listed");
        require(msg.sender == pauseGuardian || msg.sender == admin, "only pause guardian and admin can pause");
        require(msg.sender == admin || state, "only admin can unpause");

        borrowGuardianPaused[pToken] = state;
        emit ActionPaused(pToken, "Borrow", state);
        return state;
    }

    /**
     * @notice Admin function to pause / unpause the token borrow feature for all markets
     * @param state true if paused, false if unpaused
     * @return new state
     */
    function _setBorrowPausedGlobal(bool state) external returns (bool) {
        require(msg.sender == pauseGuardian || msg.sender == admin, "only pause guardian and admin can pause");
        require(msg.sender == admin || state, "only admin can unpause");

        borrowGuardianPausedGlobal = state;
        emit ActionPaused(address(0), "Borrow", state);
        return state;
    }

    /**
     * @notice Admin function to pause / unpause the token transfer feature for all markets
     * @param state true if paused, false if unpaused
     * @return new state
     */
    function _setTransferPaused(bool state) external returns (bool) {
        require(msg.sender == pauseGuardian || msg.sender == admin, "only pause guardian and admin can pause");
        require(msg.sender == admin || state, "only admin can unpause");

        transferGuardianPausedGlobal = state;
        emit ActionPaused(address(0), "Transfer", state);
        return state;
    }

    /**
     * @notice Admin function to pause / unpause the token liquidation feature for all markets
     * @param state true if paused, false if unpaused
     * @return new state
     */
    function _setSeizePaused(bool state) external returns (bool) {
        require(msg.sender == pauseGuardian || msg.sender == admin, "only pause guardian and admin can pause");
        require(msg.sender == admin || state, "only admin can unpause");

        seizeGuardianPausedGlobal = state;
        emit ActionPaused(address(0), "Seize", state);
        return state;
    }

    /**
     * @notice Admin function to set the PBX token. Can be set only once.
     * @param newPBXTokenAddress new PBX token address
     */
    function _setPBXToken(address newPBXTokenAddress) external {
        onlyAdmin();
        require(newPBXTokenAddress != address(0), "invalid argument");
        require(PBXToken == address(0), "PBXToken already set");

        emit NewPBXToken(PBXToken, newPBXTokenAddress);
        PBXToken = newPBXTokenAddress;
    }

    /*** Policy Hooks, should not be marked as pure, view ***/

    /**
     * @notice Validates mint and reverts on rejection. May emit logs. Now empty, reserved for potential future use.
     * @param pToken Asset being minted
     * @param minter The address minting the tokens
     * @param actualMintAmount The amount of the underlying asset being minted
     * @param mintTokens The number of tokens being minted
     */
    function mintVerify(address pToken, address minter, uint actualMintAmount, uint mintTokens) external { }

    /**
     * @notice Validates redeem and reverts on rejection. May emit logs.
     * @param pToken Asset being redeemed
     * @param redeemer The address redeeming the tokens
     * @param redeemAmount The amount of the underlying asset being redeemed
     * @param redeemTokens The number of tokens being redeemed
     */
    function redeemVerify(address pToken, address redeemer, uint redeemAmount, uint redeemTokens) external {
        // Shh - currently unused
        pToken;
        redeemer;

        // Require tokens is zero or amount is also zero
        require(!(redeemTokens == 0 && redeemAmount > 0), "redeemTokens zero");
    }

    /**
     * @notice Validates borrow and reverts on rejection. May emit logs. Now empty, reserved for potential future use.
     * @param pToken Asset whose underlying is being borrowed
     * @param borrower The address borrowing the underlying
     * @param borrowAmount The amount of the underlying asset requested to borrow
     */
    function borrowVerify(address pToken, address borrower, uint borrowAmount) external { }

    /**
     * @notice Validates repayBorrow and reverts on rejection. May emit logs. Now empty, reserved for potential future use.
     * @param pToken Asset being repaid
     * @param payer The address repaying the borrow
     * @param borrower The address of the borrower
     * @param actualRepayAmount The amount of underlying being repaid
     */
    function repayBorrowVerify(address pToken, address payer, address borrower, uint actualRepayAmount, uint borrowerIndex) external { }

    /**
     * @notice Validates liquidateBorrow and reverts on rejection. May emit logs. Now empty, reserved for potential future use.
     * @param pTokenBorrowed Asset which was borrowed by the borrower
     * @param pTokenCollateral Asset which was used as collateral and will be seized
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param actualRepayAmount The amount of underlying being repaid
     */
    function liquidateBorrowVerify(address pTokenBorrowed, address pTokenCollateral, address liquidator, address borrower, uint actualRepayAmount, uint seizeTokens) external { }

    /**
     * @notice Validates seize and reverts on rejection. May emit logs. Now empty, reserved for potential future use.
     * @param pTokenCollateral Asset which was used as collateral and will be seized
     * @param pTokenBorrowed Asset which was borrowed by the borrower
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param seizeTokens The number of collateral tokens to seize
     */
    function seizeVerify(address pTokenCollateral, address pTokenBorrowed, address liquidator, address borrower, uint seizeTokens) external { }

    /**
     * @notice Validates transfer and reverts on rejection. May emit logs. Now empty, reserved for potential future use.
     * @param pToken Asset being transferred
     * @param src The account which sources the tokens
     * @param dst The account which receives the tokens
     * @param transferTokens The number of pTokens to transfer
     */
    function transferVerify(address pToken, address src, address dst, uint transferTokens) external { }


    /**
     * @dev Delegates execution to an part 2 implementation contract.
     * It returns to the external caller whatever the implementation returns
     * or forwards reverts.
     */
    function() external payable {
        // delegate all other functions to part 2 implementation
        (bool success,) = comptrollerPart2Implementation.delegatecall(msg.data);

        assembly {
            let free_mem_ptr := mload(0x40)
            returndatacopy(free_mem_ptr, 0, returndatasize)

            switch success
            case 0 {revert(free_mem_ptr, returndatasize)}
            default {return (free_mem_ptr, returndatasize)}
        }
    }
}
