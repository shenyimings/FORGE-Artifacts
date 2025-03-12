//SPDX-License-Identifier: Unlicense
pragma solidity ^0.5.16;

// @TOOD: remove console log
import "hardhat/console.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

contract GrantsDAOV2 is Ownable, ERC165 {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    uint256 public grantsCount;
    uint256 public initiativesCount;

    mapping(string => Grant) public grants;
    mapping(string => Initiative) public initiatives;

    /**
     * @notice The enum for the possible states that a grant can be in
     * ACTIVE - when the grant is initially created on the contract
     * COMPLETED - when all the milestones are paid out
     * CANCELLED - when a grant fails to reach all milestone payments
     */
    enum GrantState {ACTIVE, COMPLETED, CANCELLED}

    /**
     * @notice The enum for the possible states that a grant can be in
     * OPEN - when an initiative is open for someone to take up
     * ASSIGNED - when an initiative is assigned to someone
     * COMPLETED -  when all the milestones are paid out
     * CANCELLED - when a initiative fails to reach all milestone payments
     */
    enum InitiativeState {OPEN, ASSIGNED, COMPLETED, CANCELLED}

    /**
     * @notice A struct representing a grant
     */
    struct Grant {
        string grantHash;
        string title;
        string description;
        uint256[] milestones;
        address paymentCurrency;
        string proposer;
        address receivingAddress;
        uint256 currentMilestone;
        uint256 createdAt;
        uint256 modifiedAt;
        GrantState state;
    }

    /**
     * @notice A struct representing a initiative
     */
    struct Initiative {
        string initiativeHash;
        string title;
        string description;
        uint256[] milestones;
        address paymentCurrency;
        address receivingAddress;
        uint256 currentMilestone;
        uint256 createdAt;
        uint256 modifiedAt;
        InitiativeState state;
    }

    /**
     * @notice Event emitted when a new grant is created
     */
    event NewGrant(string grantHash, string proposer, address receivingAddress);

    /**
     * @notice Event emitted when a new grant is created
     */
    event NewInitiative(string initiativeHash);

    /**
     * @notice Event emitted when an initiative is assigned
     */
    event InitiativeAssigned(string initiativeHash, address assignee);

    /**
     * @notice Event emitted when an grant is re-assigned
     */
    event GrantReassigned(string grantHash, address assignee);

    /**
     * @notice Event emitted when a grant milestone is paid
     */
    event GrantMilestoneReleased(string grantHash, uint256 amount, address receiver, address paymentCurrency);

    /**
     * @notice Event emitted when an initiative milestone is paid
     */
    event InitiativeMilestoneReleased(string initiativeHash, uint256 amount, address receiver, address paymentCurrency);

    /**
     * @notice Event emitted when an grant is completed
     */
    event GrantCompleted(string grantHash);

    /**
     * @notice Event emitted when an initiative is completed
     */
    event InitiativeCompleted(string initiativeHash);

    /**
     * @notice Event emitted when an grant is cancelled
     */
    event GrantCancelled(string grantHash);

    /**
     * @notice Event emitted when an initiative is cancelled
     */
    event InitiativeCancelled(string initiativeHash);

    /**
     * @notice Event emitted when a withdrawal from the contract occurs
     */
    event Withdrawal(address receiver, uint256 amount, address token);

    /**
     * @notice Contract is created by a deployer who then sets the grantsDAO multisig to be the owner
     */
    constructor() public {}

    /**
     * @notice Called by the owners (gDAO multisig) to create a new grant
     * Emits NewGrant event.
     * @param _grantHash The ipfs hash of a grant (retrieved from the snapshot proposal)
     * @param _title The title of the grant
     * @param _description The description of the grant
     * @param _milestones An array specifying the number of milestones and the respective payment amounts
     * @param _paymentCurrency An address specifying the ERC20 token to be paid in
     * @param _proposer The identifier of the proposer
     * @param _receivingAddress The address in which to receive the grant milestones in
     */
    function createGrant(
        string memory _grantHash,
        string memory _title,
        string memory _description,
        uint256[] memory _milestones,
        address _paymentCurrency,
        string memory _proposer,
        address _receivingAddress
    ) public onlyOwner() {
        grants[_grantHash] = Grant(
            _grantHash,
            _title,
            _description,
            _milestones,
            _paymentCurrency,
            _proposer,
            _receivingAddress,
            0,
            now,
            now,
            GrantState.ACTIVE
        );

        grantsCount += 1;

        emit NewGrant(_grantHash, _proposer, _receivingAddress);
    }

    /**
     * @notice Called by the owners (gDAO multisig) to create a new initiative
     * Emits NewInitiative event.
     * @param _initiativeHash The ipfs hash of an initiatve, if passed through ipfs should return the content of this initiative
     * @param _title The title of the initiative
     * @param _description The description of the initiative
     * @param _milestones An array specifying the number of milestones and the respective payment amounts
     */
    function createInitiative(
        string memory _initiativeHash,
        string memory _title,
        string memory _description,
        uint256[] memory _milestones,
        address _paymentCurrency
    ) public onlyOwner() {
        Initiative memory newInitiative =
            Initiative(
                _initiativeHash,
                _title,
                _description,
                _milestones,
                _paymentCurrency,
                address(0),
                0,
                now,
                now,
                InitiativeState.OPEN
            );

        initiatives[_initiativeHash] = newInitiative;

        initiativesCount += 1;

        emit NewInitiative(_initiativeHash);
    }

    /**
     * @notice Called by the owners (gDAO multisig) to assign a initiative to a payable address
     * Emits InitiativeAssigned event.
     * @param _hash The hash of the initiative to modify
     * @param _assignee An address to assign the initiative to
     */
    function assignInitiative(string memory _hash, address _assignee) public onlyOwner() {
        Initiative storage initiative = initiatives[_hash];

        initiative.state = InitiativeState.ASSIGNED;

        initiative.receivingAddress = _assignee;

        emit InitiativeAssigned(_hash, _assignee);
    }

    /**
     * @notice Called by the owners (gDAO multisig) to assign a initiative to a payable address
     * Emits InitiativeAssigned event.
     * @param _hash The hash of the initiative to modify
     * @param _assignee An address to assign the initiative to
     */
    function reassignGrant(string memory _hash, address _assignee) public onlyOwner() {
        Grant storage grant = grants[_hash];

        grant.receivingAddress = _assignee;

        emit GrantReassigned(_hash, _assignee);
    }

    /**
     * @notice Called by the owners (gDAO multisig) to release a milestone payment on a grant
     * Emits GrantMilestoneReleased event or GrantCompleted
     * @param _hash The hash of the grant to release payment for
     */
    function progressGrant(string memory _hash) public onlyOwner() {
        Grant storage grant = grants[_hash];

        require(grant.state == GrantState.ACTIVE, "grant is not active");

        uint256 currentMilestone = grant.currentMilestone;

        // If the current milestone is the last one, mark the grant as completed
        if (currentMilestone == grant.milestones.length - 1) {
            grant.state = GrantState.COMPLETED;
            emit GrantCompleted(_hash);
        } else {
            grant.currentMilestone += 1;
        }

        grant.modifiedAt = now;

        _transferMilestonePayment(grant.milestones[currentMilestone], grant.paymentCurrency, grant.receivingAddress);

        emit GrantMilestoneReleased(
            _hash,
            grant.milestones[currentMilestone],
            grant.receivingAddress,
            grant.paymentCurrency
        );
    }

    /**
     * @notice Called by the owners (gDAO multisig) to release a milestone payment on an initiative
     * Emits InitiativeMilestoneReleased event or InitiativeCompleted
     * @param _hash The hash of the grant to release payment for
     */
    function progressInitiative(string memory _hash) public onlyOwner() {
        Initiative storage initiative = initiatives[_hash];

        require(initiative.state == InitiativeState.ASSIGNED, "initiative has not been assigned");

        uint256 currentMilestone = initiative.currentMilestone;

        // If the current milestone is the last one, mark the initiative as completed
        if (currentMilestone == initiative.milestones.length - 1) {
            initiative.state = InitiativeState.COMPLETED;
            emit InitiativeCompleted(_hash);
        } else {
            initiative.currentMilestone += 1;
        }

        initiative.modifiedAt = now;

        _transferMilestonePayment(
            initiative.milestones[currentMilestone],
            initiative.paymentCurrency,
            initiative.receivingAddress
        );

        emit InitiativeMilestoneReleased(
            _hash,
            initiative.milestones[currentMilestone],
            initiative.receivingAddress,
            initiative.paymentCurrency
        );
    }

    /**
     * @notice Called by the owners (gDAO multisig) to release all payments on an grant
     * Emits GrantCompleted
     * @param _hash The hash of the grant to release all payments
     */
    function completeGrant(string memory _hash) public onlyOwner() {
        Grant storage grant = grants[_hash];

        require(grant.state == GrantState.ACTIVE, "grant is not active");

        uint256 currentMilestone = grant.currentMilestone;

        uint256 total;

        for (uint256 i = currentMilestone; i < grant.milestones.length; i++) {
            total += grant.milestones[i];
        }

        grant.currentMilestone = grant.milestones.length - 1;

        grant.state = GrantState.COMPLETED;

        grant.modifiedAt = now;

        _transferMilestonePayment(total, grant.paymentCurrency, grant.receivingAddress);

        emit GrantCompleted(_hash);
    }

    /**
     * @notice Called by the owners (gDAO multisig) to release a milestone payment on an initiative
     * Emits InitiativeCompleted
     * @param _hash The hash of the initiative to release all payments
     */
    function completeInitiative(string memory _hash) public onlyOwner() {
        Initiative storage initiative = initiatives[_hash];

        require(initiative.state == InitiativeState.ASSIGNED, "initiative has not been assigned");

        uint256 currentMilestone = initiative.currentMilestone;

        uint256 total;

        for (uint256 i = currentMilestone; i < initiative.milestones.length; i++) {
            total += initiative.milestones[i];
        }

        initiative.currentMilestone = initiative.milestones.length - 1;

        initiative.state = InitiativeState.COMPLETED;

        initiative.modifiedAt = now;

        _transferMilestonePayment(total, initiative.paymentCurrency, initiative.receivingAddress);

        emit InitiativeCompleted(_hash);
    }

    /**
     * @notice Called by the owners (gDAO multisig) to cancel a grant
     * Emits GrantCancelled
     * @param _hash The hash of the grant to cancel
     */
    function cancelGrant(string memory _hash) public onlyOwner() {
        Grant storage grant = grants[_hash];

        grant.state = GrantState.CANCELLED;

        grant.modifiedAt = now;

        emit GrantCancelled(_hash);
    }

    /**
     * @notice Called by the owners (gDAO multisig) to cancel a initiative
     * Emits InitiativeCancelled
     * @param _hash The hash of the initiative to cancel
     */
    function cancelInitiative(string memory _hash) public onlyOwner() {
        Initiative storage initiative = initiatives[_hash];

        initiative.state = InitiativeState.CANCELLED;

        initiative.modifiedAt = now;

        emit InitiativeCancelled(_hash);
    }

    /**
     * @notice Called by the owners (gDAO multisig) to withdraw any ERC20 deposited in this account
     * Emits Withdrawal
     * @param _receiver The hash of the initiative to release all payments
     * @param _amount The amount of specified erc20 to withdraw
     * @param _token The hash of the initiative to release all payments
     */
    function withdraw(
        address _receiver,
        uint256 _amount,
        address _token
    ) public onlyOwner() {
        IERC20 token = IERC20(_token);

        require(token.balanceOf(address(this)) >= _amount, "insufficient balance in contract");

        token.safeTransfer(_receiver, _amount);

        emit Withdrawal(_receiver, _amount, _token);
    }

    /**
     * @notice An internal function that handles the transfer of funds from the contract to the payable address
     * @param _milestoneAmount The amount to transfer
     * @param _paymentCurrency The ERC20 address of token to transfer
     * @param _receiver The address of the receiver
     */
    function _transferMilestonePayment(
        uint256 _milestoneAmount,
        address _paymentCurrency,
        address _receiver
    ) internal {
        IERC20 token = IERC20(_paymentCurrency);

        require(token.balanceOf(address(this)) >= _milestoneAmount, "contract has insufficient balance");

        token.safeTransfer(_receiver, _milestoneAmount);
    }

    /**
     * @notice A view function for getting a grants milestones
     * @param _hash The hash of the grant
     */
    function returnGrantMilestones(string memory _hash) public view returns (uint256[] memory) {
        return grants[_hash].milestones;
    }

    /**
     * @notice A view function for getting an initiatives milestones
     * @param _hash The hash of the initiative
     */
    function returnInitiativeMilestones(string memory _hash) public view returns (uint256[] memory) {
        return initiatives[_hash].milestones;
    }
}
