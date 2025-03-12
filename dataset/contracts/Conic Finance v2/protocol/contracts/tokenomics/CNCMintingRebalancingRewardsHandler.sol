// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/tokenomics/ICNCMintingRebalancingRewardsHandler.sol";
import "../../interfaces/tokenomics/IInflationManager.sol";
import "../../interfaces/tokenomics/ICNCToken.sol";
import "../../interfaces/pools/IConicPool.sol";
import "../../libraries/ScaledMath.sol";

contract CNCMintingRebalancingRewardsHandler is
    ICNCMintingRebalancingRewardsHandler,
    Ownable,
    Initializable
{
    using SafeERC20 for IERC20;
    using ScaledMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev the maximum amount of CNC that can be minted for rebalancing rewards
    uint256 internal constant _MAX_REBALANCING_REWARDS = 1_900_000e18; // 19% of total supply

    /// @dev gives out 5 dollars per 1 hour (assuming 1 CNC = 6 USD) for every 10,000 USD in TVL that needs to be shifted
    uint256 internal constant _INITIAL_REBALANCING_REWARD_PER_DOLLAR_PER_SECOND =
        5e18 / uint256(3600 * 1 * 10_000 * 6);

    IController public immutable override controller;

    ICNCToken public immutable cnc;

    ICNCMintingRebalancingRewardsHandler public immutable previousRewardsHandler;
    uint256 public override totalCncMinted;
    uint256 public override cncRebalancingRewardPerDollarPerSecond;

    bool internal _isInternal;

    modifier onlyInflationManager() {
        require(
            msg.sender == address(controller.inflationManager()),
            "only InflationManager can call this function"
        );
        _;
    }

    constructor(
        IController _controller,
        ICNCToken _cnc,
        ICNCMintingRebalancingRewardsHandler _previousRewardsHandler
    ) {
        cncRebalancingRewardPerDollarPerSecond = _INITIAL_REBALANCING_REWARD_PER_DOLLAR_PER_SECOND;
        controller = _controller;
        previousRewardsHandler = _previousRewardsHandler;
        cnc = _cnc;
    }

    function initialize() external onlyOwner initializer {
        totalCncMinted = previousRewardsHandler.totalCncMinted();
    }

    function setCncRebalancingRewardPerDollarPerSecond(
        uint256 _cncRebalancingRewardPerDollarPerSecond
    ) external override onlyOwner {
        cncRebalancingRewardPerDollarPerSecond = _cncRebalancingRewardPerDollarPerSecond;
        emit SetCncRebalancingRewardPerDollarPerSecond(_cncRebalancingRewardPerDollarPerSecond);
    }

    function _distributeRebalancingRewards(address pool, address account, uint256 amount) internal {
        if (totalCncMinted + amount > _MAX_REBALANCING_REWARDS) {
            amount = _MAX_REBALANCING_REWARDS - totalCncMinted;
        }
        if (amount == 0) return;
        uint256 mintedAmount = cnc.mint(account, amount);
        if (mintedAmount > 0) {
            totalCncMinted += mintedAmount;
            emit RebalancingRewardDistributed(pool, account, address(cnc), mintedAmount);
        }
    }

    function handleRebalancingRewards(
        IConicPool conicPool,
        address account,
        uint256 deviationBefore,
        uint256 deviationAfter
    ) external onlyInflationManager {
        _handleRebalancingRewards(conicPool, account, deviationBefore, deviationAfter);
    }

    function _handleRebalancingRewards(
        IConicPool conicPool,
        address account,
        uint256 deviationBefore,
        uint256 deviationAfter
    ) internal {
        if (_isInternal) return;
        uint256 cncRewardAmount = computeRebalancingRewards(
            address(conicPool),
            deviationBefore,
            deviationAfter
        );
        _distributeRebalancingRewards(address(conicPool), account, cncRewardAmount);
    }

    /// @dev this computes how much CNC a user should get when depositing
    /// this does not check whether the rewards should still be distributed
    /// amount CNC = t * CNC/s * (1 - (Δdeviation / initialDeviation))
    /// where
    /// CNC/s: the amount of CNC per second to distributed for rebalancing
    /// t: the time elapsed since the weight update
    /// Δdeviation: the deviation difference caused by this deposit
    /// initialDeviation: the deviation after updating weights
    /// @return the amount of CNC to give to the user as reward
    function computeRebalancingRewards(
        address conicPool,
        uint256 deviationBefore,
        uint256 deviationAfter
    ) public view override returns (uint256) {
        if (deviationBefore < deviationAfter) return 0;
        uint8 decimals = IConicPool(conicPool).underlying().decimals();
        uint256 deviationDelta = deviationBefore - deviationAfter;
        uint256 lastWeightUpdate = controller.lastWeightUpdate(conicPool);
        uint256 elapsedSinceUpdate = uint256(block.timestamp) - lastWeightUpdate;
        return
            (elapsedSinceUpdate * cncRebalancingRewardPerDollarPerSecond).mulDown(
                deviationDelta.convertScale(decimals, 18)
            );
    }

    function rebalance(
        address conicPool,
        uint256 underlyingAmount,
        uint256 minUnderlyingReceived,
        uint256 minCNCReceived
    ) external override returns (uint256 underlyingReceived, uint256 cncReceived) {
        require(controller.isPool(conicPool), "not a pool");
        IConicPool conicPool_ = IConicPool(conicPool);
        bool rebalancingRewardActive = conicPool_.rebalancingRewardActive();
        IERC20 underlying = conicPool_.underlying();
        require(underlying.balanceOf(msg.sender) >= underlyingAmount, "insufficient underlying");
        uint256 deviationBefore = conicPool_.computeTotalDeviation();
        underlying.safeTransferFrom(msg.sender, address(this), underlyingAmount);
        underlying.safeApprove(conicPool, underlyingAmount);
        _isInternal = true;
        uint256 lpTokenAmount = conicPool_.deposit(underlyingAmount, 0, false);
        _isInternal = false;
        underlyingReceived = conicPool_.withdraw(lpTokenAmount, 0);
        require(underlyingReceived >= minUnderlyingReceived, "insufficient underlying received");
        uint256 cncBefore = cnc.balanceOf(msg.sender);

        // Only distribute rebalancing rewards if active
        if (rebalancingRewardActive) {
            uint256 deviationAfter = conicPool_.computeTotalDeviation();
            _handleRebalancingRewards(conicPool_, msg.sender, deviationBefore, deviationAfter);
        }

        cncReceived = cnc.balanceOf(msg.sender) - cncBefore;
        require(cncReceived >= minCNCReceived, "insufficient CNC received");
        underlying.safeTransfer(msg.sender, underlyingReceived);
    }

    /// @notice switches the minting rebalancing reward handler by granting the new one minting rights
    /// and renouncing his own
    /// `InflationManager.removePoolRebalancingRewardHandler` should be called on every pool before this is called
    /// this should typically be done as a single batched governance action
    /// The same governance action should also call `InflationManager.addPoolRebalancingRewardHandler` for each pool
    /// passing in `newRebalancingRewardsHandler` so that the whole operation is atomic
    /// @param newRebalancingRewardsHandler the address of the new rebalancing rewards handler
    function switchMintingRebalancingRewardsHandler(
        address newRebalancingRewardsHandler
    ) external onlyOwner {
        address[] memory pools = controller.listPools();
        for (uint256 i; i < pools.length; i++) {
            require(
                !controller.inflationManager().hasPoolRebalancingRewardHandlers(
                    pools[i],
                    address(this)
                ),
                "handler is still registered for a pool"
            );
        }
        cnc.addMinter(newRebalancingRewardsHandler);
        cnc.renounceMinterRights();
    }
}
