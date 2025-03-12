// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/*
Adopted from Convex's Vested Escrow
found at https://github.com/convex-eth/platform/blob/main/contracts/contracts/VestedEscrow.sol
*/
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../libraries/ScaledMath.sol";
import "../../interfaces/tokenomics/IVestingEscrow.sol";

contract VestingEscrow is ReentrancyGuard, Ownable, IVestingEscrow {
    using ScaledMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public rewardToken;
    address public fundAdmin;

    uint256 public startTime;
    uint256 public endTime;
    uint256 public totalTime;

    uint256 public initialLockedSupply;
    uint256 public unallocatedSupply;
    bool supplyInitialized;

    mapping(address => uint256) public initialLocked;
    mapping(address => uint256) public totalClaimed;

    constructor(
        address rewardToken_,
        uint256 starttime_,
        uint256 endtime_,
        address fundAdmin_
    ) Ownable() {
        require(starttime_ >= block.timestamp, "start must be future");
        require(endtime_ > starttime_, "end must be greater");

        rewardToken = IERC20(rewardToken_);
        startTime = starttime_;
        endTime = endtime_;
        totalTime = endTime - startTime;
        fundAdmin = fundAdmin_;
    }

    // @notice: Initializes the token supply granted to the vesting escrow contract. Needs to be called after minting
    function setUnallocatedSupply() external override onlyOwner {
        require(!supplyInitialized, "Unallocated supply already set");
        require(rewardToken.balanceOf(address(this)) > 0, "contract does not own any tokens");
        unallocatedSupply = rewardToken.balanceOf(address(this));
        supplyInitialized = true;
        emit SupplyInitialized(unallocatedSupply);
    }

    function setupVesting(
        address[] calldata _recipient,
        uint256[] calldata _amount
    ) external override nonReentrant returns (bool) {
        require(msg.sender == fundAdmin);
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _recipient.length; i++) {
            uint256 amount = _amount[i];
            initialLocked[_recipient[i]] = initialLocked[_recipient[i]] + amount;
            totalAmount += amount;
            emit Fund(_recipient[i], amount);
        }

        initialLockedSupply += totalAmount;
        unallocatedSupply -= totalAmount;
        return true;
    }

    function _totalVestedOf(address _recipient, uint256 _time) internal view returns (uint256) {
        if (_time < startTime) {
            return 0;
        }
        uint256 locked = initialLocked[_recipient];
        uint256 elapsed = _time - startTime;
        uint256 total = (locked * elapsed) / totalTime;
        if (total > locked) {
            return locked;
        }
        return total;
    }

    function _totalVested() internal view returns (uint256) {
        uint256 _time = block.timestamp;
        if (_time < startTime) {
            return 0;
        }
        uint256 locked = initialLockedSupply;
        uint256 elapsed = _time - startTime;
        uint256 total = (locked * elapsed) / totalTime;
        if (total > locked) {
            return locked;
        }
        return total;
    }

    function vestedSupply() external view override returns (uint256) {
        return _totalVested();
    }

    function lockedSupply() external view override returns (uint256) {
        return initialLockedSupply - _totalVested();
    }

    function vestedOf(address _recipient) external view override returns (uint256) {
        return _totalVestedOf(_recipient, block.timestamp);
    }

    function balanceOf(address _recipient) external view override returns (uint256) {
        uint256 vested = _totalVestedOf(_recipient, block.timestamp);
        return vested - totalClaimed[_recipient];
    }

    function lockedOf(address _recipient) external view override returns (uint256) {
        uint256 vested = _totalVestedOf(_recipient, block.timestamp);
        return initialLocked[_recipient] - vested;
    }

    function claim() external override nonReentrant {
        uint256 vested = _totalVestedOf(msg.sender, block.timestamp);
        uint256 claimable = vested - totalClaimed[msg.sender];

        totalClaimed[msg.sender] = totalClaimed[msg.sender] + claimable;
        rewardToken.safeTransfer(msg.sender, claimable);

        emit Claim(msg.sender, claimable);
    }
}
