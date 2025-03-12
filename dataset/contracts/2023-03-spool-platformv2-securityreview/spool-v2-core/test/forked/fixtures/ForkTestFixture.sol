// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../../src/managers/ActionManager.sol";
import "../../../src/managers/AssetGroupRegistry.sol";
import "../../../src/managers/GuardManager.sol";
import "../../../src/managers/RiskManager.sol";
import "../../../src/managers/SmartVaultManager.sol";
import "../../../src/managers/StrategyRegistry.sol";
import "../../../src/managers/UsdPriceFeedManager.sol";
import "../../../src/MasterWallet.sol";
import "../../../src/SmartVault.sol";
import "../../../src/SmartVaultFactory.sol";
import "../../../src/Swapper.sol";
import "../../libraries/Arrays.sol";
import "../../libraries/Constants.sol";
import "../../mocks/MockStrategy.sol";
import "../../mocks/MockToken.sol";
import "../../mocks/MockPriceFeedManager.sol";
import "../../fixtures/TestFixture.sol";
import "../EthereumForkConstants.sol";

contract ForkTestFixture is TestFixture {
    IERC20Metadata internal constant tokenUSDC = IERC20Metadata(USDC);
    IERC20Metadata internal constant tokenUSDT = IERC20Metadata(USDT);
    IERC20Metadata internal constant tokenDAI = IERC20Metadata(DAI);

    MockStrategy internal strategyA;
    MockStrategy internal strategyB;
    MockStrategy internal strategyC;
    address[] internal assetGroupUSDC;
    uint256 internal assetGroupIdUSDC;

    function test_mock() external pure override {}

    function setUpBase() internal override {
        super.setUpBase();

        // set initial state
        assetGroupUSDC = Arrays.toArray(address(tokenUSDC));
        assetGroupRegistry.allowTokenBatch(assetGroupUSDC);
        assetGroupIdUSDC = assetGroupRegistry.registerAssetGroup(assetGroupUSDC);

        priceFeedManager.setExchangeRate(address(tokenUSDC), 1 * USD_DECIMALS_MULTIPLIER);
        priceFeedManager.setExchangeRate(address(tokenUSDT), 1 * USD_DECIMALS_MULTIPLIER);
        priceFeedManager.setExchangeRate(address(tokenDAI), 1 * USD_DECIMALS_MULTIPLIER);
    }

    function _dealTokens(address account) internal {
        deal(address(tokenUSDC), account, 1e18, true);
        deal(address(tokenUSDT), account, 1e18, true);
        deal(address(tokenDAI), account, 1e30, true);
    }

    function _createVault(
        uint16 managementFeePct,
        uint16 depositFeePct,
        uint256 assetGroupId,
        address[] memory strategies,
        uint256[] memory allocations
    ) internal returns (ISmartVault) {
        vm.mockCall(
            address(riskManager),
            abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
            abi.encode(allocations)
        );

        smartVault = smartVaultFactory.deploySmartVault(
            SmartVaultSpecification({
                smartVaultName: "MySmartVault",
                assetGroupId: assetGroupId,
                actions: new IAction[](0),
                actionRequestTypes: new RequestType[](0),
                guards: new GuardDefinition[][](0),
                guardRequestTypes: new RequestType[](0),
                strategies: strategies,
                strategyAllocation: uint16a16.wrap(0),
                riskTolerance: 4,
                riskProvider: riskProvider,
                managementFeePct: managementFeePct,
                depositFeePct: depositFeePct,
                allocationProvider: address(allocationProvider),
                performanceFeePct: 0,
                allowRedeemFor: true
            })
        );

        return smartVault;
    }
}
