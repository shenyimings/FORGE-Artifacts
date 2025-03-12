// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IScaledBalanceToken} from "@aave-v3-core/interfaces/IScaledBalanceToken.sol";
import {IEACAggregatorProxy} from "@aave-v3-periphery/misc/interfaces/IEACAggregatorProxy.sol";
import {ITransferStrategyBase} from "@aave-v3-periphery/rewards/interfaces/ITransferStrategyBase.sol";

import {RewardsDataTypes} from "@aave-v3-periphery/rewards/libraries/RewardsDataTypes.sol";

import {PullRewardsTransferStrategyMock} from "test/mocks/PullRewardsTransferStrategyMock.sol";
import "test/helpers/IntegrationTest.sol";

contract TestIntegrationRewardsManager is IntegrationTest {
    using ConfigLib for Config;

    // From the rewards manager
    event Accrued(
        address indexed asset, address indexed reward, address indexed user, uint256 assetIndex, uint256 rewardsAccrued
    );

    uint256 internal constant NB_REWARDS = 2;

    address internal aDai;
    address internal vDai;
    address internal aUsdc;
    address internal vUsdc;

    address[] internal assets;
    address[NB_REWARDS] internal expectedRewardTokens;
    uint256[NB_REWARDS] internal noAccruedRewards = [0, 0];
    RewardsDataTypes.RewardsConfigInput[] rewardsConfig;

    function setUp() public virtual override {
        super.setUp();

        aDai = testMarkets[dai].aToken;
        vDai = testMarkets[dai].variableDebtToken;
        aUsdc = testMarkets[usdc].aToken;
        vUsdc = testMarkets[usdc].variableDebtToken;
        assets = [aDai, vDai, aUsdc, vUsdc];
        expectedRewardTokens = [wNative, link];

        _setUpRewardsConfig();
    }

    function _setUpRewardsConfig() internal {
        ITransferStrategyBase transferStrategy = new PullRewardsTransferStrategyMock();
        for (uint256 i; i < expectedRewardTokens.length; ++i) {
            address rewardToken = expectedRewardTokens[i];

            deal(rewardToken, address(transferStrategy), type(uint96).max);

            IEACAggregatorProxy rewardOracle = IEACAggregatorProxy(oracle.getSourceOfAsset(rewardToken));

            rewardsConfig.push(
                RewardsDataTypes.RewardsConfigInput({
                    emissionPerSecond: 0.001 ether,
                    totalSupply: 0,
                    distributionEnd: 1711944000,
                    asset: assets[i * 2],
                    reward: rewardToken,
                    transferStrategy: transferStrategy,
                    rewardOracle: rewardOracle
                })
            );
            rewardsConfig.push(
                RewardsDataTypes.RewardsConfigInput({
                    emissionPerSecond: 0.001 ether,
                    totalSupply: 0,
                    distributionEnd: 1711944000,
                    asset: assets[i * 2 + 1],
                    reward: rewardToken,
                    transferStrategy: transferStrategy,
                    rewardOracle: rewardOracle
                })
            );
        }

        vm.prank(emissionManager);
        rewardsController.configureAssets(rewardsConfig);
    }

    function _assertClaimRewards(
        address[] memory rewardTokens,
        uint256[] memory amounts,
        uint256[] memory rewardBalancesBefore,
        uint256[NB_REWARDS] memory expectedAccruedRewards,
        string memory suffix
    ) internal {
        assertEq(rewardTokens.length, NB_REWARDS, string.concat("rewardTokens length", " ", suffix));
        assertEq(amounts.length, NB_REWARDS, string.concat("amounts length", " ", suffix));

        for (uint256 i; i < NB_REWARDS; ++i) {
            address rewardToken = expectedRewardTokens[i];
            uint256 accruedRewards = expectedAccruedRewards[i];

            string memory index = string.concat("[", vm.toString(i), "]");

            assertEq(rewardTokens[i], rewardToken, string.concat("rewardTokens", index, " ", suffix));
            assertEq(amounts[i], accruedRewards, string.concat("amounts", index, " ", suffix));
            assertEq(
                ERC20(rewardToken).balanceOf(address(user)),
                rewardBalancesBefore[i] + accruedRewards,
                string.concat("balance", index, " ", suffix)
            );
        }
    }

    function testGetMorpho() public {
        assertEq(rewardsManager.MORPHO(), address(morpho));
    }

    function testGetRewardsController() public {
        assertEq(rewardsManager.REWARDS_CONTROLLER(), address(rewardsController));
    }

    function testGetRewardData(uint256 amount, uint256 blocks) public {
        amount = _boundSupply(testMarkets[dai], amount);
        blocks = _boundBlocks(blocks);
        (uint256 startingIndex, uint256 index, uint256 lastUpdateTimestamp) =
            rewardsManager.getRewardData(aDai, wNative);

        assertEq(startingIndex, 0, "starting index before");
        assertEq(index, 0, "index before");
        assertEq(lastUpdateTimestamp, 0, "lastUpdateTimestamp before");

        user.approve(dai, amount);
        user.supply(dai, amount);

        uint256 expectedIndex = rewardsManager.getAssetIndex(aDai, wNative);
        uint256 expectedTimestamp = block.timestamp;

        (startingIndex, index, lastUpdateTimestamp) = rewardsManager.getRewardData(aDai, wNative);
        assertEq(startingIndex, expectedIndex, "starting index after supply");
        assertEq(index, expectedIndex, "index after supply");
        assertEq(lastUpdateTimestamp, expectedTimestamp, "lastUpdateTimestamp after supply");

        _forward(blocks);

        (startingIndex, index, lastUpdateTimestamp) = rewardsManager.getRewardData(aDai, wNative);
        assertEq(startingIndex, expectedIndex, "starting index after forward");
        assertEq(index, expectedIndex, "index after forward");
        assertEq(lastUpdateTimestamp, expectedTimestamp, "lastUpdateTimestamp after forward");
    }

    function testGetUserData(uint256 amount, uint256 blocks) public {
        amount = _boundSupply(testMarkets[dai], amount);
        blocks = _boundBlocks(blocks);
        (uint256 index, uint256 accrued) = rewardsManager.getUserData(aDai, wNative, address(user));

        assertEq(index, 0, "index before");
        assertEq(accrued, 0, "accrued before");

        user.approve(dai, amount);
        user.supply(dai, amount);

        (index, accrued) = rewardsManager.getUserData(aDai, wNative, address(user));

        // The user's first index is expected to be zero because on the first reward update,
        // the update is bypassed as the reward starting index is set to what the user's asset index would be.
        assertEq(index, 0, "index after supply");
        assertEq(accrued, 0, "accrued after supply");

        _forward(blocks);

        user.approve(dai, amount);
        user.supply(dai, amount);

        uint256 expectedIndex = rewardsManager.getAssetIndex(aDai, wNative);
        uint256 expectedAccrued = rewardsManager.getUserRewards(assets, address(user), wNative);

        (index, accrued) = rewardsManager.getUserData(aDai, wNative, address(user));

        assertEq(index, expectedIndex, "index after forward");
        assertEq(accrued, expectedAccrued, "accrued after forward");

        user.withdraw(dai, type(uint256).max);

        expectedIndex = rewardsManager.getAssetIndex(aDai, wNative);
        expectedAccrued = rewardsManager.getUserRewards(assets, address(user), wNative);

        (index, accrued) = rewardsManager.getUserData(aDai, wNative, address(user));

        assertEq(index, expectedIndex, "index after withdraw");
        assertEq(accrued, expectedAccrued, "accrued after withdraw");
    }

    struct RewardTest {
        uint256 collateralDai;
        uint256 collateralUsdc;
        uint256 supplyDai;
        uint256 supplyUsdc;
        uint256 borrowDai;
        uint256 blocks;
    }

    function testGetUserRewards(RewardTest memory params) public {
        params.collateralDai = _boundSupply(testMarkets[dai], params.collateralDai);
        params.collateralUsdc = _boundSupply(testMarkets[usdc], params.collateralUsdc);
        params.supplyDai = _boundSupply(testMarkets[dai], params.supplyDai);
        params.supplyUsdc = _boundSupply(testMarkets[usdc], params.supplyUsdc);
        params.borrowDai = _boundBorrow(testMarkets[dai], params.borrowDai);
        params.blocks = _boundBlocks(params.blocks);

        // Initialize asset indexes for each asset
        hacker.approve(dai, 1000);
        hacker.supplyCollateral(dai, 1000);
        hacker.approve(usdc, 1000);
        hacker.supplyCollateral(usdc, 1000);
        hacker.borrow(dai, 100);
        hacker.borrow(usdc, 100);

        _forward(1);

        user.approve(dai, params.collateralDai);
        user.supplyCollateral(dai, params.collateralDai);
        user.approve(usdc, params.collateralUsdc);
        user.supplyCollateral(usdc, params.collateralUsdc);
        user.approve(dai, params.supplyDai);
        user.supply(dai, params.supplyDai);
        user.approve(usdc, params.supplyUsdc);
        user.supply(usdc, params.supplyUsdc);
        _borrowWithoutCollateral(address(user), testMarkets[dai], params.borrowDai, address(user), address(user), 0);

        uint256 scaledCollateralDai = morpho.scaledCollateralBalance(dai, address(user));
        uint256 scaledCollateralUsdc = morpho.scaledCollateralBalance(usdc, address(user));
        uint256 scaledSupplyDai = morpho.scaledPoolSupplyBalance(dai, address(user));
        uint256 scaledSupplyUsdc = morpho.scaledPoolSupplyBalance(usdc, address(user));
        uint256 scaledBorrowDai = morpho.scaledPoolBorrowBalance(dai, address(user));

        (uint256 accrued) = rewardsManager.getUserRewards(assets, address(user), wNative);
        assertEq(accrued, 0, "accrued 1");

        _forward(params.blocks);

        uint256 expectedAccrued = _calculateRewardByAsset(address(user), scaledCollateralDai, aDai, wNative);
        expectedAccrued += _calculateRewardByAsset(address(user), scaledSupplyDai, aDai, wNative);
        expectedAccrued += _calculateRewardByAsset(address(user), scaledBorrowDai, vDai, wNative);
        expectedAccrued += _calculateRewardByAsset(address(user), scaledCollateralUsdc, aUsdc, wNative);
        expectedAccrued += _calculateRewardByAsset(address(user), scaledSupplyUsdc, aUsdc, wNative);

        accrued = rewardsManager.getUserRewards(assets, address(user), wNative);

        assertApproxEqAbs(accrued, expectedAccrued, 5, "accrued 2");
    }

    function _calculateRewardByAsset(address user, uint256 scaledBalance, address asset, address reward)
        internal
        view
        returns (uint256)
    {
        uint256 assetUnit = 10 ** rewardsController.getAssetDecimals(asset);
        uint256 userIndex = rewardsManager.getUserAssetIndex(user, asset, reward);
        uint256 assetIndex = rewardsManager.getAssetIndex(asset, reward);

        return scaledBalance * (assetIndex - userIndex) / assetUnit;
    }

    function testGetUserAssetIndex(uint256 amount, uint256 blocks) public {
        amount = _boundSupply(testMarkets[dai], amount);
        blocks = _boundBlocks(blocks);

        uint256 startingAssetIndex = rewardsManager.getAssetIndex(aDai, wNative);

        // The case where rewards manager has never been updated.
        uint256 index = rewardsManager.getUserAssetIndex(address(user), aDai, wNative);
        assertEq(index, 0, "index 1");

        // The case where the rewards manager has been updated and the user's asset index has not.
        user.approve(dai, amount);
        user.supplyCollateral(dai, amount);
        index = rewardsManager.getUserAssetIndex(address(user), aDai, wNative);
        assertEq(index, startingAssetIndex, "index 2");

        _forward(blocks);

        // The user asset index should be the same in future blocks without an update call.
        index = rewardsManager.getUserAssetIndex(address(user), aDai, wNative);
        assertEq(index, startingAssetIndex, "index 3");

        // After an update call, the user's asset index should be updated to the current asset index.
        user.approve(dai, amount);
        user.supplyCollateral(dai, amount);

        index = rewardsManager.getUserAssetIndex(address(user), aDai, wNative);
        assertEq(index, rewardsManager.getAssetIndex(aDai, wNative), "index 4");
    }

    function testGetAssetIndex(uint256 blocks) public {
        blocks = _boundBlocks(blocks);
        uint256 assetUnit = 10 ** rewardsController.getAssetDecimals(aDai);
        uint256 currentTimestamp = block.timestamp;

        (uint256 rewardIndex, uint256 emissionPerSecond, uint256 lastUpdateTimestamp, uint256 distributionEnd) =
            rewardsController.getRewardsData(aDai, wNative);
        uint256 totalEmitted = emissionPerSecond * (currentTimestamp - lastUpdateTimestamp) * assetUnit
            / IScaledBalanceToken(aDai).scaledTotalSupply();

        assertEq(rewardsManager.getAssetIndex(aDai, wNative), rewardIndex + totalEmitted, "index 1");

        _forward(blocks);

        currentTimestamp = block.timestamp;

        currentTimestamp = currentTimestamp > distributionEnd ? distributionEnd : currentTimestamp;
        totalEmitted = emissionPerSecond * (currentTimestamp - lastUpdateTimestamp) * assetUnit
            / IScaledBalanceToken(aDai).scaledTotalSupply();

        assertEq(rewardsManager.getAssetIndex(aDai, wNative), rewardIndex + totalEmitted, "index 2");
    }

    function testClaimRewardsRevertIfPaused() public {
        morpho.setIsClaimRewardsPaused(true);

        vm.expectRevert(Errors.ClaimRewardsPaused.selector);
        morpho.claimRewards(assets, address(this));
    }

    function testClaimRewardsRevertIfRewardsManagerZero() public {
        morpho.setRewardsManager(address(0));

        vm.expectRevert(Errors.AddressIsZero.selector);
        morpho.claimRewards(assets, address(this));
    }

    function testClaimRewardsWhenSupplyingPool(uint256 amount, uint256 blocks) public {
        amount = _boundSupply(testMarkets[dai], amount);
        blocks = _boundBlocks(blocks);

        user.approve(dai, amount);
        user.supply(dai, amount);

        _forward(blocks);

        uint256 accruedRewards = rewardsManager.getUserRewards(assets, address(user), wNative);

        assertGt(accruedRewards, 0, "accruedRewards > 0");

        uint256[] memory rewardBalancesBefore = new uint256[](NB_REWARDS);
        rewardBalancesBefore[0] = ERC20(wNative).balanceOf(address(user));
        rewardBalancesBefore[1] = ERC20(link).balanceOf(address(user));

        vm.expectEmit(true, true, true, true);
        emit Accrued(
            aDai, wNative, address(user), rewardsManager.getAssetIndex(testMarkets[dai].aToken, wNative), accruedRewards
        );
        vm.expectEmit(true, true, true, true);
        emit Events.RewardsClaimed(address(this), address(user), wNative, accruedRewards);

        (address[] memory rewardTokens, uint256[] memory amounts) = morpho.claimRewards(assets, address(user));

        _assertClaimRewards(rewardTokens, amounts, rewardBalancesBefore, [accruedRewards, 0], "(1)");

        user.withdraw(dai, type(uint256).max);

        _forward(blocks);

        accruedRewards = rewardsManager.getUserRewards(assets, address(user), wNative);

        assertEq(accruedRewards, 0, "accruedRewards == 0");

        rewardBalancesBefore[0] = ERC20(wNative).balanceOf(address(user));

        (rewardTokens, amounts) = morpho.claimRewards(assets, address(user));

        _assertClaimRewards(rewardTokens, amounts, rewardBalancesBefore, noAccruedRewards, "(2)");
    }

    function testClaimRewardsWhenSupplyingCollateral(uint256 amount, uint256 blocks) public {
        amount = _boundSupply(testMarkets[dai], amount);
        blocks = _boundBlocks(blocks);

        user.approve(dai, amount);
        user.supplyCollateral(dai, amount);

        _forward(blocks);

        uint256 accruedRewards = rewardsManager.getUserRewards(assets, address(user), wNative);

        assertGt(accruedRewards, 0, "accruedRewards > 0");

        uint256[] memory rewardBalancesBefore = new uint256[](NB_REWARDS);
        rewardBalancesBefore[0] = ERC20(wNative).balanceOf(address(user));
        rewardBalancesBefore[1] = ERC20(link).balanceOf(address(user));

        vm.expectEmit(true, true, true, true);
        emit Accrued(aDai, wNative, address(user), rewardsManager.getAssetIndex(aDai, wNative), accruedRewards);
        vm.expectEmit(true, true, true, true);
        emit Events.RewardsClaimed(address(this), address(user), wNative, accruedRewards);

        (address[] memory rewardTokens, uint256[] memory amounts) = morpho.claimRewards(assets, address(user));

        _assertClaimRewards(rewardTokens, amounts, rewardBalancesBefore, [accruedRewards, 0], "(1)");

        user.withdrawCollateral(dai, type(uint256).max);

        _forward(blocks);

        accruedRewards = rewardsManager.getUserRewards(assets, address(user), wNative);

        assertEq(accruedRewards, 0, "accruedRewards == 0");

        rewardBalancesBefore[0] = ERC20(wNative).balanceOf(address(user));

        (rewardTokens, amounts) = morpho.claimRewards(assets, address(user));

        _assertClaimRewards(rewardTokens, amounts, rewardBalancesBefore, noAccruedRewards, "(2)");
    }

    function testClaimRewardsWhenBorrowingPool(uint256 amount, uint256 blocks) public {
        amount = _boundBorrow(testMarkets[dai], amount);
        blocks = _boundBlocks(blocks);

        _borrowWithCollateral(
            address(user), testMarkets[wbtc], testMarkets[dai], amount, address(user), address(user), 0
        );

        _forward(blocks);

        uint256 accruedRewards = rewardsManager.getUserRewards(assets, address(user), wNative);

        assertGt(accruedRewards, 0, "accruedRewards > 0");

        uint256[] memory rewardBalancesBefore = new uint256[](NB_REWARDS);
        rewardBalancesBefore[0] = ERC20(wNative).balanceOf(address(user));
        rewardBalancesBefore[1] = ERC20(link).balanceOf(address(user));

        vm.expectEmit(true, true, true, true);
        emit Accrued(vDai, wNative, address(user), rewardsManager.getAssetIndex(vDai, wNative), accruedRewards);
        vm.expectEmit(true, true, true, true);
        emit Events.RewardsClaimed(address(this), address(user), wNative, accruedRewards);

        (address[] memory rewardTokens, uint256[] memory amounts) = morpho.claimRewards(assets, address(user));

        _assertClaimRewards(rewardTokens, amounts, rewardBalancesBefore, [accruedRewards, 0], "(1)");

        user.approve(dai, type(uint256).max);
        user.repay(dai, type(uint256).max);

        _forward(blocks);

        accruedRewards = rewardsManager.getUserRewards(assets, address(user), wNative);

        assertEq(accruedRewards, 0, "accruedRewards == 0");

        rewardBalancesBefore[0] = ERC20(wNative).balanceOf(address(user));

        (rewardTokens, amounts) = morpho.claimRewards(assets, address(user));

        _assertClaimRewards(rewardTokens, amounts, rewardBalancesBefore, noAccruedRewards, "(2)");
    }

    function testClaimRewardsWhenSupplyingAndBorrowing(uint256 supplyAmount, uint256 borrowAmount, uint256 blocks)
        public
    {
        supplyAmount = _boundSupply(testMarkets[usdc], supplyAmount);
        borrowAmount = _boundBorrow(testMarkets[dai], borrowAmount);
        blocks = _boundBlocks(blocks);

        user.approve(usdc, supplyAmount);
        user.supply(usdc, supplyAmount);

        _borrowWithoutCollateral(address(user), testMarkets[dai], borrowAmount, address(user), address(user), 0);

        _forward(blocks);

        (address[] memory rewardsList, uint256[] memory unclaimed) =
            rewardsManager.getAllUserRewards(assets, address(user));

        assertEq(rewardsList[0], wNative, "rewardsList[0]");
        assertEq(rewardsList[1], link, "rewardsList[1]");
        assertGt(unclaimed[0], 0, "unclaimed[0] > 0");
        assertGt(unclaimed[1], 0, "unclaimed[1] > 0");

        uint256[] memory rewardBalancesBefore = new uint256[](NB_REWARDS);
        rewardBalancesBefore[0] = ERC20(wNative).balanceOf(address(user));
        rewardBalancesBefore[1] = ERC20(link).balanceOf(address(user));

        vm.expectEmit(true, true, true, true);
        emit Accrued(vDai, wNative, address(user), rewardsManager.getAssetIndex(vDai, wNative), unclaimed[0]);
        vm.expectEmit(true, true, true, true);
        emit Accrued(aUsdc, link, address(user), rewardsManager.getAssetIndex(aUsdc, link), unclaimed[1]);
        vm.expectEmit(true, true, true, true);
        emit Events.RewardsClaimed(address(this), address(user), wNative, unclaimed[0]);
        vm.expectEmit(true, true, true, true);
        emit Events.RewardsClaimed(address(this), address(user), link, unclaimed[1]);

        (address[] memory rewardTokens, uint256[] memory amounts) = morpho.claimRewards(assets, address(user));

        _assertClaimRewards(rewardTokens, amounts, rewardBalancesBefore, [unclaimed[0], unclaimed[1]], "(1)");

        user.approve(dai, type(uint256).max);
        user.repay(dai, type(uint256).max);
        user.withdraw(usdc, type(uint256).max);

        _forward(blocks);

        (rewardsList, unclaimed) = rewardsManager.getAllUserRewards(assets, address(user));

        assertEq(unclaimed[0], 0, "unclaimed[0] == 0");
        assertEq(unclaimed[1], 0, "unclaimed[1] == 0");

        rewardBalancesBefore[0] = ERC20(wNative).balanceOf(address(user));
        rewardBalancesBefore[1] = ERC20(link).balanceOf(address(user));

        (rewardTokens, amounts) = morpho.claimRewards(assets, address(user));

        _assertClaimRewards(rewardTokens, amounts, rewardBalancesBefore, noAccruedRewards, "(2)");
    }

    function testClaimRewardsWhenSpeedSetZero(uint256 amount, uint256 blocks) public {
        amount = _boundSupply(testMarkets[dai], amount);
        blocks = (_boundBlocks(blocks) + 1) / 2;

        user.approve(dai, amount);
        user.supplyCollateral(dai, amount);

        _forward(blocks);

        uint256 rewardsBefore = rewardsManager.getUserRewards(assets, address(user), wNative);

        address[] memory rewards = new address[](1);
        rewards[0] = wNative;
        uint88[] memory speeds = new uint88[](1);
        speeds[0] = 0;

        vm.prank(emissionManager);
        rewardsController.setEmissionPerSecond(aDai, rewards, speeds);

        uint256 rewardsAfter = rewardsManager.getUserRewards(assets, address(user), wNative);

        assertEq(rewardsAfter, rewardsBefore, "rewardsAfter != rewardsBefore (1)");

        _forward(blocks);

        rewardsAfter = rewardsManager.getUserRewards(assets, address(user), wNative);

        assertEq(rewardsAfter, rewardsBefore, "rewardsAfter != rewardsBefore (2)");

        uint256[] memory rewardBalancesBefore = new uint256[](NB_REWARDS);
        rewardBalancesBefore[0] = ERC20(wNative).balanceOf(address(user));
        rewardBalancesBefore[1] = ERC20(link).balanceOf(address(user));

        vm.expectEmit(true, true, true, true);
        emit Accrued(aDai, wNative, address(user), rewardsManager.getAssetIndex(aDai, wNative), rewardsAfter);
        vm.expectEmit(true, true, true, true);
        emit Events.RewardsClaimed(address(this), address(user), wNative, rewardsAfter);

        (address[] memory rewardTokens, uint256[] memory amounts) = morpho.claimRewards(assets, address(user));

        _assertClaimRewards(rewardTokens, amounts, rewardBalancesBefore, [rewardsAfter, 0], "");
    }
}
