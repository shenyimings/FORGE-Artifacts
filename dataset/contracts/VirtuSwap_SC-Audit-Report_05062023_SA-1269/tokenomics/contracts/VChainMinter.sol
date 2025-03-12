// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IVStaker.sol";
import "./interfaces/IVChainMinter.sol";
import "./interfaces/IVTokenomicsParams.sol";
import "./VeVrsw.sol";

/**
 * @title vChainMinter
 * @dev This contract is responsible for distributing VRSW ang veVRSW tokens to stakers
 */
contract VChainMinter is IVChainMinter, Ownable {
    struct StakerInfo {
        uint128 totalAllocated; // Total amount of VRSW tokens allocated to the staker
        uint128 lastAvailable; // The snapshot of the availableTokens
    }

    struct PartnerTokenInfo {
        uint128 from; // Timestamp of the start of the partner token distribution
        uint128 duration; // The duration of the partner token distribution
        uint128 amount; // Amount to distribute in time range [from; from + duration]
        uint128 distributedAmount; // Amount distributed before
    }

    uint256 public constant ALLOCATION_POINTS_FACTOR = 1000000;

    // number of VRSW tokens allocated for the current epoch
    uint256 public currentEpochBalance;

    // number of VRSW tokens allocated for the next epoch
    uint256 public nextEpochBalance;

    // current epoch duration (in seconds)
    uint32 public epochDuration;

    // the time (in seconds) before the next epoch to transfer the necessary
    // amount of VRSW tokens for the next epoch to distribute
    uint32 public epochPreparationTime;

    // the next epoch duration (in seconds)
    // if the value is zero then the next epoch duration is the same as the current
    // epoch duration
    uint32 public nextEpochDuration;

    // the next epoch preparation time (in seconds)
    // if the value is zero then the next epoch preparation time is the same as
    // the current epoch preparation time
    uint32 public nextEpochPreparationTime;

    // the timestamp of the current epoch start (in seconds)
    uint32 public startEpochTime;

    // balance of VRSW tokens when the current epoch started
    uint256 public startEpochSupply;

    // total allocation points currently (must be always less than or equal to ALLOCATION_POINTS_FACTOR)
    uint256 public totalAllocationPoints;

    // stakers info
    mapping(address => StakerInfo) public stakers;

    // allocation points of stakers
    mapping(address => uint256) public allocationPoints;

    // partner tokens list per pool
    mapping(address => address[]) public partnerTokens;

    // partner tokens info per
    mapping(address => mapping(address => PartnerTokenInfo))
        public partnerTokensInfo;

    // staker contract address
    address public staker;

    // timestamp of VRSW emission start
    uint256 public immutable emissionStartTs;

    // tokenomics params contract address
    address public immutable tokenomicsParams;

    // VRSW token address
    address public immutable vrsw;

    // veVRSW token address
    address public immutable veVrsw;

    /**
     * @dev Constructor function
     * @param _emissionStartTs Timestamp of the start of emission
     * @param _tokenomicsParams Address of the tokenomics parameters contract
     * @param _vrsw Address of the VRSW token
     */
    constructor(
        uint32 _emissionStartTs,
        address _tokenomicsParams,
        address _vrsw,
        bool _enableVeVrsw
    ) {
        require(
            _tokenomicsParams != address(0),
            "tokenomicsParams zero address"
        );
        require(_vrsw != address(0), "vrsw zero address");
        tokenomicsParams = _tokenomicsParams;
        emissionStartTs = _emissionStartTs;
        epochDuration = 4 weeks;
        epochPreparationTime = 1 weeks;
        startEpochTime = _emissionStartTs - epochDuration;
        vrsw = _vrsw;
        veVrsw = _enableVeVrsw
            ? address(new VeVrsw(address(this)))
            : address(0);
    }

    /// @inheritdoc IVChainMinter
    function prepareForNextEpoch(
        uint256 nextBalance
    ) external override onlyOwner {
        uint256 currentEpochEnd = startEpochTime + epochDuration;
        require(
            block.timestamp + epochPreparationTime >= currentEpochEnd &&
                block.timestamp < currentEpochEnd,
            "Too early"
        );
        int256 diff = int256(nextBalance) - int256(nextEpochBalance);
        nextEpochBalance = nextBalance;
        if (diff > 0) {
            SafeERC20.safeTransferFrom(
                IERC20(vrsw),
                msg.sender,
                address(this),
                uint256(diff)
            );
        } else if (diff < 0) {
            SafeERC20.safeTransfer(IERC20(vrsw), msg.sender, uint256(-diff));
        }
    }

    /// @inheritdoc IVChainMinter
    function setEpochParams(
        uint32 _epochDuration,
        uint32 _epochPreparationTime
    ) external override onlyOwner {
        require(
            _epochPreparationTime > 0 && _epochDuration > 0,
            "must be greater than zero"
        );
        require(
            _epochPreparationTime < _epochDuration,
            "preparationTime >= epochDuration"
        );
        (nextEpochPreparationTime, nextEpochDuration) = (
            _epochPreparationTime,
            _epochDuration
        );
    }

    /// @inheritdoc IVChainMinter
    function setAllocationPoints(
        address[] calldata _pools,
        uint256[] calldata _allocationPoints
    ) external override onlyOwner {
        require(_pools.length == _allocationPoints.length, "lengths differ");
        if (block.timestamp >= startEpochTime + epochDuration)
            _epochTransition();

        uint256 availableTokens = _availableTokens();
        int256 _totalAllocationPoints = int256(totalAllocationPoints);
        IVStaker _staker = IVStaker(staker);
        StakerInfo memory stakerInfo;
        for (uint256 i = 0; i < _pools.length; ++i) {
            require(
                _pools[i] == address(0) || _staker.isPoolValid(_pools[i]),
                "one of lp tokens is not valid"
            );

            stakerInfo = stakers[_pools[i]];
            _updateStakerInfo(
                stakerInfo,
                allocationPoints[_pools[i]],
                availableTokens
            );
            stakers[_pools[i]] = stakerInfo;

            _totalAllocationPoints +=
                int256(_allocationPoints[i]) -
                int256(allocationPoints[_pools[i]]);
            allocationPoints[_pools[i]] = _allocationPoints[i];
        }
        require(
            uint256(_totalAllocationPoints) <= ALLOCATION_POINTS_FACTOR,
            "sum must be less than 1000000"
        );
        totalAllocationPoints = uint256(_totalAllocationPoints);
        emit AllocationPointsChanged(_pools, _allocationPoints);
    }

    /// @inheritdoc IVChainMinter
    function transferRewards(
        address to,
        address pool,
        address[] calldata rewardTokens,
        uint256[] calldata amounts
    ) external override {
        require(block.timestamp >= emissionStartTs, "too early");
        require(staker == msg.sender, "invalid staker");
        if (block.timestamp >= startEpochTime + epochDuration)
            _epochTransition();

        for (uint i = 0; i < rewardTokens.length; ++i) {
            if (amounts[i] > 0) {
                SafeERC20.safeTransfer(IERC20(rewardTokens[i]), to, amounts[i]);
                emit TransferRewards(to, pool, rewardTokens[i], amounts[i]);
            }
        }
    }

    /// @inheritdoc IVChainMinter
    function distributePartnerToken(
        address partnerToken,
        uint128 amount,
        address pool,
        uint128 from,
        uint128 duration
    ) external override onlyOwner {
        require(amount > 0, "amount must be positive");
        require(duration > 0, "duration must be positive");
        require(
            pool == address(0) || IVStaker(staker).isPoolValid(pool),
            "invalid pool"
        );
        PartnerTokenInfo memory partnerTokenInfo = partnerTokensInfo[pool][
            partnerToken
        ];
        if (
            partnerTokenInfo.amount == 0 &&
            partnerTokenInfo.distributedAmount == 0
        ) {
            partnerTokenInfo = PartnerTokenInfo(from, duration, amount, 0);
            partnerTokens[pool].push(partnerToken);
        } else {
            partnerTokenInfo.distributedAmount += partnerTokenInfo.amount;
            partnerTokenInfo.from = from;
            partnerTokenInfo.duration = duration;
            partnerTokenInfo.amount = amount;
        }
        partnerTokensInfo[pool][partnerToken] = partnerTokenInfo;
        SafeERC20.safeTransferFrom(
            IERC20(partnerToken),
            msg.sender,
            address(this),
            amount
        );
        emit PartnerRewards(partnerToken, amount, pool, from, duration);
    }

    /// @inheritdoc IVChainMinter
    function mintVeVrsw(address to, uint256 amount) external override {
        require(amount > 0, "zero amount");
        require(staker == msg.sender, "invalid staker");
        if (veVrsw != address(0)) VeVrsw(veVrsw).mint(to, amount);
    }

    /// @inheritdoc IVChainMinter
    function burnVeVrsw(address from, uint256 amount) external override {
        require(amount > 0, "zero amount");
        require(staker == msg.sender, "invalid staker");
        if (veVrsw != address(0)) VeVrsw(veVrsw).burn(from, amount);
    }

    /// @inheritdoc IVChainMinter
    function triggerEpochTransition() external override {
        require(block.timestamp >= startEpochTime + epochDuration, "Too early");
        _epochTransition();
    }

    /// @inheritdoc IVChainMinter
    function setStaker(address _newStaker) external override onlyOwner {
        require(_newStaker != address(0), "zero address");
        require(staker == address(0), "staker can be set once");
        staker = _newStaker;
        emit NewStaker(_newStaker);
    }

    function getRewardTokens(
        address pool
    ) external view override returns (address[] memory rewardTokens) {
        uint256 partnerTokensNumber = partnerTokens[pool].length;
        rewardTokens = new address[](partnerTokensNumber + 1);
        rewardTokens[0] = vrsw;
        for (uint i = 1; i <= partnerTokensNumber; ++i) {
            rewardTokens[i] = partnerTokens[pool][i - 1];
        }
    }

    /// @inheritdoc IVChainMinter
    function calculateTokensForPool(
        address pool,
        address rewardToken
    ) external view override returns (uint256) {
        if (rewardToken == vrsw) {
            uint256 _tokensAvailable = block.timestamp >=
                startEpochTime + epochDuration
                ? _availableTokensForNextEpoch()
                : _availableTokens();
            StakerInfo memory stakerInfo = stakers[pool];
            _updateStakerInfo(
                stakerInfo,
                allocationPoints[pool],
                _tokensAvailable
            );
            return stakerInfo.totalAllocated;
        } else {
            PartnerTokenInfo memory partnerTokenInfo = partnerTokensInfo[pool][
                rewardToken
            ];
            return
                partnerTokenInfo.distributedAmount +
                (
                    block.timestamp < partnerTokenInfo.from
                        ? 0
                        : (partnerTokenInfo.amount *
                            Math.min(
                                partnerTokenInfo.duration,
                                block.timestamp - partnerTokenInfo.from
                            )) / partnerTokenInfo.duration
                );
        }
    }

    /**
     * @dev Transfers through multiple epochs right to the epoch, which
     * start is before block.timestamp
     */
    function _epochTransition() private {
        startEpochTime += epochDuration;
        startEpochSupply += currentEpochBalance;
        currentEpochBalance = nextEpochBalance;
        if (nextEpochDuration > 0) {
            epochDuration = nextEpochDuration;
            nextEpochDuration = 0;
        }
        if (nextEpochPreparationTime > 0) {
            epochPreparationTime = nextEpochPreparationTime;
            nextEpochPreparationTime = 0;
        }
        nextEpochBalance = 0;
        uint256 _startEpochTime = startEpochTime;
        uint256 _epochDuration = epochDuration;
        if (block.timestamp >= _startEpochTime + _epochDuration) {
            startEpochSupply += currentEpochBalance;
            currentEpochBalance = 0;
        }
        while (block.timestamp >= _startEpochTime + _epochDuration) {
            _startEpochTime += _epochDuration;
        }
        startEpochTime = uint32(_startEpochTime);
    }

    /**
     * @dev Updates the specified staker's allocation information based on the current state of the emission.
     * @param stakerInfo The current allocation information for the staker.
     * @param _allocationPoints The allocation points for the staker's contract.
     */
    function _updateStakerInfo(
        StakerInfo memory stakerInfo,
        uint256 _allocationPoints,
        uint256 _tokensAvailable
    ) private pure {
        stakerInfo.totalAllocated += uint128(
            ((_tokensAvailable - stakerInfo.lastAvailable) *
                uint128(_allocationPoints)) / ALLOCATION_POINTS_FACTOR
        );
        stakerInfo.lastAvailable = uint128(_tokensAvailable);
    }

    /**
     * @dev Calculates number of VRSW tokens currently available for algorithmic
     * distribution.
     */
    function _availableTokens() private view returns (uint256) {
        return
            startEpochSupply +
            (Math.min(block.timestamp - startEpochTime, epochDuration) *
                currentEpochBalance) /
            epochDuration;
    }

    /**
     * @dev Calculates number of VRSW tokens that are available for algorithmic
     * distribution in case when now is epoch N and block.timestamp is in epoch N + 1.
     */
    function _availableTokensForNextEpoch() private view returns (uint256) {
        uint32 _nextEpochDuration = (
            nextEpochDuration > 0 ? nextEpochDuration : epochDuration
        );
        return
            (startEpochSupply + currentEpochBalance) +
            (Math.min(
                block.timestamp - startEpochTime - epochDuration,
                _nextEpochDuration
            ) * nextEpochBalance) /
            _nextEpochDuration;
    }
}
