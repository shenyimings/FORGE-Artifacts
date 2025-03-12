pragma solidity ^0.5.16;

import "./compound/ComptrollerInterface.sol";
import "./compound/CTokenInterfaces.sol";


interface LiquidatorPool {
    function enterUserMarket(address owner, CErc20Interface market) external;
}

// for now ETH is not supported
contract User {
    ComptrollerInterface comp;
    PriceOracle fakePriceOracle;
    address owner;
    address liquidatorsPool;
    mapping(address=>uint) debtToPool;
    bool topped = false;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(ComptrollerInterface _comp, PriceOracle _fakePriceOracle, address _owner, address _liquidatorsPool) public {
        comp = _comp;
        fakePriceOracle = _fakePriceOracle;
        owner = _owner;
        liquidatorsPool = _liquidatorsPool;
    }

    // comptroller interface
    function enterMarkets(address[] memory cTokens) public onlyOwner returns (uint[] memory) {
        for(uint i = 0 ; i < cTokens.length ; i++) {
            EIP20Interface underlying = EIP20Interface(CErc20Interface(cTokens[i]).underlying());
            underlying.approve(cTokens[i],uint(-1));
            LiquidatorPool(liquidatorsPool).enterUserMarket(owner, CErc20Interface(cTokens[i]));
        }

        return comp.enterMarkets(cTokens);
    }

    function exitMarket(address cToken) public onlyOwner returns (uint) {
        EIP20Interface underlying = EIP20Interface(CErc20Interface(cToken).underlying());
        underlying.approve(cToken,0);

        return comp.exitMarket(cToken);
    }

    // ctoken interface
    function mint(CErc20Interface cToken, uint mintAmount) public onlyOwner returns (uint) {
        EIP20Interface underlying = EIP20Interface(cToken.underlying());
        underlying.transferFrom(msg.sender,address(this),mintAmount);

        require(cToken.mint(mintAmount) == 0);
    }

    function redeem(CErc20Interface cToken, uint redeemTokens) public onlyOwner returns (uint) {
        // TODO - check that safe
        require(cToken.redeem(redeemTokens) == 0);
        EIP20Interface underlying = EIP20Interface(cToken.underlying());

        require(underlying.transfer(owner, underlying.balanceOf(address(this))));
    }

    function redeemUnderlying(CErc20Interface cToken, uint redeemAmount) public onlyOwner returns (uint) {
        // TODO - check that safe
        require(cToken.redeemUnderlying(redeemAmount) == 0);
        EIP20Interface underlying = EIP20Interface(cToken.underlying());

        require(underlying.transfer(owner, underlying.balanceOf(address(this))));
    }

    function borrow(CErc20Interface cToken, uint borrowAmount) public onlyOwner returns (uint) {
        EIP20Interface underlying = EIP20Interface(cToken.underlying());
        require(cToken.borrow(borrowAmount) == 0);

        require(underlying.transfer(owner, underlying.balanceOf(address(this))));
    }

    function repayBorrow(CErc20Interface cToken, uint repayAmount) public onlyOwner returns (uint) {
        if(repayAmount == uint(-1)) repayAmount = cToken.borrowBalanceCurrent(address(this));

        EIP20Interface underlying = EIP20Interface(cToken.underlying());
        underlying.transferFrom(msg.sender,address(this),repayAmount);

        require(cToken.repayBorrow(repayAmount) == 0);
    }

    ////////////////////////////////////////////////////////////////////////////

    function getUserDebtAndCollateralNormalized() public /*view*/ returns(uint debtValue, uint collateralValue) {
        address[] memory assets = comp.getAssetsIn(address(this));
        debtValue = 0;
        for(uint i = 0 ; i < assets.length ; i++) {
            CErc20Interface asset = CErc20Interface(assets[i]);
            uint price = fakePriceOracle.getUnderlyingPrice(asset);
            require(price > 0, "invalid price");
            debtValue += asset.borrowBalanceCurrent(address(this)) * price;
        }

        (uint err, uint liquidity,uint shortfall) = comp.getAccountLiquidity(address(this));
        require(err == 0, "comp.getAccountLiquidity failed");
        if(liquidity > 0) {
            collateralValue = debtValue + liquidity;
        }
        else {
            collateralValue = debtValue - shortfall;
        }
    }

    ////////////////////////////////////////////////////////////////////////////

    function shouldTop() public /*view*/ returns(bool) {
        if(topped) return false;

        (uint debt, uint collateral) = getUserDebtAndCollateralNormalized();

        return debt * 110 >= collateral * 100;
    }

    function shouldUntop() public /*view*/ returns(bool) {
        if(! topped) return false;

        (uint debt, uint collateral) = getUserDebtAndCollateralNormalized();

        return debt * 120 <= collateral * 100;
    }

    function topUp() public { // anyone can call
        require(shouldTop(), "no need for topping");

        address[] memory assets = comp.getAssetsIn(address(this));
        for(uint i = 0 ; i < assets.length ; i++) {
            CErc20Interface asset = CErc20Interface(assets[i]);
            EIP20Interface underlying = EIP20Interface(asset.underlying());
            uint topUpAmount = asset.borrowBalanceCurrent(address(this)) / 20;

            if(topUpAmount == 0) continue;

            underlying.transferFrom(liquidatorsPool, address(this), topUpAmount);
            require(asset.repayBorrow(topUpAmount) == 0, "topUp: repayBorrow failed");

            debtToPool[address(underlying)] += topUpAmount;
        }

        topped = true;
    }

    function untop() public { // anyone can call
        require(shouldUntop(), "no need for untopping");

        address[] memory assets = comp.getAssetsIn(address(this));
        for(uint i = 0 ; i < assets.length ; i++) {
            CErc20Interface asset = CErc20Interface(assets[i]);
            EIP20Interface underlying = EIP20Interface(asset.underlying());

            uint untopAmount = debtToPool[address(underlying)];

            if(untopAmount == 0) continue;

            require(asset.borrow(untopAmount) == 0, "untop: borrow failed");

            debtToPool[address(underlying)] = 0;
            require(underlying.transfer(liquidatorsPool, untopAmount));
        }

        topped = false;
    }

    function canLiquidate() public /*view*/ returns(bool) {
        (uint debt, uint collateral) = getUserDebtAndCollateralNormalized();

        uint poolDebt = 0;
        address[] memory assets = comp.getAssetsIn(address(this));
        for(uint i = 0 ; i < assets.length ; i++) {
            CErc20Interface asset = CErc20Interface(assets[i]);
            EIP20Interface underlying = EIP20Interface(asset.underlying());
            poolDebt += debtToPool[address(underlying)] * fakePriceOracle.getUnderlyingPrice(asset);
        }

        return (debt + poolDebt) >= collateral;
    }

    function availableLiquidationSize(CErc20Interface cDebtToken) public returns(uint) {
        if(! canLiquidate()) return 0;

        uint debt = cDebtToken.borrowBalanceCurrent(address(this));
        uint poolDebt = debtToPool[cDebtToken.underlying()];

        uint maxLiquidationAmount = (comp.closeFactorMantissa() * (debt + poolDebt)) / 1e18;

        return maxLiquidationAmount;
    }

    function liquidateBorrow(CErc20Interface cToken, uint underlyingAmount, CErc20Interface collateral) public { // TODO - only liquidator can call it
        require(canLiquidate(), "liquidateBorrow: cannot liquidate");
        EIP20Interface underlying = EIP20Interface(cToken.underlying());
        uint debt = cToken.borrowBalanceCurrent(address(this));
        uint poolDebt = debtToPool[address(underlying)];

        uint maxLiquidationAmount = (comp.closeFactorMantissa() * (debt + poolDebt)) / 1e18;

        require(maxLiquidationAmount >= underlyingAmount, "liquidateBorrow: underlyingAmount is too big");

        if(poolDebt < underlyingAmount) {
            require(underlying.transferFrom(msg.sender,address(this), underlyingAmount - poolDebt));
            require(cToken.repayBorrow(underlyingAmount - poolDebt) == 0, "liquidateBorrow: repayBorrow failed");
            debtToPool[address(underlying)] = 0;
        }
        else {
            debtToPool[address(underlying)] -= underlyingAmount;
        }

        // send collateral to liquidator
        uint underlyingValue = underlyingAmount * fakePriceOracle.getUnderlyingPrice(cToken);
        uint collateralAmount = underlyingValue * 1e18 / (fakePriceOracle.getUnderlyingPrice(collateral) * collateral.exchangeRateCurrent());
        uint permiumAmount = collateralAmount * comp.liquidationIncentiveMantissa() / 1e18;

        require(collateral.transfer(msg.sender, permiumAmount), "liquidateBorrow: collateral transfer failed");

        // check if need to reset topped flag
        address[] memory assets = comp.getAssetsIn(address(this));
        uint totalPoolDebt = 0;
        for(uint i = 0 ; i < assets.length ; i++) {
            CErc20Interface asset = CErc20Interface(assets[i]);
            totalPoolDebt += debtToPool[address(asset.underlying())];
        }

        if(totalPoolDebt == 0) topped = false;
    }
}
