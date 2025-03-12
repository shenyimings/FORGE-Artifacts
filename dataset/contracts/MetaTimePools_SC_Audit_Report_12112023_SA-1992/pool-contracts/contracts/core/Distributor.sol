// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Distributor
 * @notice Holds tokens for users to claim.
 * @dev A contract for distributing tokens over a specified period of time.
 */
contract Distributor is Initializable, Ownable {
    string public poolName; // Name of the mtc distribution pool
    uint256 public startTime; // Start time of the distribution
    uint256 public endTime; // End time of the distribution
    uint256 public periodLength; // Length of each distribution period
    uint256 public distributionRate; // Rate of mtc distribution per period
    uint256 public constant BASE_DIVIDER = 10_000; // Base divider for distribution rate calculation
    uint256 public claimableAmount; // Total amount of tokens claimable per period
    uint256 public claimedAmount; // Total amount of tokens claimed so far
    uint256 public lastClaimTime; // Timestamp of the last mtc claim
    uint256 public leftClaimableAmount; // Remaining amount of tokens available for claiming

    event HasClaimed(address indexed beneficiary, uint256 amount); // Event emitted when a beneficiary has claimed tokens
    event PoolParamsUpdated(
        uint256 newStartTime,
        uint256 newEndTime,
        uint256 newDistributionRate,
        uint256 newPeriodLength,
        uint256 newClaimableAmount
    ); // Event emitted when pool params are updated
    event Deposit(address indexed sender, uint amount, uint balance); // Event emitted when pool received mtc

    /**
     * @dev A modifier that validates pool parameters.
     * @param _startTime Start timestamp of claim period.
     * @param _endTime End timestamp of claim period.
     * @param _distributionRate Distribution rate of each claim.
     * @param _periodLength Distribution duration of each claim.
     */
    modifier isParamsValid(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _distributionRate,
        uint256 _periodLength
    ) {
        require(
            _startTime < _endTime,
            "Distributor: end time must be bigger than start time"
        );
        _;
    }

    /**
     * @dev disableInitializers function.
     * It disables the execution of initializers in the contract, as it is not intended to be called directly.
     * The purpose of this function is to prevent accidental execution of initializers when creating proxy instances of the contract.
     * It is called internally during the construction of the proxy contract.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev The receive function is a special function that allows the contract to accept MTC transactions.
     * It emits a Deposit event to record the deposit details.
     */
    receive() external payable {
        emit Deposit(_msgSender(), msg.value, address(this).balance);
    }

    /**
     * @dev Initializes the contract with the specified parameters.
     * @param _owner The address of the contract owner.
     * @param _poolName The name of the mtc distribution pool.
     * @param _startTime The start time of the distribution.
     * @param _endTime The end time of the distribution.
     * @param _distributionRate The rate of mtc distribution per period.
     * @param _periodLength The length of each distribution period.
     * @param _claimableAmount The total amount of tokens claimable per period.
     */
    function initialize(
        address _owner,
        string memory _poolName,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _distributionRate,
        uint256 _periodLength,
        uint256 _lastClaimTime,
        uint256 _claimableAmount,
        uint256 _leftClaimableAmount
    )
        external
        initializer
        isParamsValid(_startTime, _endTime, _distributionRate, _periodLength)
    {
        _transferOwnership(_owner);

        poolName = _poolName;
        startTime = _startTime;
        endTime = _endTime;
        distributionRate = _distributionRate;
        periodLength = _periodLength;
        lastClaimTime = _lastClaimTime;
        claimableAmount = _claimableAmount;
        leftClaimableAmount = _leftClaimableAmount;
    }

    /**
     * @dev Claim tokens for the sender.
     * @return A boolean indicating whether the claim was successful.
     */
    function claim() external onlyOwner returns (bool) {
        uint256 amount = calculateClaimableAmount();

        claimedAmount += amount;

        lastClaimTime = block.timestamp;

        leftClaimableAmount -= amount;

        (bool sent, ) = owner().call{value: amount}("");
        require(sent, "Distributor: unable to claim");

        emit HasClaimed(owner(), amount);

        return true;
    }

    /**
     * @dev Updates pool parameters before the claim period and only callable by the contract owner.
     * @param newStartTime New start timestamp of the claim period.
     * @param newEndTime New end timestamp of the claim period.
     * @param newDistributionRate New distribution rate of each claim.
     * @param newPeriodLength New distribution duration of each claim.
     * @param newClaimableAmount New claimable amount of the pool.
     */
    function updatePoolParams(
        uint256 newStartTime,
        uint256 newEndTime,
        uint256 newDistributionRate,
        uint256 newPeriodLength,
        uint256 newClaimableAmount
    )
        external
        onlyOwner
        isParamsValid(
            newStartTime,
            newEndTime,
            newDistributionRate,
            newPeriodLength
        )
        returns (bool)
    {
        startTime = newStartTime;
        endTime = newEndTime;
        distributionRate = newDistributionRate;
        periodLength = newPeriodLength;
        claimableAmount = newClaimableAmount;
        lastClaimTime = newStartTime;

        emit PoolParamsUpdated(
            newStartTime,
            newEndTime,
            newDistributionRate,
            newPeriodLength,
            newClaimableAmount
        );

        return true;
    }

    /**
     * @dev Calculates the amount of tokens claimable for the current period.
     * @return The amount of tokens claimable for the current period.
     */
    function calculateClaimableAmount() public view returns (uint256) {
        require(
            block.timestamp >= startTime,
            "Distributor: distribution has not started yet"
        );

        uint256 amount = 0;
        if (block.timestamp > endTime) {
            amount = leftClaimableAmount;
        } else {
            amount = _calculateClaimableAmount();
        }

        require(amount > 0, "calculateClaimableAmount: No tokens to claim");

        return amount;
    }

    /**
     * @dev Internal function to calculate the amount of tokens claimable for the current period.
     * @return The amount of tokens claimable for the current period.
     */
    function _calculateClaimableAmount() internal view returns (uint256) {
        return
            (claimableAmount *
                distributionRate *
                (block.timestamp - lastClaimTime) *
                10 ** 18) / (periodLength * BASE_DIVIDER * 10 ** 18);
    }
}
