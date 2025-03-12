// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../TroveManager.sol";
import "../BorrowerOperations.sol";
import "../ActivePool.sol";
import "../DefaultPool.sol";
import "../StabilityPool.sol";
import "../GasPool.sol";
import "../CollSurplusPool.sol";
import "../EUSDToken.sol";
import "./PriceFeedTestnet.sol";
import "../SortedTroves.sol";
import "../TroveManagerLiquidations.sol";
import "../TroveManagerRedemptions.sol";
import "../CollateralManager.sol";
import "../Treasury.sol";
import "../LiquidityIncentive.sol";
import "../TroveDebt.sol";
import "../TroveInterestRateStrategy.sol";
import "./TestAssets/WETH.sol";
import "./EchidnaProxy.sol";
import "../DataTypes.sol";

// Run with:
// rm -f fuzzTests/corpus/* # (optional)
// ~/.local/bin/echidna-test contracts/TestContracts/EchidnaTester.sol --contract EchidnaTester --config fuzzTests/echidna_config.yaml

contract EchidnaTester {
    using SafeMathUpgradeable for uint256;

    uint256 private constant NUMBER_OF_ACTORS = 100;
    uint256 private constant INITIAL_BALANCE = 1e24;
    uint256 private MCR;
    uint256 private CCR;
    uint256 private EUSD_GAS_COMPENSATION;

    TroveManager public troveManager;
    TroveManagerLiquidations public troveManagerLiquidations;
    TroveManagerRedemptions public troveManagerRedemptions;
    BorrowerOperations public borrowerOperations;
    ActivePool public activePool;
    DefaultPool public defaultPool;
    StabilityPool public stabilityPool;
    GasPool public gasPool;
    CollSurplusPool public collSurplusPool;
    EUSDToken public eusdToken;
    PriceFeedTestnet priceFeedTestnet;
    SortedTroves sortedTroves;
    CollateralManager collateralManager;
    Treasury treasury;
    LiquidityIncentive liquidityIncentive;
    TroveDebt troveDebt;
    TroveInterestRateStrategy troveInterestRateStrategy;

    WETH weth;

    EchidnaProxy[NUMBER_OF_ACTORS] public echidnaProxies;

    uint256 private numberOfTroves;

    constructor() payable {
        troveManager = new TroveManager();
        borrowerOperations = new BorrowerOperations();
        activePool = new ActivePool();
        defaultPool = new DefaultPool();
        stabilityPool = new StabilityPool();
        gasPool = new GasPool();
        troveManagerLiquidations = new TroveManagerLiquidations();
        troveManagerRedemptions = new TroveManagerRedemptions();
        collateralManager = new CollateralManager();
        treasury = new Treasury();
        liquidityIncentive = new LiquidityIncentive();
        troveDebt = new TroveDebt();
        eusdToken = new EUSDToken();
        eusdToken.initialize(
            address(troveManager),
            address(troveManagerLiquidations),
            address(troveManagerRedemptions),
            address(stabilityPool),
            address(borrowerOperations),
            address(treasury),
            address(liquidityIncentive)
        );
        
        troveInterestRateStrategy = new TroveInterestRateStrategy();
        troveInterestRateStrategy.initialize(
            2e27,
            75e23,
            1e25,
            2e25
        );

        weth = new WETH();

        collSurplusPool = new CollSurplusPool();
        priceFeedTestnet = new PriceFeedTestnet();

        sortedTroves = new SortedTroves();

        troveManager.initialize(
            address(troveDebt),
            address(troveInterestRateStrategy)
        );

        troveManager.setAddresses(
            address(borrowerOperations),
            address(activePool),
            address(defaultPool),
            address(stabilityPool),
            address(gasPool),
            address(collSurplusPool),
            address(priceFeedTestnet),
            address(eusdToken),
            address(sortedTroves),
            address(troveManagerLiquidations),
            address(troveManagerRedemptions),
            address(collateralManager)
        );

        troveManagerLiquidations.setAddresses(
            address(borrowerOperations),
            address(activePool),
            address(defaultPool),
            address(stabilityPool),
            address(gasPool),
            address(collSurplusPool),
            address(priceFeedTestnet),
            address(eusdToken),
            address(sortedTroves),
            address(troveManager),
            address(collateralManager)
        );

        troveManagerLiquidations.init(address(troveDebt));

        troveManagerRedemptions.setAddresses(
            address(borrowerOperations),
            address(activePool),
            address(defaultPool),
            address(stabilityPool),
            address(gasPool),
            address(collSurplusPool),
            address(priceFeedTestnet),
            address(eusdToken),
            address(sortedTroves),
            address(troveManager),
            address(collateralManager)
        );

        borrowerOperations.setAddresses(
            address(troveManager),
            address(collateralManager),
            address(activePool),
            address(defaultPool),
            address(stabilityPool),
            address(gasPool),
            address(collSurplusPool),
            address(priceFeedTestnet),
            address(sortedTroves),
            address(eusdToken)
        );

        borrowerOperations.init(
            address(weth),
            address(treasury),
            address(troveDebt)
        );

        activePool.setAddresses(
            address(borrowerOperations),
            address(troveManager),
            address(troveManagerLiquidations),
            address(troveManagerRedemptions),
            address(stabilityPool),
            address(defaultPool),
            address(treasury),
            address(liquidityIncentive),
            address(collSurplusPool),
            address(weth)
        );

        defaultPool.setAddresses(address(troveManager), address(activePool));

        stabilityPool.setAddresses(
            address(borrowerOperations),
            address(troveManager),
            address(collateralManager),
            address(troveManagerLiquidations),
            address(activePool),
            address(eusdToken),
            address(sortedTroves),
            address(priceFeedTestnet),
            address(0),
            address(weth)
        );

        collSurplusPool.setAddresses(
            address(borrowerOperations),
            address(troveManager),
            address(troveManagerLiquidations),
            address(troveManagerRedemptions),
            address(activePool),
            address(weth)
        );

        sortedTroves.setParams(
            1e18,
            address(troveManager),
            address(troveManagerRedemptions),
            address(borrowerOperations)
        );

        for (uint256 i = 0; i < NUMBER_OF_ACTORS; i++) {
            echidnaProxies[i] = new EchidnaProxy(
                troveManager,
                borrowerOperations,
                stabilityPool,
                eusdToken
            );
            (bool success, ) = address(echidnaProxies[i]).call{
                value: INITIAL_BALANCE
            }("");
            require(success, "proxy called failed");
        }

        MCR = collateralManager.MCR();
        CCR = collateralManager.CCR();
        EUSD_GAS_COMPENSATION = collateralManager.EUSD_GAS_COMPENSATION();
        require(MCR != 0, "MCR <= 0");
        require(CCR != 0, "CCR <= 0");

        priceFeedTestnet.setPrice(1e22);
    }

    function _getUSDValue(
        address[] memory _collaterals,
        uint256[] memory _amounts,
        uint256 _price
    ) internal view returns (uint256) {
        (uint256 totalValue, ) = collateralManager.getValue(
            _collaterals,
            _amounts,
            _price
        );
        return totalValue;
    }

    // TroveManager

    function liquidateExt(uint256 _i, address _user) external {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].liquidatePrx(_user);
    }

    function liquidateTrovesExt(uint256 _i, uint256 _n) external {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].liquidateTrovesPrx(_n);
    }

    function batchLiquidateTrovesExt(
        uint256 _i,
        address[] calldata _troveArray
    ) external {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].batchLiquidateTrovesPrx(_troveArray);
    }

    function redeemCollateralExt(
        uint256 _i,
        uint256 _EUSDAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR
    ) external {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].redeemCollateralPrx(
            _EUSDAmount,
            _firstRedemptionHint,
            _upperPartialRedemptionHint,
            _lowerPartialRedemptionHint,
            _partialRedemptionHintNICR,
            0,
            0
        );
    }

    // Borrower Operations

    function getAdjustedETH(
        uint256 actorBalance,
        uint256 _ETH,
        uint256 ratio
    ) internal view returns (uint256) {
        uint256 price = priceFeedTestnet.getPrice();
        require(price != 0);
        uint256 minETH = ratio.mul(EUSD_GAS_COMPENSATION).div(price);
        require(actorBalance > minETH);
        uint256 ETH = minETH + (_ETH % (actorBalance - minETH));
        return ETH;
    }

    function getAdjustedEUSD(
        address[] memory _collaterals,
        uint256[] memory _amounts,
        uint256 _EUSDAmount,
        uint256 ratio
    ) internal view returns (uint256) {
        uint256 price = priceFeedTestnet.getPrice();
        uint256 value = _getUSDValue(_collaterals, _amounts, price);
        uint256 EUSDAmount = _EUSDAmount;
        uint256 compositeDebt = EUSDAmount.add(EUSD_GAS_COMPENSATION);
        uint256 ICR = ERDMath._computeCR(value, compositeDebt);
        if (ICR < ratio) {
            compositeDebt = value.div(ratio);
            EUSDAmount = compositeDebt.sub(EUSD_GAS_COMPENSATION);
        }
        return EUSDAmount;
    }

    function openTroveExt(
        uint256 _i,
        uint256 _ETH,
        address[] memory _collaterals,
        uint256[] memory _amounts,
        uint256 _EUSDAmount
    ) public payable {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        EchidnaProxy echidnaProxy = echidnaProxies[actor];
        uint256 actorBalance = address(echidnaProxy).balance;

        // we pass in CCR instead of MCR in case it’s the first one
        uint256 ETH = getAdjustedETH(actorBalance, _ETH, CCR);
        uint256 EUSDAmount = getAdjustedEUSD(
            _collaterals,
            _amounts,
            _EUSDAmount,
            CCR
        );

        //console.log('ETH', ETH);
        //console.log('EUSDAmount', EUSDAmount);

        echidnaProxy.openTrovePrx(
            ETH,
            0,
            EUSDAmount,
            address(0),
            address(0),
            _collaterals,
            _amounts
        );

        numberOfTroves = troveManager.getTroveOwnersCount();
        assert(numberOfTroves != 0);
        // canary
        //assert(numberOfTroves == 0);
    }

    function openTroveRawExt(
        uint256 _i,
        uint256 _ETH,
        address[] memory _collaterals,
        uint256[] memory _amounts,
        uint256 _EUSDAmount,
        address _upperHint,
        address _lowerHint,
        uint256 _maxFee
    ) public payable {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].openTrovePrx(
            _ETH,
            _maxFee,
            _EUSDAmount,
            _upperHint,
            _lowerHint,
            _collaterals,
            _amounts
        );
    }

    function addCollExt(
        uint256 _i,
        uint256 _ETH,
        address[] memory _collaterals,
        uint256[] memory _amounts
    ) external payable {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        EchidnaProxy echidnaProxy = echidnaProxies[actor];
        uint256 actorBalance = address(echidnaProxy).balance;

        uint256 ETH = getAdjustedETH(actorBalance, _ETH, MCR);

        echidnaProxy.addCollPrx(
            ETH,
            _collaterals,
            _amounts,
            address(0),
            address(0)
        );
    }

    function addCollRawExt(
        uint256 _i,
        uint256 _ETH,
        address[] memory _collaterals,
        uint256[] memory _amounts,
        address _upperHint,
        address _lowerHint
    ) external payable {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].addCollPrx(
            _ETH,
            _collaterals,
            _amounts,
            _upperHint,
            _lowerHint
        );
    }

    function withdrawCollExt(
        uint256 _i,
        address[] memory _collaterals,
        uint256[] memory _amounts,
        address _upperHint,
        address _lowerHint
    ) external {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].withdrawCollPrx(
            _collaterals,
            _amounts,
            _upperHint,
            _lowerHint
        );
    }

    function withdrawEUSDExt(
        uint256 _i,
        uint256 _amount,
        address _upperHint,
        address _lowerHint,
        uint256 _maxFee
    ) external {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].withdrawEUSDPrx(
            _amount,
            _upperHint,
            _lowerHint,
            _maxFee
        );
    }

    function repayEUSDExt(
        uint256 _i,
        uint256 _amount,
        address _upperHint,
        address _lowerHint
    ) external {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].repayEUSDPrx(_amount, _upperHint, _lowerHint);
    }

    function closeTroveExt(uint256 _i) external {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].closeTrovePrx();
    }

    function adjustTroveExt(
        uint256 _i,
        uint256 _ETH,
        address[] memory _collsIn,
        uint256[] memory _amountsIn,
        address[] memory _collsOut,
        uint256[] memory _amountsOut,
        uint256 _debtChange,
        bool _isDebtIncrease
    ) external payable {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        EchidnaProxy echidnaProxy = echidnaProxies[actor];
        uint256 actorBalance = address(echidnaProxy).balance;

        uint256 ETH = getAdjustedETH(actorBalance, _ETH, MCR);
        uint256 debtChange = _debtChange;
        if (_isDebtIncrease) {
            (
                address[] memory collsIn,
                uint256[] memory amountsIn
            ) = borrowerOperations._adjustArray(_collsIn, _amountsIn, ETH);
            debtChange = getAdjustedEUSD(
                collsIn,
                amountsIn,
                uint256(_debtChange),
                MCR
            );
        }
        echidnaProxy.adjustTrovePrx(
            ETH,
            _collsIn,
            _amountsIn,
            _collsOut,
            _amountsOut,
            debtChange,
            _isDebtIncrease,
            address(0),
            address(0),
            0
        );
    }

    function adjustTroveRawExt(
        uint256 _i,
        uint256 _ETH,
        address[] memory _collsIn,
        uint256[] memory _amountsIn,
        address[] memory _collsOut,
        uint256[] memory _amountsOut,
        uint256 _debtChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint,
        uint256 _maxFee
    ) external payable {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].adjustTrovePrx(
            _ETH,
            _collsIn,
            _amountsIn,
            _collsOut,
            _amountsOut,
            _debtChange,
            _isDebtIncrease,
            _upperHint,
            _lowerHint,
            _maxFee
        );
    }

    // Pool Manager

    function provideToSPExt(
        uint256 _i,
        uint256 _amount,
        address _frontEndTag
    ) external {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].provideToSPPrx(_amount, _frontEndTag);
    }

    function withdrawFromSPExt(uint256 _i, uint256 _amount) external {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        echidnaProxies[actor].withdrawFromSPPrx(_amount);
    }

    // EUSD Token

    function transferExt(
        uint256 _i,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        return echidnaProxies[actor].transferPrx(recipient, amount);
    }

    function approveExt(
        uint256 _i,
        address spender,
        uint256 amount
    ) external returns (bool) {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        return echidnaProxies[actor].approvePrx(spender, amount);
    }

    function transferFromExt(
        uint256 _i,
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        return echidnaProxies[actor].transferFromPrx(sender, recipient, amount);
    }

    function increaseAllowanceExt(
        uint256 _i,
        address spender,
        uint256 addedValue
    ) external returns (bool) {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        return echidnaProxies[actor].increaseAllowancePrx(spender, addedValue);
    }

    function decreaseAllowanceExt(
        uint256 _i,
        address spender,
        uint256 subtractedValue
    ) external returns (bool) {
        uint256 actor = _i % NUMBER_OF_ACTORS;
        return
            echidnaProxies[actor].decreaseAllowancePrx(
                spender,
                subtractedValue
            );
    }

    // PriceFeed

    function setPriceExt(uint256 _price) external {
        bool result = priceFeedTestnet.setPrice(_price);
        assert(result);
    }

    // --------------------------
    // Invariants and properties
    // --------------------------

    function echidna_canary_number_of_troves() public view returns (bool) {
        if (numberOfTroves > 20) {
            return false;
        }

        return true;
    }

    function echidna_canary_active_pool_balance() public view returns (bool) {
        if (address(activePool).balance != 0) {
            return false;
        }
        return true;
    }

    function echidna_troves_order() external view returns (bool) {
        address currentTrove = sortedTroves.getFirst();
        address nextTrove = sortedTroves.getNext(currentTrove);
        uint256 price = priceFeedTestnet.fetchPrice();

        while (currentTrove != address(0) && nextTrove != address(0)) {
            if (
                troveManager.getCurrentICR(nextTrove, price) >
                troveManager.getCurrentICR(currentTrove, price)
            ) {
                return false;
            }
            // Uncomment to check that the condition is meaningful
            //else return false;

            currentTrove = nextTrove;
            nextTrove = sortedTroves.getNext(currentTrove);
        }

        return true;
    }

    /**
     * Status
     * Minimum debt (gas compensation)
     * Stake != 0
     */
    function echidna_trove_properties() public view returns (bool) {
        address currentTrove = sortedTroves.getFirst();
        while (currentTrove != address(0)) {
            // Status
            if (
                DataTypes.Status(troveManager.getTroveStatus(currentTrove)) !=
                DataTypes.Status.active
            ) {
                return false;
            }
            // Uncomment to check that the condition is meaningful
            //else return false;

            // Minimum debt (gas compensation)
            if (
                troveManager.getTroveDebt(currentTrove) < EUSD_GAS_COMPENSATION
            ) {
                return false;
            }
            // Uncomment to check that the condition is meaningful
            //else return false;

            // Stake != 0
            (, uint256 totalCollStake, ) = troveManager.getTroveStakes(
                currentTrove
            );
            if (totalCollStake == 0) {
                return false;
            }
            // Uncomment to check that the condition is meaningful
            //else return false;

            currentTrove = sortedTroves.getNext(currentTrove);
        }
        return true;
    }

    function echidna_ETH_balances() public view returns (bool) {
        if (address(troveManager).balance != 0) {
            return false;
        }

        if (address(borrowerOperations).balance != 0) {
            return false;
        }

        if (
            weth.balanceOf(address(activePool)) !=
            activePool.getCollateralAmount(address(weth))
        ) {
            return false;
        }

        if (
            weth.balanceOf(address(defaultPool)) !=
            defaultPool.getCollateralAmount(address(weth))
        ) {
            return false;
        }

        if (
            weth.balanceOf(address(stabilityPool)) !=
            stabilityPool.getCollateralAmount(address(weth))
        ) {
            return false;
        }

        if (address(eusdToken).balance != 0) {
            return false;
        }

        if (address(priceFeedTestnet).balance != 0) {
            return false;
        }

        if (address(sortedTroves).balance != 0) {
            return false;
        }

        return true;
    }

    function echidna_price() public view returns (bool) {
        uint256 price = priceFeedTestnet.getPrice();

        if (price == 0) {
            return false;
        }
        // Uncomment to check that the condition is meaningful
        //else return false;

        return true;
    }

    // Total EUSD matches
    function echidna_EUSD_global_balances() public view returns (bool) {
        uint256 totalSupply = eusdToken.totalSupply();
        uint256 gasPoolBalance = eusdToken.balanceOf(address(gasPool));

        uint256 activePoolBalance = activePool.getEUSDDebt();
        uint256 defaultPoolBalance = defaultPool.getEUSDDebt();
        if (totalSupply != activePoolBalance + defaultPoolBalance) {
            return false;
        }

        uint256 stabilityPoolBalance = stabilityPool.getTotalEUSDDeposits();
        address currentTrove = sortedTroves.getFirst();
        uint256 trovesBalance;
        while (currentTrove != address(0)) {
            trovesBalance += eusdToken.balanceOf(address(currentTrove));
            currentTrove = sortedTroves.getNext(currentTrove);
        }
        // we cannot state equality because tranfers are made to external addresses too
        if (
            totalSupply <= stabilityPoolBalance + trovesBalance + gasPoolBalance
        ) {
            return false;
        }

        return true;
    }

    /*
    function echidna_test() public view returns(bool) {
        return true;
    }
    */
}
