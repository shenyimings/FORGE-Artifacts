// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.6.12;

import "../../interfaces/IO3.sol";
import "../../libs/GSN/Context.sol";
import "../../libs/math/SafeMath.sol";
import "../../libs/ownership/Ownable.sol";
import "../../libs/utils/ReentrancyGuard.sol";
import "../../libs/token/ERC20/SafeERC20.sol";

contract O3Staking is Context, Ownable, ReentrancyGuard {
    using SafeMath for uint;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct StakingRecord {
        address staker;
        uint blockIndex;
        uint staked;
        uint totalProfit;
    }

    event LOG_STAKE (
        address indexed staker,
        uint stakeAmount
    );

    event LOG_UNSTAKE (
        address indexed staker,
        uint withdrawAmount
    );

    event LOG_CLAIM_PROFIT (
        address indexed staker,
        uint profit
    );

    event LOG_CALL (
        bytes4 indexed sig,
        address indexed caller,
        bytes data
    ) anonymous;

    modifier _logs_() {
        emit LOG_CALL(msg.sig, _msgSender(), _msgData());
        _;
    }

    address public StakingToken;
    address public O3Token;
    uint public startStakingBlockIndex;
    uint public startUnstakeBlockIndex;
    uint public startClaimBlockIndex;
    uint public totalStaked;

    mapping(address => StakingRecord) private _stakingRecords;
    mapping(uint => uint) private _unitProfitAccumu;

    uint private _unitProfit; // Latest unit profit.
    uint private _upBlockIndex; // The block index `_unitProfit` refreshed.

    uint private _sharePerBlock;
    bool private _stakingPaused;
    bool private _withdarawPaused;
    bool private _claimProfitPaused;

    uint public constant ONE = 10**18;

    constructor(
        address _stakingToken,
        address _o3Token,
        uint _startStakingBlockIndex,
        uint _startUnstakeBlockIndex,
        uint _startClaimBlockIndex
    ) public {
        require(_stakingToken != address(0), "O3Staking: ZERO_STAKING_ADDRESS");
        require(_o3Token != address(0), "O3Staking: ZERO_O3TOKEN_ADDRESS");
        require(_startClaimBlockIndex >= _startStakingBlockIndex, "O3Staking: INVALID_START_CLAIM_BLOCK_INDEX");

        StakingToken = _stakingToken;
        O3Token = _o3Token;
        startStakingBlockIndex = _startStakingBlockIndex;
        startUnstakeBlockIndex = _startUnstakeBlockIndex;
        startClaimBlockIndex = _startClaimBlockIndex;
    }

    function getTotalProfit(address staker) external view returns (uint) {
        if (block.number <= startStakingBlockIndex) {
            return 0;
        }

        uint currentProfitAccumu = _unitProfitAccumu[block.number];
        if (_upBlockIndex < block.number) {
            uint unitProfitIncrease = _unitProfit.mul(block.number.sub(_upBlockIndex));
            currentProfitAccumu = _unitProfitAccumu[_upBlockIndex].add(unitProfitIncrease);
        }

        StakingRecord storage rec = _stakingRecords[staker];

        uint preUnitProfit = _unitProfitAccumu[rec.blockIndex];
        uint currentProfit = (currentProfitAccumu.sub(preUnitProfit)).mul(rec.staked).div(ONE);

        return rec.totalProfit.add(currentProfit);
    }

    function getStakingAmount(address staker) external view returns (uint) {
        StakingRecord storage rec = _stakingRecords[staker];
        return rec.staked;
    }

    function getSharePerBlock() external view returns (uint) {
        return _sharePerBlock;
    }

    function setStakingToke(address _token) external onlyOwner _logs_ {
        StakingToken = _token;
    }

    function setSharePerBlock(uint sharePerBlock) external onlyOwner _logs_ {
        _sharePerBlock = sharePerBlock;
        _updateUnitProfitState();
    }

    function setStartUnstakeBlockIndex(uint _startUnstakeBlockIndex) external onlyOwner _logs_ {
        startUnstakeBlockIndex = _startUnstakeBlockIndex;
    }

    function setStartClaimBlockIndex(uint _startClaimBlockIndex) external onlyOwner _logs_ {
        startClaimBlockIndex = _startClaimBlockIndex;
    }

    function stake(uint amount) external nonReentrant _logs_ {
        require(!_stakingPaused, "O3Staking: STAKING_PAUSED");
        require(amount > 0, "O3Staking: INVALID_STAKING_AMOUNT");

        totalStaked = amount.add(totalStaked);
        _updateUnitProfitState();

        StakingRecord storage rec = _stakingRecords[_msgSender()];

        uint userTotalProfit = _settleCurrentUserProfit(_msgSender());
        _updateUserStakingRecord(_msgSender(), rec.staked.add(amount), userTotalProfit);

        emit LOG_STAKE(_msgSender(), amount);

        _pullToken(StakingToken, _msgSender(), amount);
    }

    function unstake(uint amount) external nonReentrant _logs_ {
        require(!_withdarawPaused, "O3Staking: UNSTAKE_PAUSED");
        require(block.number >= startUnstakeBlockIndex, "O3Staking: UNSTAKE_NOT_STARTED");

        StakingRecord storage rec = _stakingRecords[_msgSender()];

        require(amount > 0, "O3Staking: ZERO_UNSTAKE_AMOUNT");
        require(amount <= rec.staked, "O3Staking: UNSTAKE_AMOUNT_EXCEEDED");

        totalStaked = totalStaked.sub(amount);
        _updateUnitProfitState();

        uint userTotalProfit = _settleCurrentUserProfit(_msgSender());
        _updateUserStakingRecord(_msgSender(), rec.staked.sub(amount), userTotalProfit);

        emit LOG_UNSTAKE(_msgSender(), amount);

        _pushToken(StakingToken, _msgSender(), amount);
    }

    function claimProfit() external nonReentrant _logs_ {
        require(!_claimProfitPaused, "O3Staking: CLAIM_PROFIT_PAUSED");
        require(block.number >= startClaimBlockIndex, "O3Staking: CLAIM_NOT_STARTED");

        uint totalProfit = _getTotalProfit(_msgSender());
        require(totalProfit > 0, "O3Staking: ZERO_PROFIT");

        StakingRecord storage rec = _stakingRecords[_msgSender()];
        _updateUserStakingRecord(_msgSender(), rec.staked, 0);

        emit LOG_CLAIM_PROFIT(_msgSender(), totalProfit);

        _pushShareToken(_msgSender(), totalProfit);
    }

    function _getTotalProfit(address staker) internal returns (uint) {
        _updateUnitProfitState();

        uint totalProfit = _settleCurrentUserProfit(staker);
        return totalProfit;
    }

    function _updateUserStakingRecord(address staker, uint staked, uint totalProfit) internal {
        _stakingRecords[staker].staked = staked;
        _stakingRecords[staker].totalProfit = totalProfit;
        _stakingRecords[staker].blockIndex = block.number;

        // Any action before `startStakingBlockIndex` is treated as acted in block `startStakingBlockIndex`.
        if (block.number < startStakingBlockIndex) {
            _stakingRecords[staker].blockIndex = startStakingBlockIndex;
        }
    }

    function _settleCurrentUserProfit(address staker) internal view returns (uint) {
        if (block.number <= startStakingBlockIndex) {
            return 0;
        }

        StakingRecord storage rec = _stakingRecords[staker];

        uint preUnitProfit = _unitProfitAccumu[rec.blockIndex];
        uint currUnitProfit = _unitProfitAccumu[block.number];
        uint currentProfit = (currUnitProfit.sub(preUnitProfit)).mul(rec.staked).div(ONE);

        return rec.totalProfit.add(currentProfit);
    }

    function _updateUnitProfitState() internal {
        uint currentBlockIndex = block.number;
        if (_upBlockIndex >= currentBlockIndex) {
            _updateUnitProfit();
            return;
        }

        // Accumulate unit profit.
        uint unitStakeProfitIncrease = _unitProfit.mul(currentBlockIndex.sub(_upBlockIndex));
        _unitProfitAccumu[currentBlockIndex] = unitStakeProfitIncrease.add(_unitProfitAccumu[_upBlockIndex]);

        _upBlockIndex = block.number;

        if (currentBlockIndex <= startStakingBlockIndex) {
            _unitProfitAccumu[startStakingBlockIndex] = _unitProfitAccumu[currentBlockIndex];
            _upBlockIndex = startStakingBlockIndex;
        }

        _updateUnitProfit();
    }

    function _updateUnitProfit() internal {
        if (totalStaked > 0) {
            _unitProfit = _sharePerBlock.mul(ONE).div(totalStaked);
        }
    }

    function pauseStaking() external onlyOwner _logs_ {
        _stakingPaused = true;
    }

    function unpauseStaking() external onlyOwner _logs_ {
        _stakingPaused = false;
    }

    function pauseUnstake() external onlyOwner _logs_ {
        _withdarawPaused = true;
    }

    function unpauseUnstake() external onlyOwner _logs_ {
        _withdarawPaused = false;
    }

    function pauseClaimProfit() external onlyOwner _logs_ {
        _claimProfitPaused = true;
    }

    function unpauseClaimProfit() external onlyOwner _logs_ {
        _claimProfitPaused = false;
    }

    function collect(address token, address to) external nonReentrant onlyOwner _logs_ {
        require(token != StakingToken, "O3Staking: COLLECT_NOT_ALLOWED");
        uint balance = IERC20(token).balanceOf(address(this));
        _pushToken(token, to, balance);
    }

    function _pushToken(address token, address to, uint amount) internal {
        SafeERC20.safeTransfer(IERC20(token), to, amount);
    }

    function _pushShareToken(address to, uint amount) internal {
        IO3(O3Token).mintLockedToken(to, amount);
    }

    function _pullToken(address token, address from, uint amount) internal {
        SafeERC20.safeTransferFrom(IERC20(token), from, address(this), amount);
    }
}
