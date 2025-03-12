// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../perp/IPikaPerp.sol";
import "./IPikaStaking.sol";
import "../access/Governable.sol";

/** @title PikaFeeReward
    @notice Contract to distribute trading fee reward to PIKA holders.
 */
contract PikaFeeReward is Governable, ReentrancyGuard, Pausable {

    using SafeERC20 for IERC20;
    using Address for address payable;

    address public owner;
    address public pikaPerp;
    address public pikaStaking;
    address public rewardToken;

    uint256 public cumulativeRewardPerTokenStored;

    mapping(address => uint256) private claimableReward;
    mapping(address => uint256) private previousRewardPerToken;

    uint256 public constant PRECISION = 10**18;
    event SetOwner(address owner);
    event SetPikaPerp(address pikaPerp);
    event SetPikaStaking(address pikaStaking);
    event ClaimedReward(
        address user,
        address rewardToken,
        uint256 amount
    );

    constructor(address _pikaStaking, address _rewardToken) {
        owner = msg.sender;
        pikaStaking = _pikaStaking;
        rewardToken = _rewardToken;
    }

    // Governance methods

    function setOwner(address _owner) external onlyGov {
        owner = _owner;
        emit SetOwner(_owner);
    }

    function setPikaPerp(address _pikaPerp) external onlyOwner {
        pikaPerp = _pikaPerp;
        emit SetPikaPerp(_pikaPerp);
    }

    function setPikaStaking(address _pikaStaking) external onlyOwner {
        pikaStaking = _pikaStaking;
        emit SetPikaStaking(_pikaStaking);
    }

    // Methods

    function updateReward(address account) public {
        if (account == address(0)) return;
        uint256 pikaReward = IPikaPerp(pikaPerp).distributePikaReward();
        uint256 _totalSupply = IPikaStaking(pikaStaking).totalSupply();
        if (_totalSupply > 0) {
            cumulativeRewardPerTokenStored += pikaReward * PRECISION / _totalSupply;
        }
        if (cumulativeRewardPerTokenStored == 0) return;
        claimableReward[account] += IPikaStaking(pikaStaking).balanceOf(account) * (cumulativeRewardPerTokenStored - previousRewardPerToken[account]) / PRECISION;
        previousRewardPerToken[account] = cumulativeRewardPerTokenStored;
    }

    function claimReward() external {
        updateReward(msg.sender);
        uint256 rewardToSend = claimableReward[msg.sender];
        claimableReward[msg.sender] = 0;
        if (rewardToSend > 0) {
            _transferOut(msg.sender, rewardToSend);
            emit ClaimedReward(
                msg.sender,
                rewardToken,
                rewardToSend
            );
        }
    }

    function getClaimableReward(address account) external view returns(uint256) {
        uint256 currentClaimableReward = claimableReward[account];
        uint256 totalSupply = IPikaStaking(pikaStaking).totalSupply();
        if (totalSupply == 0) return currentClaimableReward;

        uint256 _pendingReward = IPikaPerp(pikaPerp).getPendingPikaReward();
        uint256 _rewardPerTokenStored = cumulativeRewardPerTokenStored + _pendingReward * PRECISION / totalSupply;
        if (_rewardPerTokenStored == 0) return currentClaimableReward;
        return currentClaimableReward + IPikaStaking(pikaStaking).balanceOf(account) * (_rewardPerTokenStored - previousRewardPerToken[account]) / PRECISION;
    }

    fallback() external payable {}
    receive() external payable {}

    // Utils

    function _transferOut(address to, uint256 amount) internal {
        if (amount == 0 || to == address(0)) return;
        if (rewardToken == address(0)) {
            payable(to).sendValue(amount);
        } else {
            IERC20(rewardToken).safeTransfer(to, amount);
        }
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }
}
