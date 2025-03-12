// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./IntegrationTest.sol";

contract ProductionTest is IntegrationTest {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using TestMarketLib for TestMarket;
    using ConfigLib for Config;

    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function _rpcAlias() internal pure override returns (string memory) {
        return "tenderly";
    }

    function _fork() internal override {
        string memory rpcUrl = vm.rpcUrl(_rpcAlias());

        forkId = vm.createSelectFork(rpcUrl);
        vm.chainId(config.getChainId());
    }

    function _loadConfig() internal override {
        super._loadConfig();

        morpho = IMorpho(payable(config.getMorphoEth()));
        morphoProxy = TransparentUpgradeableProxy(payable(address(morpho)));

        rewardsManager = IRewardsManager(morpho.rewardsManager());
        positionsManager = IPositionsManager(morpho.positionsManager());
        morphoImpl = IMorpho(address(uint160(uint256(vm.load(address(morpho), _IMPLEMENTATION_SLOT)))));

        proxyAdmin = ProxyAdmin(address(uint160(uint256(vm.load(address(morpho), _ADMIN_SLOT)))));

        allUnderlyings = morpho.marketsCreated();
        eModeCategoryId = uint8(morpho.eModeCategoryId());
    }

    function _deploy() internal override {}

    function _createTestMarket(address underlying, uint16, uint16) internal override {
        TestMarket storage market = testMarkets[underlying];
        Types.Market memory morphoMarket = morpho.market(underlying);
        DataTypes.ReserveConfigurationMap memory configuration = pool.getConfiguration(underlying);

        market.underlying = underlying;
        market.aToken = morphoMarket.aToken;
        market.variableDebtToken = morphoMarket.variableDebtToken;
        market.stableDebtToken = morphoMarket.stableDebtToken;
        market.symbol = ERC20(underlying).symbol();
        market.reserveFactor = morphoMarket.reserveFactor;
        market.p2pIndexCursor = morphoMarket.p2pIndexCursor;
        market.price = oracle.getAssetPrice(underlying); // Price is constant, equal to price at fork block number.

        (market.ltv, market.lt, market.liquidationBonus, market.decimals,,) = configuration.getParams();

        market.minAmount = (MIN_USD_AMOUNT * 10 ** market.decimals) / market.price;
        market.maxAmount = (MAX_USD_AMOUNT * 10 ** market.decimals) / market.price;

        // Disable supply & borrow caps for all created markets.
        poolAdmin.setSupplyCap(underlying, 0);
        poolAdmin.setBorrowCap(underlying, 0);
        market.supplyCap = type(uint256).max;
        market.borrowCap = type(uint256).max;

        market.eModeCategoryId = uint8(configuration.getEModeCategory());
        market.eModeCategory = pool.getEModeCategoryData(market.eModeCategoryId);

        market.isInEMode = eModeCategoryId == 0 || eModeCategoryId == market.eModeCategoryId;
        market.isCollateral =
            market.getLt(eModeCategoryId) > 0 && configuration.getDebtCeiling() == 0 && morphoMarket.isCollateral;
        market.isBorrowable = configuration.getBorrowingEnabled() && !configuration.getSiloedBorrowing();

        vm.label(morphoMarket.aToken, string.concat("a", market.symbol));
        vm.label(morphoMarket.variableDebtToken, string.concat("vd", market.symbol));
        vm.label(morphoMarket.stableDebtToken, string.concat("sd", market.symbol));

        if (market.isCollateral) {
            collateralUnderlyings.push(underlying);
        }

        if (market.isBorrowable) {
            if (market.isInEMode) borrowableInEModeUnderlyings.push(underlying);
            else borrowableNotInEModeUnderlyings.push(underlying);
        }
    }
}
