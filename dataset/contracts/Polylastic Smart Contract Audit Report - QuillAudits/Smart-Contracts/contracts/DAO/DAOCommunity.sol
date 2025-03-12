// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./IDAOCommunity.sol";
import "./IDAO.sol";
import "./DAOStandart.sol";
import "../extension/ExtensionSelector.sol";

contract DAOCommunity is DAOStandart, ExtensionSelector, IDAO, IDAOCommunity {
    bytes32 public constant DAO_COMMUNITY_ROLE =
        keccak256("DAO_COMMUNITY_ROLE");
    bytes32 public constant DAO_ADMIN_ROLE = keccak256("DAO_ADMIN_ROLE");

    constructor(
        address voteToken,
        uint256 minimumQuorumPercent,
        uint256 debatingPeriodDuration,
        bytes4[] memory selectors,
        address DAOAdmin
    ) DAOStandart(voteToken, minimumQuorumPercent, debatingPeriodDuration) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(DAO_ADMIN_ROLE, DAOAdmin);
        _setupRole(DAO_COMMUNITY_ROLE, address(this));

        uint256 len = selectors.length;
        for (uint256 i; i < len; i++) {
            _addSelector(selectors[i]);
        }
    }

    /**
     * @dev add a new selector.
     */
    function addSelector(bytes4 selector) external onlyRole(DAO_ADMIN_ROLE) {
        _addSelector(selector);
        emit Selector(selector, true);
    }

    /**
     * @dev remove a selector.
     */
    function removeSelector(bytes4 selector) external onlyRole(DAO_ADMIN_ROLE) {
        _removeSelector(selector);
        emit Selector(selector, false);
    }

    /**
     * @dev set the duration of the vote
     */
    function changePeriodDuration(uint256 debatingPeriodDuration)
        external
        onlyRole(DAO_COMMUNITY_ROLE)
    {
        require(
            debatingPeriodDuration <= 30 days &&
                debatingPeriodDuration >= 7 days,
            "Invalid debatingPeriodDuration"
        );
        _setPeriodDuration(debatingPeriodDuration);
    }

    /**
     * @dev set the minimum percentage of votes from the total number
     * of tokens to consider the vote successful
     */
    function changeMinimumQuorumPercent(uint256 minimumQuorum)
        external
        onlyRole(DAO_ADMIN_ROLE)
    {
        _setMinimumQuorumPercent(minimumQuorum);
    }

    /**
     * @dev replenishment of the user's balance
     */
    function deposit(uint256 amount) external {
        _deposit(amount);
    }

    /**
     * @dev withdrawal of the user's balance
     */
    function withdraw() external {
        _withdraw();
    }

    /**
     * @dev adding a new proposal
     * @param recipient the address of the contract on which the signature will be called
     * @param callData signature function
     * @param startTime voting start time
     */
    function addProposal(
        address recipient,
        bytes calldata callData,
        uint256 startTime
    ) external isValidSelector(bytes4(callData)) {
        _addProposal(recipient, callData, startTime);
    }

    /**
     * @dev voting for the proposal
     * @param proposalId id of voting
     * @param supportAgainst vote for (true) or against (false)
     */
    function vote(uint256 proposalId, bool supportAgainst) external {
        _vote(proposalId, supportAgainst);
    }

    /**
     * @dev end the vote
     * @param proposalId id of voting
     */
    function finishVote(uint256 proposalId) external {
        _finishVote(proposalId);
    }

    function isValidSignature(bytes4 selector) external view returns (bool) {
        return _isValidSelector(selector);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IDAOCommunity).interfaceId ||
            interfaceId == type(IDAO).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
