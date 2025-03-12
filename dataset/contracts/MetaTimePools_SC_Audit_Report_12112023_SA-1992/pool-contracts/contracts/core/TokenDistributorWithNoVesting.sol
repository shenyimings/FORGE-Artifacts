// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenDistributorWithNoVesting
 * @dev A contract for distributing tokens during no vesting sales.
 */
contract TokenDistributorWithNoVesting is Initializable, Ownable {
    uint256 public distributionPeriodStart; // The start time of the distribution period
    uint256 public distributionPeriodEnd; // The end time of the distribution period
    uint256 public claimPeriodEnd; // The end time of the claim period
    uint256 public totalAmount; // The total amount of tokens available for distribution
    mapping(address => uint256) public claimableAmounts; // Mapping of beneficiary addresses to their claimable amounts

    event CanClaim(address indexed beneficiary, uint256 amount); // Event emitted when a beneficiary can claim tokens
    event HasClaimed(address indexed beneficiary, uint256 amount); // Event emitted when a beneficiary claims tokens
    event Swept(address receiver, uint256 amount); // Event emitted when tokens are swept from the contract
    event SetClaimableAmounts(uint256 usersLength, uint256 totalAmount); // Event emitted when claimable amounts are set
    event Deposit(address indexed sender, uint amount, uint balance); // Event emitted when pool received mtc

    /**
     * @dev The receive function is a special function that allows the contract to accept MTC transactions.
     * It emits a Deposit event to record the deposit details.
     */
    receive() external payable {
        emit Deposit(_msgSender(), msg.value, address(this).balance);
    }

    /**
     * @dev Initializes the contract.
     * @param _distributionPeriodStart The start time of the claim period
     * @param _distributionPeriodEnd The end time of the claim period
     */
    function initialize(
        uint256 _distributionPeriodStart,
        uint256 _distributionPeriodEnd
    ) external initializer {
        require(
            _distributionPeriodEnd > _distributionPeriodStart,
            "TokenDistributorWithNoVesting: end time must be bigger than start time"
        );

        distributionPeriodStart = _distributionPeriodStart;
        distributionPeriodEnd = _distributionPeriodEnd;
        claimPeriodEnd = _distributionPeriodEnd + 100 days;

        _transferOwnership(_msgSender());
    }

    /**
     * @dev Controls settable status of the contract while trying to set addresses and their amounts.
     */
    modifier isSettable() {
        require(
            block.timestamp < distributionPeriodStart,
            "TokenDistributorWithNoVesting: claim period has already started"
        );
        _;
    }

    /**
     * @dev Sets the claimable amounts for a list of users.
     * @param users The list of user addresses
     * @param amounts The list of claimable amounts corresponding to each user
     */
    function setClaimableAmounts(
        address[] calldata users,
        uint256[] calldata amounts
    ) external onlyOwner isSettable {
        uint256 usersLength = users.length;
        require(
            usersLength == amounts.length,
            "TokenDistributorWithNoVesting: user and amount list lengths must match"
        );

        uint256 sum = totalAmount;
        for (uint256 i = 0; i < usersLength; i++) {
            address user = users[i];

            require(
                user != address(0),
                "TokenDistributorWithNoVesting: cannot set zero address"
            );

            uint256 amount = amounts[i];

            require(
                claimableAmounts[user] == 0,
                "TokenDistributorWithNoVesting: address already set"
            );

            claimableAmounts[user] = amount;
            emit CanClaim(user, amount);

            sum += amounts[i];
        }

        require(
            address(this).balance >= sum,
            "TokenDistributorWithNoVesting: total claimable amount does not match"
        );
        totalAmount = sum;

        emit SetClaimableAmounts(usersLength, totalAmount);
    }

    /**
     * @dev Allows a beneficiary to claim their tokens.
     */
    function claim() external {
        require(
            block.timestamp >= distributionPeriodStart,
            "TokenDistributorWithNoVesting: tokens cannot be claimed yet"
        );
        require(
            block.timestamp <= claimPeriodEnd,
            "TokenDistributorWithNoVesting: claim period has ended"
        );

        uint256 claimableAmount = claimableAmounts[_msgSender()];

        require(
            claimableAmount > 0,
            "TokenDistributorWithNoVesting: no tokens to claim"
        );

        claimableAmounts[_msgSender()] = 0;

        (bool sent, ) = _msgSender().call{value: claimableAmount}("");
        require(sent, "TokenDistributorWithNoVesting: unable to withdraw");

        emit HasClaimed(_msgSender(), claimableAmount);
    }

    /**
     * @dev Transfers remaining tokens from the contract to the owner.
     */
    function sweep() external onlyOwner {
        require(
            block.timestamp > claimPeriodEnd,
            "TokenDistributorWithNoVesting: cannot sweep before claim end time"
        );

        uint256 leftovers = address(this).balance;
        require(leftovers != 0, "TokenDistributorWithNoVesting: no leftovers");

        (bool sent, ) = owner().call{value: leftovers}("");
        require(sent, "TokenDistributorWithNoVesting: unable to withdraw");

        emit Swept(owner(), leftovers);
    }
}
