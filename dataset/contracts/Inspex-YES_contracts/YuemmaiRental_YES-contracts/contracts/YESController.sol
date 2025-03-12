//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./modules/admin/Authorization.sol";
import "./interfaces/IYESController.sol";
import "./interfaces/ILending.sol";
import "./interfaces/IYESVault.sol";
import "./interfaces/IYESPriceOracle.sol";
import "./interfaces/IBorrowLimitOracle.sol";
import "./libraries/error/ErrorReporter.sol";
import "./libraries/math/Exponential.sol";

contract YESController is IYESController, YESControllerErrorReporter, Authorization, Exponential {

    uint internal constant collateralFactorMaxMantissa = 0.9e18;

    bool public override constant isController = true;

    IYESVault private _yesVault;
    IYESPriceOracle private _oracle;
    IBorrowLimitOracle private _borrowLimitOracle;
    ILending[] private _allMarkets;
    mapping(address => ILending[]) private _accountAssets;
    mapping(address => Market) private _markets;

    uint public override collateralFactorMantissa;
    uint public override liquidationIncentiveMantissa;
    bool public override transferGuardianPaused;
    bool public override seizeGuardianPaused;

    mapping(address => bool) public override mintGuardianPaused;
    mapping(address => bool) public override borrowGuardianPaused;
    mapping(address => uint) public override borrowCaps;

    constructor(address adminRouter_, address borrowLimitOracle_) Authorization(adminRouter_) {
        _borrowLimitOracle = IBorrowLimitOracle(borrowLimitOracle_);
    }

    /*** Assets You Are In ***/

    function getAssetsIn(address account) external view returns (ILending[] memory) {
        ILending[] memory assetsIn = _accountAssets[account];
        return assetsIn;
    }

    function checkMembership(address account, ILending lContract) external view returns (bool) {
        return _markets[address(lContract)].accountMembership[account];
    }

    function enterMarkets(address[] memory lContracts) public override returns (uint[] memory) {
        uint len = lContracts.length;

        uint[] memory results = new uint[](len);
        for (uint i = 0; i < len; i++) {
            results[i] = uint(addToMarketInternal(lContracts[i], msg.sender));
        }

        return results;
    }

    function addToMarketInternal(address lContractAddress, address borrower) internal returns (Error) {
        Market storage marketToJoin = _markets[lContractAddress];

        if (!marketToJoin.isListed) {
            // market is not listed, cannot join
            return Error.MARKET_NOT_LISTED;
        }

        if (marketToJoin.accountMembership[borrower] == true) {
            // already joined
            return Error.NO_ERROR;
        }

        marketToJoin.accountMembership[borrower] = true;
        _accountAssets[borrower].push(ILending(lContractAddress));

        emit MarketEntered(lContractAddress, borrower);

        return Error.NO_ERROR;
    }

    function exitMarket(address lContractAddress) external override returns (uint) {
        ILending lContract = ILending(lContractAddress);
        (uint oErr, , uint amountOwed, ) = lContract.getAccountSnapshot(msg.sender);
        require(oErr == 0, "exitMarket: getAccountSnapshot failed"); // semi-opaque error code

        /* Fail if the sender has a borrow balance */
        if (amountOwed != 0) {
            return fail(Error.NONZERO_BORROW_BALANCE, FailureInfo.EXIT_MARKET_BALANCE_OWED);
        }

        /* Fail if the sender is not permitted to withdraw all of their tokens */
        uint allowed = withdrawAllowedInternal(lContractAddress, msg.sender);
        if (allowed != 0) {
            return failOpaque(Error.REJECTION, FailureInfo.EXIT_MARKET_REJECTION, allowed);
        }

        Market storage marketToExit = _markets[address(lContract)];

        /* Return true if the sender is not already ‘in’ the market */
        if (!marketToExit.accountMembership[msg.sender]) {
            return uint(Error.NO_ERROR);
        }

        /* Set lContract account membership to false */
        delete marketToExit.accountMembership[msg.sender];

        /* Delete lContract from the account’s list of assets */
        // load into memory for faster iteration
        ILending[] memory userAssetList = _accountAssets[msg.sender];
        uint len = userAssetList.length;
        uint assetIndex = len;
        for (uint i = 0; i < len; i++) {
            if (userAssetList[i] == lContract) {
                assetIndex = i;
                break;
            }
        }

        // We *must* have found the asset in the list or our redundant data structure is broken
        assert(assetIndex < len);

        // copy last item in list to location of item to be removed, reduce length by 1
        ILending[] storage storedList = _accountAssets[msg.sender];
        storedList[assetIndex] = storedList[storedList.length - 1];
        storedList.pop();

        emit MarketExited(lContractAddress, msg.sender);

        return uint(Error.NO_ERROR);
    }


    /*** Policy Hooks ***/

    function depositAllowed(address lContract) external override view returns (uint) {
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!mintGuardianPaused[lContract], "mint is paused");

        if (!_markets[lContract].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        return uint(Error.NO_ERROR);
    }

    function withdrawAllowed(address lContract, address withdrawer) external override view returns (uint) {
        uint allowed = withdrawAllowedInternal(lContract, withdrawer);
        if (allowed != uint(Error.NO_ERROR)) {
            return allowed;
        }

        return uint(Error.NO_ERROR);
    }

    function withdrawAllowedInternal(address lContract, address withdrawer) internal view returns (uint) {
        if (!_markets[lContract].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        /* If the withdrawer is not 'in' the market, then we can bypass the liquidity check */
        if (!_markets[lContract].accountMembership[withdrawer]) {
            return uint(Error.NO_ERROR);
        }

        /* Otherwise, perform a hypothetical liquidity check to guard against shortfall */
        (Error err, uint collateralValue, , uint borrowValue) = getHypotheticalAccountLiquidityInternal(withdrawer, ILending(lContract), 0);
        if (err != Error.NO_ERROR) {
            return uint(err);
        }

        if (collateralValue < borrowValue) {
            return uint(Error.INSUFFICIENT_LIQUIDITY);
        }

        return uint(Error.NO_ERROR);

        // if (shortfall > 0) {
        //     return uint(Error.INSUFFICIENT_LIQUIDITY);
        // }

        // return uint(Error.NO_ERROR);
    }

    function transferAllowed(address lContract, address src) external override view returns (uint) {
        
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!transferGuardianPaused, "transfer is paused");

        // Currently the only consideration is whether or not
        //  the src is allowed to withdraw this many tokens
        uint allowed = withdrawAllowedInternal(lContract, src);
        if (allowed != uint(Error.NO_ERROR)) {
            return allowed;
        }

        return uint(Error.NO_ERROR);
    }

    function borrowAllowed(address lContract, address borrower, uint borrowAmount) external override returns  (uint) {
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!borrowGuardianPaused[lContract], "borrow is paused");

        if (!_markets[lContract].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        if (!_markets[lContract].accountMembership[borrower]) {
            // only lContracts may call borrowAllowed if borrower not in market
            require(msg.sender == lContract, "sender must be lContract");

            // attempt to add borrower to the market
            Error err_ = addToMarketInternal(msg.sender, borrower);
            if (err_ != Error.NO_ERROR) {
                return uint(err_);
            }

            // it should be impossible to break the important invariant
            assert(_markets[lContract].accountMembership[borrower]);
        }

        if (_oracle.getLatestPrice(ILending(lContract).underlyingToken()) == 0) {
            return uint(Error.PRICE_ERROR);
        }

        uint borrowCap = borrowCaps[lContract];
        // Borrow cap of 0 corresponds to unlimited borrowing
        if (borrowCap != 0) {
            uint totalBorrows = ILending(lContract).totalBorrows();
            uint nextTotalBorrows = add_(totalBorrows, borrowAmount);
            require(nextTotalBorrows < borrowCap, "market borrow cap reached");
        }

        (Error err, uint collateralValue, uint borrowLimit, uint borrowValue) = getHypotheticalAccountLiquidityInternal(borrower, ILending(lContract), borrowAmount);
        if (err != Error.NO_ERROR) {
            return uint(err);
        }

        if (collateralValue < borrowLimit) {
            if (collateralValue < borrowValue) {
                return uint(Error.INSUFFICIENT_LIQUIDITY);
            }
        } else {
            if (borrowLimit < borrowValue) {
                return uint(Error.INSUFFICIENT_BORROW_LIMIT);
            }
        }

        return uint(Error.NO_ERROR);
    }

    function repayBorrowAllowed(
        address lContract
    ) external override view returns (uint) {

        if (!_markets[lContract].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        return uint(Error.NO_ERROR);
    }

    function liquidateBorrowAllowed(
        address lContract,
        address borrower
    ) external override view returns (uint) {

        if (!_markets[lContract].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        (Error err, uint collateralValue, uint borrowLimit, uint borrowBalance) = getAccountLiquidityInternal(borrower);
        uint borrowPower = collateralValue <= borrowLimit ? collateralValue : borrowLimit;

        /* The borrower must have shortfall in order to be liquidatable */
        if (err != Error.NO_ERROR) {
            return uint(err);
        }

        if (borrowPower >= borrowBalance) {
            return uint(Error.INSUFFICIENT_SHORTFALL);
        }

        return uint(Error.NO_ERROR);
    }

    function seizeAllowed(
        address lContract
    ) external override view returns (uint) {
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!seizeGuardianPaused, "seize is paused");

        if (!_markets[lContract].isListed) {
            return uint(Error.MARKET_NOT_LISTED);
        }

        if (address(ILending(lContract).controller()) != address(this)) {
            return uint(Error.CONTROLLER_MISMATCH);
        }

        return uint(Error.NO_ERROR);
    }

     /*** Liquidity/Liquidation Calculations ***/

    struct AccountLiquidityLocalVars {
        uint collateralValue;
        uint borrowLimit;
        uint sumBorrowPlusEffects;
        uint collateralBalance;
        uint borrowBalance;
        uint exchangeRateMantissa;
        uint oraclePriceMantissa;
        uint yesPrice;
        Exp collateralFactor;
        Exp exchangeRate;
        Exp oraclePrice;
        Exp tokensToDenom;
    }

    function getAccountLiquidity(address account) public view override returns (uint, uint, uint, uint) {
        (Error err, uint collateralValue, uint borrowLimit, uint borrowValue) = getHypotheticalAccountLiquidityInternal(account, ILending(address(0)), 0);

        return (uint(err), collateralValue, borrowLimit, borrowValue);
    }

    function getAccountLiquidityInternal(address account) internal view returns (Error, uint, uint, uint) {
        return getHypotheticalAccountLiquidityInternal(account, ILending(address(0)), 0);
    }

    function getHypotheticalAccountLiquidity(
        address account,
        address lContractModify,
        uint borrowAmount
    ) public view returns (uint, uint, uint, uint) {
        (Error err, uint collateralValue, uint borrowLimit, uint borrowValue) = getHypotheticalAccountLiquidityInternal(account, ILending(lContractModify), borrowAmount);
        return (uint(err), collateralValue, borrowLimit, borrowValue);
    }

    function getHypotheticalAccountLiquidityInternal(
        address account,
        ILending lContractModify,
        uint borrowAmount
    ) internal view returns (Error, uint, uint, uint) {

        AccountLiquidityLocalVars memory vars; // Holds all our calculation results
        uint oErr;

        vars.collateralBalance = _yesVault.tokensOf(account); 

        vars.collateralFactor = Exp({mantissa: collateralFactorMantissa});

        // collateralValue = tokensToDenom * lContractBalance
        vars.collateralValue = mul_ScalarTruncate(vars.collateralFactor, vars.collateralBalance);

        vars.yesPrice = _oracle.getYESPrice();

        // Use off-chain borrow limit for YES customers. Otherwise, use only collateral value.
        vars.borrowLimit = _yesVault.releasedTo(account) > 0 ? 
            mul_ScalarTruncate(Exp({mantissa: vars.yesPrice}), borrowLimitOf(account)) : 
            vars.collateralValue;

        // For each asset the account is in
        ILending[] memory assets = _accountAssets[account];

        for (uint i = 0; i < assets.length; i++) {
            ILending asset = assets[i];

            // Read the balances and exchange rate from the lContract
            (oErr, , vars.borrowBalance, ) = asset.getAccountSnapshot(account);

            if (oErr != 0) { // semi-opaque error code, we assume NO_ERROR == 0 is invariant between upgrades
                return (Error.SNAPSHOT_ERROR, 0, 0, 0);
            }

            // Get the normalized price of the asset
            vars.oraclePriceMantissa = _oracle.getLatestPrice(asset.underlyingToken());
            if (vars.oraclePriceMantissa == 0) {
                return (Error.PRICE_ERROR, 0, 0, 0);
            }
            vars.oraclePrice = Exp({mantissa: vars.oraclePriceMantissa});

            // sumBorrowPlusEffects += oraclePrice * borrowBalance
            vars.sumBorrowPlusEffects = mul_ScalarTruncateAddUInt(vars.oraclePrice, vars.borrowBalance, vars.sumBorrowPlusEffects);

            // Calculate effects of interacting with lContractModify
            if (asset == lContractModify) {
                // withdraw effect
                // sumBorrowPlusEffects += tokensToDenom * withdrawTokens
                // vars.sumBorrowPlusEffects = mul_ScalarTruncateAddUInt(vars.tokensToDenom, withdrawTokens, vars.sumBorrowPlusEffects);

                // borrow effect
                // sumBorrowPlusEffects += oraclePrice * borrowAmount
                vars.sumBorrowPlusEffects = mul_ScalarTruncateAddUInt(vars.oraclePrice, borrowAmount, vars.sumBorrowPlusEffects);
            }
        }

        return (Error.NO_ERROR, vars.collateralValue, vars.borrowLimit, vars.sumBorrowPlusEffects);

        // // These are safe, as the underflow condition is checked first
        // if (vars.collateralValue > vars.sumBorrowPlusEffects) {
        //     return (Error.NO_ERROR, vars.collateralValue - vars.sumBorrowPlusEffects, 0);
        // } else {
        //     return (Error.NO_ERROR, 0, vars.sumBorrowPlusEffects - vars.collateralValue);
        // }
    }

    function liquidateCalculateSeizeTokens(address lContract, uint borrowBalance) external override view returns (uint, uint) {
        /* Read oracle prices for borrowed and collateral markets */
        uint priceBorrowedMantissa = _oracle.getLatestPrice(ILending(lContract).underlyingToken());
        if (priceBorrowedMantissa == 0) {
            return (uint(Error.PRICE_ERROR), 0);
        }

        uint seizeTokens;
        Exp memory incentivePrice;

        incentivePrice = mul_(Exp({mantissa: liquidationIncentiveMantissa}), Exp({mantissa: priceBorrowedMantissa}));

        seizeTokens = mul_ScalarTruncate(incentivePrice, borrowBalance);

        return (uint(Error.NO_ERROR), seizeTokens);
    }

    /* Getters */

    function yesVault() external view override returns (address) {
        return address(_yesVault);
    }

    function oracle() external view override returns (address) {
        return address(_oracle);
    }

    function borrowLimitOracle() external view override returns (address) {
        return address(_borrowLimitOracle);
    }

    function markets(address lContract, address account) external view override returns (bool, bool) {
        Market storage market = _markets[lContract];
        return (market.isListed, market.accountMembership[account]);
    }

    function allMarkets() external view override returns (address[] memory) {
        address[] memory marketList = new address[](_allMarkets.length);
        for (uint i = 0; i < _allMarkets.length; i++)
            marketList[i] = address(_allMarkets[i]);
        return marketList;
    }

    function accountAssets(address account) external view override returns (address[] memory) {
        ILending[] memory lContracts = _accountAssets[account];
        address[] memory assets = new address[](lContracts.length);
        for (uint i = 0; i < lContracts.length; i++)
            assets[i] = address(lContracts[i]);
        return assets;
    }

    function isDeprecated(ILending lContract) public view returns (bool) {
        return
            borrowGuardianPaused[address(lContract)] == true && 
            lContract.reserveFactorMantissa() == 1e18
        ;
    }

    function getBlockNumber() public view returns (uint) {
        return block.number;
    }

    /* Admin Functions */

    function _supportMarket(address lContractAddress) external onlyAdmin returns (uint) {
        ILending lContract = ILending(lContractAddress);
        if (_markets[lContractAddress].isListed) {
            return fail(Error.MARKET_ALREADY_LISTED, FailureInfo.SUPPORT_MARKET_EXISTS);
        }

        lContract.isLContract(); // Sanity check to make sure its really a LToken

        _markets[lContractAddress].isListed = true;

        _addMarketInternal(lContractAddress);

        emit MarketListed(lContractAddress);

        return uint(Error.NO_ERROR);
    }

    function _addMarketInternal(address lContract) internal {
        for (uint i = 0; i < _allMarkets.length; i ++) {
            require(_allMarkets[i] != ILending(lContract), "market already added");
        }
        _allMarkets.push(ILending(lContract));
    }

    function _setMintPaused(address lContractAddress, bool state) public onlyAdmin returns (bool) {
        require(_markets[lContractAddress].isListed, "cannot pause a market that is not listed");

        mintGuardianPaused[lContractAddress] = state;
        emit ActionPaused(lContractAddress, "Mint", state);
        return state;
    }

    function _setPriceOracle(address newOracle) public onlyAdmin returns (uint) {
        // Track the old oracle for the controller
        IYESPriceOracle oldOracle = _oracle;

        // Set controller's oracle to newOracle
        _oracle = IYESPriceOracle(newOracle);

        // Emit NewPriceOracle(oldOracle, newOracle)
        emit NewPriceOracle(address(oldOracle), newOracle);

        return uint(Error.NO_ERROR);
    }

    function _setYESVault(address newYESVault) public onlyAdmin returns (uint) {
        IYESVault oldYESVault = _yesVault;
        _yesVault = IYESVault(newYESVault);
        emit NewYESVault(address(oldYESVault), newYESVault);
        return uint(Error.NO_ERROR);
    }

    function _setCollateralFactor(uint newCollateralFactorMantissa) external onlyAdmin returns (uint) {
        Exp memory newCollateralFactorExp = Exp({mantissa: newCollateralFactorMantissa});

        // Check collateral factor <= 1
        Exp memory highLimit = Exp({mantissa: collateralFactorMaxMantissa});
        if (lessThanExp(highLimit, newCollateralFactorExp)) {
            return fail(Error.INVALID_COLLATERAL_FACTOR, FailureInfo.SET_COLLATERAL_FACTOR_VALIDATION);
        }

        // Set market's collateral factor to new collateral factor, remember old value
        uint oldCollateralFactorMantissa = collateralFactorMantissa;
        collateralFactorMantissa = newCollateralFactorMantissa;

        // Emit event with asset, old collateral factor, and new collateral factor
        emit NewCollateralFactor(oldCollateralFactorMantissa, newCollateralFactorMantissa);

        return uint(Error.NO_ERROR);
    }

    function _setLiquidationIncentive(uint newLiquidationIncentiveMantissa) external onlyAdmin returns (uint) {
        // Save current value for use in log
        uint oldLiquidationIncentiveMantissa = liquidationIncentiveMantissa;

        // Set liquidation incentive to new incentive
        liquidationIncentiveMantissa = newLiquidationIncentiveMantissa;

        // Emit event with old incentive, new incentive
        emit NewLiquidationIncentive(oldLiquidationIncentiveMantissa, newLiquidationIncentiveMantissa);

        return uint(Error.NO_ERROR);
    }

    function borrowLimitOf(address account) public view override returns (uint) {
        return _borrowLimitOracle.borrowLimitOf(account);
    }
  
}
