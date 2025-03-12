// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Whitelist} from "./Whitelist.sol";
import {IWhitelistChecker} from "./interfaces/IWhitelistChecker.sol";

/// @title WhitelistChecker
/// @dev A contract which keep track of whether it is using a list of whitelist contracts.
abstract contract WhitelistChecker is IWhitelistChecker {
    event PendingGovernanceUpdated(address pendingGovernance);

    event GovernanceUpdated(address governance);

    event WhitelistAdded(Whitelist _whitelist);

    event WhitelistRemoved(Whitelist _whitelist);

    /// @dev The address of the account which currently has administrative capabilities over this contract.
    address public governance;

    address public pendingGovernance;

    Whitelist[] public whitelist;

    mapping(Whitelist => uint256) whitelistIndex;

    /// @dev A modifier which reverts when the caller is not the governance.
    modifier onlyGovernance() {
        require(msg.sender == governance, "StakingPools: only governance");
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
            "StakingPools: pending governance address cannot be 0x0"
        );
        pendingGovernance = _pendingGovernance;

        emit PendingGovernanceUpdated(_pendingGovernance);
    }

    /// @dev Sets the pending governance.
    ///
    /// This function can only called by the pending governance.
    function acceptGovernance() external {
        require(
            msg.sender == pendingGovernance,
            "StakingPools: only pending governance"
        );

        governance = pendingGovernance;

        emit GovernanceUpdated(pendingGovernance);
    }

    /// @dev A modifier which reverts when the msg.sender has no NFT in any whitelist
    modifier inWhitelist() virtual {
        require(whitelist.length > 0, "StakingPools: whitelist not set");
        bool _inList;
        for (uint256 i = 0; i < whitelist.length; i++) {
            if (whitelist[i].includeOwner(msg.sender)) {
                _inList = true;
                break;
            }
        }
        require(_inList, "StakingPools: owner not in any white lists");
        _;
    }

    /// @dev Adds a whitelist to watch list.
    ///
    /// This function can only called by the current governance.
    ///
    /// @param _whitelist The address of the whitelist contract
    function addWhitelist(Whitelist _whitelist)
        external
        virtual
        override
        onlyGovernance
    {
        require(
            address(_whitelist) != address(0),
            "StakingPools: whitelist cannot be 0x0"
        );
        require(
            whitelistIndex[_whitelist] == 0,
            "StakingPools: the whitelist already added"
        );
        whitelist.push(_whitelist);
        whitelistIndex[_whitelist] = whitelist.length;

        emit WhitelistAdded(_whitelist);
    }

    /// @dev Adds a whitelist to watch list.
    ///
    /// This function can only called by the current governance.
    ///
    /// @param _whitelist The address of the whitelist contract
    function removeWhitelist(Whitelist _whitelist)
        external
        virtual
        override
        onlyGovernance
    {
        require(
            whitelistIndex[_whitelist] != 0,
            "StakingPools: the whitelist doesn't exist"
        );
        _whitelist.removeChecker(IWhitelistChecker(address(this)));
        uint256 _whitelistPtr = whitelistIndex[_whitelist];
        if (_whitelistPtr != whitelist.length) {
            whitelist[_whitelistPtr - 1] = whitelist[whitelist.length - 1];
            whitelistIndex[whitelist[whitelist.length - 1]] = _whitelistPtr;
        }
        whitelistIndex[_whitelist] = 0;
        whitelist.pop();

        emit WhitelistRemoved(_whitelist);
    }

    /// @dev Gets all NFT tokens the owner has.
    ///
    /// @param _owner The owner address.
    ///
    /// @return A list where n-th leading number indicates the following number of numbers are tokenIds of n-th watched whitelist
    function getAllTokens(address _owner)
        external
        view
        virtual
        override
        returns (uint256[] memory)
    {
        uint256 _balance = getAllBalance(_owner);
        uint256[] memory _ret = new uint256[](_balance + whitelist.length);
        uint256 _ptr = 0;
        for (uint256 i = 0; i < whitelist.length; i++) {
            _ret[_ptr] = whitelist[i].balanceOf(_owner);
            _ptr++;
            uint256[] memory _tmp = whitelist[i].listTokens(_owner);
            for (uint256 j = 0; j < _tmp.length; j++) {
                _ret[_ptr] = _tmp[j];
                _ptr++;
            }
        }
        return _ret;
    }

    /// @dev Gets the number of NFTs the owner has in all watched whitelists.
    ///
    /// @param _owner The owner address.
    ///
    /// @return The number of NFTs the owner has.
    function getAllBalance(address _owner) internal view returns (uint256) {
        uint256 _balance = 0;
        for (uint256 i = 0; i < whitelist.length; i++) {
            _balance += whitelist[i].balanceOf(_owner);
        }
        return _balance;
    }
}
