// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./IDAOAdmin.sol";
import "./IDAO.sol";
import "./DAOStandart.sol";
import "../extension/ExtensionSelector.sol";
import "../extension/ExtensionWhiteList.sol";

contract DAOAdmin is
    DAOStandart,
    ExtensionWhiteList,
    ExtensionSelector,
    IDAOAdmin,
    IDAO
{
    bytes32 public constant DAO_ADMIN_ROLE = keccak256("DAO_ADMIN_ROLE");

    constructor(
        address voteToken,
        uint256 minimumQuorumPercent,
        uint256 debatingPeriodDuration,
        address[] memory whiteList,
        bytes4[] memory selectors
    ) DAOStandart(voteToken, minimumQuorumPercent, debatingPeriodDuration) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(DAO_ADMIN_ROLE, address(this));

        uint256 len = whiteList.length;
        for (uint256 i; i < len; i++) {
            _addAccountInWL(whiteList[i]);
        }
        len = selectors.length;
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
     * @dev add a users to the whitelist
     * @param accounts array with adresses
     */
    function addAdmins(address[] memory accounts)
        external
        onlyRole(DAO_ADMIN_ROLE)
    {
        uint256 len = accounts.length;
        for (uint256 i; i < len; i++) {
            _addAccountInWL(accounts[i]);
        }
        emit WhiteList(accounts, true);
    }

    /**
     * @dev removing a users from the whitelist
     * @param accounts array with adresses
     */
    function removeAdmins(address[] memory accounts)
        external
        onlyRole(DAO_ADMIN_ROLE)
    {
        uint256 len = accounts.length;
        for (uint256 i; i < len; i++) {
            _removeAccountInWL(accounts[i]);
        }
        emit WhiteList(accounts, false);
    }

    /**
     *@dev set the duration of the vote
     */
    function setPeriodDuration(uint256 debatingPeriodDuration)
        external
        onlyRole(DAO_ADMIN_ROLE)
    {
        _setPeriodDuration(debatingPeriodDuration);
    }

    /**
     * @dev set the minimum percentage of votes from the total number
     * of tokens to consider the vote successful
     */
    function setMinimumQuorumPercent(uint256 minimumQuorum)
        external
        onlyRole(DAO_ADMIN_ROLE)
    {
        _setMinimumQuorumPercent(minimumQuorum);
    }

    /**
     * @dev replenishment of the user's balance
     */
    function deposit(uint256 amount) external isWhiteListM(msg.sender) {
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
    ) external isValidSelector(bytes4(callData)) isWhiteListM(msg.sender) {
        _addProposal(recipient, callData, startTime);
    }

    /**
     * @dev adding a new poll
     * @param startTime voting start time
     */
    function addPoll(uint256 startTime) external isWhiteListM(msg.sender) {
        _addPoll(startTime);
    }

    /**
     * @dev voting for the proposal
     * @param proposalId id of voting
     * @param supportAgainst vote for (true) or against (false)
     */
    function vote(uint256 proposalId, bool supportAgainst)
        external
        isWhiteListM(msg.sender)
    {
        _vote(proposalId, supportAgainst);
    }

    /**
     * @dev end the vote
     * @param proposalId id of voting
     */
    function finishVote(uint256 proposalId) external {
        if (_proposals[proposalId].signature.length == 0) {
            _finishPoll(proposalId);
        } else {
            _finishVote(proposalId);
        }
    }

    function isValidSignature(bytes4 selector) external view returns (bool) {
        return _isValidSelector(selector);
    }

    function isWhiteList(address account) external view returns (bool) {
        return _isWhiteList(account);
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
            interfaceId == type(IDAOAdmin).interfaceId ||
            interfaceId == type(IDAO).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
