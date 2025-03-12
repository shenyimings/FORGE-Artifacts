// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./ConicTest.sol";
import "../interfaces/vendor/IBooster.sol";

contract ConicPoolBaseTest is ConicTest {
    Controller public controller;
    CNCLockerV2 public locker;
    CNCMintingRebalancingRewardsHandler public rewardsHandler;
    IInflationManager public inflationManager;
    ILpTokenStaker public lpTokenStaker;
    ICNCToken cnc;

    function setUp() public virtual override {
        super.setUp();
        _setFork(mainnetFork);
        _initializeContracts();
    }

    function _initializeContracts() internal {
        controller = _createAndInitializeController();
        inflationManager = controller.inflationManager();
        lpTokenStaker = controller.lpTokenStaker();
        cnc = ICNCToken(controller.cncToken());
        rewardsHandler = _createRebalancingRewardsHandler(controller);
        locker = _createLockerV2(controller);
    }

    function _setWeights(address pool, IConicPool.PoolWeight[] memory weights) internal {
        IController.WeightUpdate memory weightUpdate = IController.WeightUpdate({
            conicPoolAddress: pool,
            weights: weights
        });
        controller.updateWeights(weightUpdate);
    }

    function _ensureWeightsSumTo1(IConicPool pool) internal {
        IConicPool.PoolWeight[] memory weights = pool.getWeights();
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            totalWeight += weights[i].weight;
        }
        assertEq(totalWeight, 1e18);
    }
}
