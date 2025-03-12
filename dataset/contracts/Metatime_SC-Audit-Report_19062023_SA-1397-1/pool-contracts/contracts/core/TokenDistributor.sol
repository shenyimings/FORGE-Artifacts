// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TokenDistributor is Initializable, Ownable2StepUpgradeable {
    string public poolName;
    IERC20 public token;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public totalAmount;
    uint256 public PERIOD;
    uint256 public DISTRIBUTION_RATE;
    uint256 immutable public BASE_DIVIDER = 10_000;
    mapping(address beneficiary => uint256 claimableAmount) public claimableAmounts;
    mapping(address beneficiary => uint256 claimedAmount) public claimedAmounts;
    mapping(address beneficiary => uint256 lastClaimTime) public lastClaimTimes;
    mapping(address beneficiary => uint256 leftAmount) public leftClaimableAmounts;

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
        uint256 _period
    ) external payable initializer {
        require(_startTime < _endTime, "Invalid end time");

        _transferOwnership(_owner);

        poolName = _poolName;
        token = _token;
        startTime = _startTime;
        endTime = _endTime;
        DISTRIBUTION_RATE = _distributionRate;
        PERIOD = _period;
    }

    /**
     * @dev Set the claimable amount for each address.
     * @param users List of addresses to set claimable amounts for.
     * @param amounts List of claimable amounts for each address.
     */
    function setClaimableAmounts(address[] calldata users, uint256[] calldata amounts) onlyOwner external {
        uint256 usersLength = users.length;
        require(usersLength == amounts.length, "setClaimableAmounts: User and amount list lengths must match!");
        
        uint256 totalClaimableAmount = 0;
        for (uint256 i = 0; i < usersLength; ) {
            address user = users[i];
            uint256 amount = amounts[i];
            claimableAmounts[user] = amount;
            leftClaimableAmounts[user] = amount;
            lastClaimTimes[user] = startTime;
            emit CanClaim(user, amount);
            unchecked {
                totalClaimableAmount = totalClaimableAmount + amount;
                i += 1;
            }
        }

        require(token.balanceOf(address(this)) >= totalClaimableAmount, "Total claimable amount does not match");
        totalAmount = totalClaimableAmount;
    }

    /**
     * @dev Claim tokens for the sender.
     */
    function claim() external returns(bool) {
        address sender = _msgSender();
        uint256 claimableAmount = calculateClaimableAmount(sender);


        token.transfer(sender, claimableAmount);
        claimedAmounts[sender] = claimedAmounts[sender] + claimableAmount;

        lastClaimTimes[sender] = block.timestamp;

        leftClaimableAmounts[sender] = leftClaimableAmounts[sender] - claimableAmount;

        emit HasClaimed(sender, claimableAmount);

        return true;
    }

    function calculateClaimableAmount(address user) public view returns(uint256) {
        require(block.timestamp >= startTime, "Distribution has not started yet");
        require(block.timestamp < endTime, "Distribution has ended");
        
        uint256 claimableAmount = _calculateClaimableAmount(user);

        require(claimableAmount > 0, "No tokens to claim");
        require(leftClaimableAmounts[user] >= claimableAmount, "Not enough tokens left to claim");

        return claimableAmount;
    }

    /**
    * @dev Get the amount of tokens left to claim for a given address.
    */
    function getLeftClaimableAmount(address user) external view returns (uint256) {
        return leftClaimableAmounts[user];
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
    function _calculateClaimableAmount(address user) internal view returns (uint256) {
        uint256 initialAmount = claimableAmounts[user];
        uint256 periodSinceLastClaim = (block.timestamp - lastClaimTimes[user]) * 10 ** 18 / PERIOD;
        
        return (((initialAmount * DISTRIBUTION_RATE) / BASE_DIVIDER) * periodSinceLastClaim) / 10 ** 18;
    }
}