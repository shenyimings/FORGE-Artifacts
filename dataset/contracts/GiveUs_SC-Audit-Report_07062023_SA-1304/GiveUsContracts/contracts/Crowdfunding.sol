// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ICrowdfunding} from "./ICrowdfunding.sol";

/**
 * @title A Crowdfunding Contract
 * @author Ludovic Domingues
 * @notice Contract used for Looting Plateform
 */
contract Crowdfunding is
    ICrowdfunding,
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    /**
     * @dev The following constants are used by AccessControl to check authorisations.
     */
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");
    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

    modifier validProjectId(uint256 id) {
        if (idCounter.current() <= id) {
            revert InvalidProjectId();
        }
        _;
    }

    modifier validTresholdId(uint256 projectId, uint256 tresholdId) {
        Project memory project = projects[projectId];
        if (project.nbOfTresholds <= tresholdId) {
            revert InvalidTresholdId();
        }
        _;
    }

    modifier supportedToken(address exchangeTokenAddress) {
        if (isTokenSupported(exchangeTokenAddress) == 0) {
            revert TokenNotSupported();
        }
        _;
    }

    mapping(address => uint256) private supportedTokens;
    mapping(uint256 => Project) private projects; //get project by id
    mapping(uint256 => mapping(uint256 => Treshold)) private projectsTresholds; //get project by id and treshold by id // each treshold has its own budget like [10,20,30] this means the total budget is 10+20+30 //can add alter a function to add new tresholds
    mapping(address => mapping(uint256 => uint256)) private userDonations;
    mapping(address => mapping(uint256 => mapping(uint256 => uint256)))
        private tresholdVoteFromAddress;
    mapping(uint256 => mapping(uint256 => address[]))
        private voterArrayForTreshold;

    CountersUpgradeable.Counter private idCounter;

    /**
     * @notice Initializer used to set the default roles
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `PAUSER_ROLE`, `UPDATER_ROLE` and `WITHDRAWER_ROLE` to the msg.sender
     */
    function initialize() public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPDATER_ROLE, msg.sender);
        _grantRole(WITHDRAWER_ROLE, msg.sender);
    }

    /**
     * @notice Function used to Create a new Project
     * @param projectData Data used to create project
     * @param tresholds Array of threshold for the project
     */
    function createProject(
        ProjectData calldata projectData,
        Treshold[] calldata tresholds
    )
        external
        payable
        virtual
        override
        onlyRole(UPDATER_ROLE)
        whenNotPaused
        supportedToken(projectData.exchangeTokenAddress)
    {
        if (tresholds.length == 0) {
            revert ZeroTresholds();
        }
        if (projectData.requiredAmount == 0) {
            revert ZeroRequiredAmount();
        }
        uint256 currentId = idCounter.current();
        projects[currentId] = Project(
            1,
            projectData.owner,
            projectData.exchangeTokenAddress,
            projectData.name,
            projectData.assoName,
            projectData.description,
            projectData.requiredAmount,
            0,
            0,
            0,
            0,
            tresholds.length,
            projectData.requiredVotePercentage,
            projectData.voteCooldown, //TODO add require for voteCooldown
            0,
            projectData.donationFee
        );

        for (uint256 i; i < tresholds.length; ) {
            projectsTresholds[currentId][i] = tresholds[i];
            unchecked {
                ++i;
            }
        }

        idCounter.increment();

        emit ProjectCreated(currentId, projectData.owner, projectData.name);
    }

    /**
     * @notice Function returning if a user is a donator or not
     * @param user user address
     * @param id project id
     * @return uint boolean, is user a donator
     */
    function isDonator(
        address user,
        uint256 id
    ) public view virtual override validProjectId(id) returns (uint256) {
        return userDonations[user][id] != 0 ? 1 : 0;
    }

    /**
     * @notice Function that checks if token is supported by the contract as an exchange token
     * @param token address of the token you want to check
     * @return uint boolean, is token supported
     */
    function isTokenSupported(address token) public view returns (uint256) {
        return supportedTokens[token];
    }

    /**
     * @notice Function that returns the project data of a given projectId
     * @param projectId ID of the project
     * @return Project the data for the given project
     */
    function getProject(
        uint256 projectId
    )
        external
        view
        virtual
        override
        validProjectId(projectId)
        returns (Project memory)
    {
        return projects[projectId];
    }

    /**
     * @notice Function that returns the project treshold of a given projectId and tresholdId
     * @param projectId ID of the project
     * @param tresholdId ID of the treshold
     * @return Treshold the treshold for the given projectId && tresholdId
     */
    function getProjectTresholds(
        uint256 projectId,
        uint256 tresholdId
    )
        external
        view
        virtual
        override
        validProjectId(projectId)
        validTresholdId(projectId, tresholdId)
        returns (Treshold memory)
    {
        return projectsTresholds[projectId][tresholdId];
    }

    /**
     * @notice Function that returns donated amount from a donatorAddress to a project
     * @param donatorAddress address of the donator
     * @param projectId ID of the project
     * @return uint donated amount
     */
    function getUserDonations(
        address donatorAddress,
        uint256 projectId
    )
        external
        view
        virtual
        override
        validProjectId(projectId)
        returns (uint256)
    {
        return userDonations[donatorAddress][projectId];
    }

    /**
     * @notice Function that returns if a donator has voted on a treshold
     * @param voterAddress address of the donator/voter
     * @param projectId ID of the project
     * @param tresholdId ID of the treshold
     * @return uint boolean, has voted ?
     */
    function getTresholdVoteFromAddress(
        address voterAddress,
        uint256 projectId,
        uint256 tresholdId
    )
        external
        view
        virtual
        override
        validProjectId(projectId)
        validTresholdId(projectId, tresholdId)
        returns (uint256)
    {
        return tresholdVoteFromAddress[voterAddress][projectId][tresholdId];
    }

    /**
     * @notice Triggers stopped state
     */
    function pause() external payable onlyRole(PAUSER_ROLE) whenNotPaused {
        _pause();
    }

    /**
     * @notice Returns to normal state
     */
    function unpause() external payable onlyRole(PAUSER_ROLE) whenPaused {
        _unpause();
    }

    /**
     * @notice Donate amount of tokens to project id
     * @param projectId ID of the project
     * @param amount amount to donate
     */
    function donateToProject(
        uint256 projectId,
        uint256 amount
    ) external virtual override whenNotPaused validProjectId(projectId) {
        if (amount == 0) {
            revert ZeroAmount();
        }
        Project memory project = projects[projectId];

        if (project.isActive == 0) {
            revert ProjectNotActive();
        }

        if ((amount / 10000) * 10000 != amount) {
            revert AmountTooSmall();
        }

        address tokenSupported = project.exchangeTokenAddress;

        if (
            IERC20Upgradeable(tokenSupported).allowance(
                msg.sender,
                address(this)
            ) < amount
        ) {
            revert AllowanceNotApproved();
        }

        uint256 transactionFee = (amount * project.donationFee) / 10000;
        uint256 donationAmount = amount - transactionFee;

        //Somehow the second one is more gas efficient written this way but not the first one
        userDonations[msg.sender][projectId] += donationAmount;
        projects[projectId].currentAmount =
            projects[projectId].currentAmount +
            donationAmount;

        project = projects[projectId];
        Treshold memory currentTreshold = projectsTresholds[projectId][
            project.currentTreshold
        ];

        if (
            project.currentAmount >= currentTreshold.budget &&
            currentTreshold.voteSession.isVotingInSession == 0 &&
            project.currentTreshold < project.nbOfTresholds &&
            project.currentVoteCooldown <= block.timestamp
        ) {
            startTresholdVoting(projectId);
        }

        if (
            !IERC20Upgradeable(tokenSupported).transferFrom(
                msg.sender,
                address(this),
                amount
            )
        ) {
            revert TransferFailed();
        }

        emit DonatedToProject(msg.sender, projectId, donationAmount);
    }

    /**
     * @notice Function that starts a vote session for a treshold
     * @param id ID of the project
     */
    function endTresholdVoting(
        uint256 id
    )
        external
        payable
        virtual
        override
        onlyRole(UPDATER_ROLE)
        whenNotPaused
        validProjectId(id)
    {
        Project memory project = projects[id];
        Treshold memory currentTreshold = projectsTresholds[id][
            project.currentTreshold
        ];
        if (currentTreshold.voteSession.isVotingInSession == 0) {
            revert NotInVotingSession();
        }

        projectsTresholds[id][project.currentTreshold]
            .voteSession
            .isVotingInSession = 0;

        deliberateVote(id);
    }

    /**
     * @notice Function that allows a donator to vote for the current treshold of a project
     * @param id ID of the project
     * @param vote true for positive vote, false for negative vote
     */
    function voteForTreshold(
        uint256 id,
        uint256 vote
    ) external virtual override whenNotPaused validProjectId(id) {
        if (vote > 1) {
            revert InvalidUintAsBool();
        }
        if (isDonator(msg.sender, id) == 0) {
            revert NotADonator();
        }

        Project memory project = projects[id];
        Treshold memory currentTreshold = projectsTresholds[id][
            project.currentTreshold
        ];

        if (currentTreshold.voteSession.isVotingInSession == 0) {
            revert NotInVotingSession();
        }

        if (
            tresholdVoteFromAddress[msg.sender][id][project.currentTreshold] ==
            1
        ) {
            revert CanOnlyVoteOnce();
        }

        VoteSession memory vs = currentTreshold.voteSession;
        vote == 1 ? vs.positiveVotes++ : vs.negativeVotes++;

        projectsTresholds[id][project.currentTreshold].voteSession = vs;
        tresholdVoteFromAddress[msg.sender][id][project.currentTreshold] = 1;
        voterArrayForTreshold[id][project.currentTreshold].push(msg.sender);
    }

    /**
     * @notice Function that allows a project owner to withdraw his funds
     */
    function withdrawFunds(
        uint256 projectId
    )
        external
        virtual
        override
        whenNotPaused
        validProjectId(projectId)   
    {
        Project memory project = projects[projectId];
        if (project.owner != msg.sender){
            revert NotProjectOwner();
        }

        uint256 amountToWithdraw = project.availableToWithdraw;

        if (amountToWithdraw == 0) {
            revert NoFundsToWithdraw();
        }

        address exchangeTokenAddress = project.exchangeTokenAddress;

        project.availableToWithdraw = 0;
        project.amountWithdrawn += amountToWithdraw;

        projects[projectId] = project;

        if (
            !IERC20Upgradeable(exchangeTokenAddress).transfer(
                msg.sender,
                amountToWithdraw
            )
        ) {
            revert TransferFailed();
        }

        emit WithdrewFunds(msg.sender, projectId, exchangeTokenAddress, amountToWithdraw);
    }

    /**
     * @notice Function that adds a new supported token
     * @param tokenAddress Address of the ERC20 token
     */
    function addNewSupportedToken(
        address tokenAddress
    ) external payable virtual override onlyRole(UPDATER_ROLE) {
        supportedTokens[tokenAddress] = 1;
        emit NewSupportedTokenAdded(tokenAddress);
    }

    /**
     * @notice Function that sets the donation fee for a project
     * @param projectId ID of the project
     * @param newFee New fee to set
     */
    function setDonationFee(
        uint256 projectId,
        uint16 newFee
    )
        external
        payable
        virtual
        override
        onlyRole(UPDATER_ROLE)
        validProjectId(projectId)
    {
        if (newFee > 10000) {
            revert CantGoAbove10000();
        }
        projects[projectId].donationFee = newFee;
        emit DonationFeeUpdated(projectId, newFee);
    }

    /**
     * @notice Function that sets the project status
     * @param projectId ID of the project
     * @param newStatus New status to set
     */
    function updateProjectStatus(
        uint256 projectId,
        uint256 newStatus
    )
        external
        payable
        virtual
        override
        onlyRole(UPDATER_ROLE)
        validProjectId(projectId)
    {
        if (newStatus > 1) {
            revert InvalidUintAsBool();
        }

        projects[projectId].isActive = newStatus;
        emit ProjectStatusUpdated(projectId, newStatus);
    }

    function updateProjectVoteCooldown(
        uint256 projectId,
        uint256 newCooldown
    )
        external
        payable
        virtual
        override
        onlyRole(UPDATER_ROLE)
        validProjectId(projectId)
    {
        projects[projectId].voteCooldown = newCooldown;
        emit ProjectVoteCooldownUpdated(projectId, newCooldown);
    }

    function withdrawFundsToOtherProject(
        uint256 fromProjectID,
        uint256 toProjectID
    )
        external
        payable
        virtual
        override
        onlyRole(UPDATER_ROLE)
        validProjectId(fromProjectID)
        validProjectId(toProjectID)
    {
        if(fromProjectID == toProjectID){
            revert CantWithdrawToSameProject();
        }

        Project memory fromProject = projects[fromProjectID];
        Project memory toProject = projects[toProjectID];

        if(toProject.isActive == 0){
            revert ProjectNotActive();
        }

        uint256 availableFunds = fromProject.currentAmount - fromProject.amountWithdrawn;

        if (availableFunds == 0) {
            revert NoFundsToWithdraw();
        }

        if(fromProject.exchangeTokenAddress != toProject.exchangeTokenAddress){
            revert DifferentExchangeToken();
        }

        //If the project is still active we deactivate it
        //This function is only used in a case of emergency
        //so logically we should deactivate the project
        if(fromProject.isActive == 1)
        {
            fromProject.isActive = 0;
        }

        fromProject.currentAmount = fromProject.currentAmount - availableFunds;
        fromProject.availableToWithdraw = 0;
        toProject.currentAmount = toProject.currentAmount + availableFunds;

        projects[fromProjectID] = fromProject;
        projects[toProjectID] = toProject;
    }

    //The ID is always Valid but i still put the modifier just in case
    //The whenNotPaused is always Valid but i still put the modifier just in case
    function startTresholdVoting(
        uint256 id
    ) private whenNotPaused validProjectId(id) {
        Project memory project = projects[id];
        Treshold memory currentTreshold = projectsTresholds[id][
            project.currentTreshold
        ];

        if (project.currentVoteCooldown > block.timestamp) {
            revert VoteCooldownNotOver(); 
        }

        if (currentTreshold.voteSession.isVotingInSession == 1) {
            revert AlreadyInVotingSession();
        }

        if (project.isActive == 0) {
            revert ProjectNotActive();
        }

        if (project.currentAmount < currentTreshold.budget) {
            revert TresholdNotReached();
        }

        if (project.currentTreshold >= project.nbOfTresholds) {
            revert NoMoreTresholds();
        }

        projectsTresholds[id][project.currentTreshold]
            .voteSession
            .isVotingInSession = 1;
    }

    //The ID is always Valid but i still put the modifier just in case
    //The whenNotPaused is always Valid but i still put the modifier just in case
    function deliberateVote(uint256 id) private whenNotPaused validProjectId(id) {
        Project memory project = projects[id];
        Treshold memory currentTreshold = projectsTresholds[id][
            project.currentTreshold
        ];

        int256 positiveVotes = int256(
            currentTreshold.voteSession.positiveVotes
        );
        int256 negativeVotes = int256(
            currentTreshold.voteSession.negativeVotes
        );

        if (positiveVotes + negativeVotes == 0) {
            revert CantDeliberateWithoutVotes();
        }

        int256 finalAmount = positiveVotes - negativeVotes;
        int256 votesPercentage = int256(project.requiredVotePercentage);

        projectsTresholds[id][project.currentTreshold]
            .voteSession
            .isVotingInSession = 0;

        if (
            (finalAmount * 10000) / (positiveVotes + negativeVotes) >
            votesPercentage
        ) {
            project.availableToWithdraw += currentTreshold.budget++;
            project.currentTreshold++;

            //updating global variables
            projects[id] = project;

            if (project.currentTreshold < project.nbOfTresholds) {
                currentTreshold = projectsTresholds[id][
                    project.currentTreshold
                ];

                //check if we have enough funds to start next vote
                if (
                    project.currentAmount >= currentTreshold.budget &&
                    currentTreshold.voteSession.isVotingInSession == 0
                ) {
                    startTresholdVoting(id);
                }
            }
        } else {
            resetVoteSession(id);
        }
    }

    //cancel vote and stay on current treshold
    function resetVoteSession(uint256 id) private validProjectId(id) {
        Project memory project = projects[id];
        Treshold memory currentTreshold = projectsTresholds[id][
            project.currentTreshold
        ];

        currentTreshold.voteSession.positiveVotes = 0;
        currentTreshold.voteSession.negativeVotes = 0;
        currentTreshold.voteSession.isVotingInSession = 0;
        projectsTresholds[id][project.currentTreshold] = currentTreshold;

        address[] memory tempVoterArrayForTreshold = voterArrayForTreshold[id][
            project.currentTreshold
        ];
        uint256 lenght = voterArrayForTreshold[id][project.currentTreshold]
            .length;
        address voter;

        for (uint256 i; i < lenght; ) {
            voter = tempVoterArrayForTreshold[i];
            tresholdVoteFromAddress[voter][id][project.currentTreshold] = 0;
            unchecked {
                ++i;
            }
        }

        delete voterArrayForTreshold[id][project.currentTreshold];

        uint256 newCooldown = block.timestamp + project.voteCooldown;

        projects[id].currentVoteCooldown = newCooldown;

        emit VoteSessionReset(id, project.currentTreshold, newCooldown);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[46] private __gap;
}
