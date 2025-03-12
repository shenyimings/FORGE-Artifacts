// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../perp/IPikaPerp.sol";
import "../access/Governable.sol";

/** @title VePikaFeeReward
    @notice Contract to distribute trading fee reward to vePIKA holders.
 */
contract VePikaFeeReward is Governable, ReentrancyGuard, Pausable {

    using SafeERC20 for IERC20;
    using Address for address payable;

    address public owner;
    address public pikaPerp;
    address public rewardToken;
    IERC20 public veToken; // immutable

    uint256 public cumulativeRewardPerTokenStored;

    mapping(address => uint256) private claimableReward;
    mapping(address => uint256) private previousRewardPerToken;

    uint256 public constant PRECISION = 10**18;
    event SetOwner(address owner);
    event SetPikaPerp(address pikaPerp);
    event ClaimedReward(
        address user,
        address rewardToken,
        uint256 amount
    );

    constructor(address _veToken, address _rewardToken) {
        owner = msg.sender;
        veToken = IERC20(_veToken);
        rewardToken = _rewardToken;
    }

    // Views methods

    function totalSupply() external view returns (uint256) {
        return veToken.totalSupply();
    }

    function balanceOf(address account) external view returns (uint256) {
        return veToken.balanceOf(account);
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

    // Methods

    function updateReward(address account) public {
        if (account == address(0)) return;
        uint256 pikaReward = IPikaPerp(pikaPerp).distributePikaReward();
        uint256 _totalSupply = veToken.totalSupply();
        if (_totalSupply > 0) {
            cumulativeRewardPerTokenStored += pikaReward * PRECISION / _totalSupply;
        }
        if (cumulativeRewardPerTokenStored == 0) return;
        claimableReward[account] += veToken.balanceOf(account) * (cumulativeRewardPerTokenStored - previousRewardPerToken[account]) / PRECISION;
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
        uint256 totalSupply = veToken.totalSupply();
        if (totalSupply == 0) return currentClaimableReward;

        uint256 _pendingReward = IPikaPerp(pikaPerp).getPendingPikaReward();
        uint256 _rewardPerTokenStored = cumulativeRewardPerTokenStored + _pendingReward * PRECISION / totalSupply;
        if (_rewardPerTokenStored == 0) return currentClaimableReward;
        return currentClaimableReward + veToken.balanceOf(account) * (_rewardPerTokenStored - previousRewardPerToken[account]) / PRECISION;
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
