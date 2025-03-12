// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import {IWhitelistChecker} from "./interfaces/IWhitelistChecker.sol";

contract Whitelist {
    address public governance;

    address public pendingGovernance;

    IWhitelistChecker[] public checkers;

    /// @dev A mapping of index in checkers by the whitelist checker contract address
    mapping(IWhitelistChecker => uint256) checkerIndex;

    /// @dev A mapping of lists of tokenIds by the owner
    mapping(address => uint256[]) public tokenListOf;

    /// @dev A mapping of token index of of tokenListOf by tokenIds
    mapping(uint256 => uint256) public tokenIndex;

    /// @dev A mapping of owners by tokenIds
    mapping(uint256 => address) public ownerOf; // map from tokenId to token owner

    event CheckerAdded(IWhitelistChecker checker);

    event CheckerRemoved(IWhitelistChecker checker);

    event TokenAdded(address owner, uint256 tokenId);

    event TokenRemoved(address owner, uint256 tokenId);

    event PendingGovernanceUpdated(address pendingGovernance);

    event GovernanceUpdated(address governance);

    constructor(address _governance) {
        require(
            _governance != address(0),
            "Whitelist: governance address cannot be 0x0"
        );

        governance = _governance;
    }

    /// @dev A modifier which reverts when the caller is not the governance.
    modifier onlyGovernance() {
        require(msg.sender == governance, "Whitelist: only governance");
        _;
    }

    /// @dev Sets the governance.
    ///
    /// This function can only called by the current governance.
    ///
    /// @param _pendingGovernance the new pending governance.
    function setPendingGovernance(address _pendingGovernance)
        external
        onlyGovernance
    {
        require(
            _pendingGovernance != address(0),
            "Whitelist: pending governance address cannot be 0x0"
        );
        pendingGovernance = _pendingGovernance;

        emit PendingGovernanceUpdated(_pendingGovernance);
    }

    function acceptGovernance() external {
        require(
            msg.sender == pendingGovernance,
            "Whitelist: only pending governance"
        );

        governance = pendingGovernance;

        emit GovernanceUpdated(pendingGovernance);
    }

    /// @dev Adds a whitelistChecker to the whitelist
    ///
    /// This function can only called by the current governance.
    ///
    /// @param _checker The whitelistChecker.sol contract to be added.
    function addChecker(IWhitelistChecker _checker) external onlyGovernance {
        require(
            address(_checker) != address(0),
            "Whitelist: checker cannot be 0x0"
        );
        require(
            checkerIndex[_checker] == 0,
            "Whitelist: checker already added"
        );
        checkers.push(_checker);
        checkerIndex[_checker] = checkers.length;

        emit CheckerAdded(_checker);
    }

    /// @dev Removes a whitelistChecker to the whitelist.
    ///
    /// This function can only called by the current governance or the Checker themselves.
    ///
    /// @param _checker The whitelistChecker.sol contract to be removed.
    function removeChecker(IWhitelistChecker _checker) external {
        require(
            msg.sender == address(_checker) || msg.sender == governance,
            "Whitelist: only checker or governance"
        );
        require(
            checkerIndex[_checker] != 0,
            "Whitelist: the checker doesn't exist"
        );
        uint256 _checkerPtr = checkerIndex[_checker];
        if (_checkerPtr != checkers.length) {
            checkers[_checkerPtr - 1] = checkers[checkers.length - 1];
            checkerIndex[checkers[checkers.length - 1]] = _checkerPtr;
        }
        checkerIndex[_checker] = 0;
        checkers.pop();

        emit CheckerRemoved(_checker);
    }

    /// @dev Adds an NFT to the whitelist.
    ///
    /// This function can only called by the current governance.
    ///
    /// @param _owner The owner of the NFT.
    /// @param _tokenId The tokenId of the NFT.
    function addNFT(address _owner, uint256 _tokenId) external onlyGovernance {
        require(
            ownerOf[_tokenId] == address(0),
            "Whitelist: token is already owned"
        );
        ownerOf[_tokenId] = _owner;
        tokenListOf[_owner].push(_tokenId);
        tokenIndex[_tokenId] = tokenListOf[_owner].length;

        emit TokenAdded(_owner, _tokenId);
    }

    /// @dev Removes an NFT from the whitelist.
    ///
    /// This function can only called by the token owner
    ///
    /// @param _tokenId The tokenId of the NFT.
    function removeNFT(uint256 _tokenId) external {
        require(
            ownerOf[_tokenId] == msg.sender,
            "Whitelist: msg.sender is not the token owner"
        );
        Whitelist _whitelist = Whitelist(address(this));
        for (uint256 i = 0; i < checkers.length; i++) {
            require(
                checkers[i].acceptsRemoval(_whitelist, msg.sender, _tokenId),
                "Whitelist: cannot remove when checker is using"
            );
        }
        uint256[] storage _tokenList = tokenListOf[msg.sender];
        uint256 _tokenPtr = tokenIndex[_tokenId];
        if (_tokenPtr != _tokenList.length) {
            _tokenList[_tokenPtr - 1] = _tokenList[_tokenList.length - 1];
            tokenIndex[_tokenList[_tokenList.length - 1]] = _tokenPtr;
        }
        ownerOf[_tokenId] = address(0);
        _tokenList.pop();

        emit TokenRemoved(msg.sender, _tokenId);
    }

    /// @dev Returns true if the owner has any NFT in this whitelist.
    ///
    /// @param _owner The owner.
    ///
    /// @return true if the owner has any NFT in this whitelist, false otherwise.
    function includeOwner(address _owner) external view returns (bool) {
        return tokenListOf[_owner].length > 0;
    }

    /// @dev Gets number of NFTs the owner has.
    ///
    /// @param _owner The owner.
    ///
    /// @return Number of NFT owned by the owner.
    function balanceOf(address _owner) external view returns (uint256) {
        return tokenListOf[_owner].length;
    }

    /// @dev Gets all NFTs the owner has.
    ///
    /// @param _owner The owner.
    ///
    /// @return List of NFTs the owner has
    function listTokens(address _owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory _ret = tokenListOf[_owner];
        return _ret;
    }
}
