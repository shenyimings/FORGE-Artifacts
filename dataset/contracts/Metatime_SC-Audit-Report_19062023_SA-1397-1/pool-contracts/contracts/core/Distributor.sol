// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Distributor is Initializable, Ownable2StepUpgradeable {
    string public poolName;
    IERC20 public token;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public totalAmount;
    uint256 public PERIOD;
    uint256 public DISTRIBUTION_RATE;
    uint256 immutable public BASE_DIVIDER = 10_000;
    uint256 public claimableAmount;
    uint256 public claimedAmount;
    uint256 public lastClaimTime;
    uint256 public leftClaimableAmount;

    event Swept(address receiver, uint256 amount);
    event CanClaim(address indexed beneficiary, uint256 amount);
    event HasClaimed(address indexed beneficiary, uint256 amount);

    function initialize(
        address _owner,
        string memory _poolName,
        IERC20 _token,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _distributionRate,
        uint256 _period,
        uint256 _claimableAmount
    ) external payable initializer {
        require(_startTime < _endTime, "Invalid end time");

        _transferOwnership(_owner);

        poolName = _poolName;
        token = _token;
        startTime = _startTime;
        endTime = _endTime;
        DISTRIBUTION_RATE = _distributionRate;
        PERIOD = _period;
        lastClaimTime = startTime;
        claimableAmount = _claimableAmount;
        leftClaimableAmount = _claimableAmount;
    }

    /**
     * @dev Claim tokens for the sender.
     */
    function claim() onlyOwner external returns(bool) {
        address sender = _msgSender();
        uint256 amount = calculateClaimableAmount();

        token.transfer(sender, amount);

        claimedAmount += amount;

        lastClaimTime = block.timestamp;

        leftClaimableAmount -= amount;

        emit HasClaimed(sender, amount);

        return true;
    }

    function calculateClaimableAmount() public view returns(uint256) {
        require(block.timestamp >= startTime, "Distribution has not started yet");
        require(block.timestamp < endTime, "Distribution has ended");
        
        uint256 amount = _calculateClaimableAmount();

        require(amount > 0, "No tokens to claim");
        require(leftClaimableAmount >= amount, "Not enough tokens left to claim");

        return amount;
    }

    /**
    * @dev Get the amount of tokens left to claim for a given address.
    */
    function getLeftClaimableAmount() external view returns (uint256) {
        return leftClaimableAmount;
    }

    /**
    * @dev Transfer tokens from the contract to a given address.
    */
    function sweep() onlyOwner external {
        require(block.timestamp > endTime, "sweep: Cannot sweep before claim end time!");

        uint256 leftovers = token.balanceOf(address(this));
        require(leftovers != 0, "TokenDistributor: no leftovers");

        require(token.transfer(owner(), leftovers), "TokenDistributor: fail token transfer");

        emit Swept(owner(), leftovers);
    }

    /**
     * @dev Calculate the amount of tokens that can be claimed by a given address
     * based on the number of days that have passed since the last claim.
     * The daily claim percentage is 0.4% of the initial claimable amount.
     */
    function _calculateClaimableAmount() internal view returns (uint256) {
        uint256 initialAmount = claimableAmount;
        uint256 periodSinceLastClaim = (block.timestamp - lastClaimTime) * 10 ** 18 / PERIOD;

        return (((initialAmount * DISTRIBUTION_RATE) / BASE_DIVIDER) * periodSinceLastClaim) / 10 ** 18;
    }
}