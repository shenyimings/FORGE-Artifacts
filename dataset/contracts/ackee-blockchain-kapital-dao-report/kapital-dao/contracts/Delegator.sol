// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./interfaces/IVotingWeightSource.sol";

abstract contract Delegator is IVotingWeightSource {
    event AppointDelegate(address indexed owner, address newDelegate);
    event Undelegate(address indexed owner);

    mapping(address => address) public delegates;
    mapping(address => uint256) public delegatedBalances;
    mapping(address => uint256) public lastUndelegated;

    function _balances(address account) internal view virtual returns (uint256);

    function _updateDelegate(address owner, address delegate) internal {
        uint256 balance = _balances(owner);
        require(balance > 0, "Delegator: zero balance");
        address lastDelegate = delegates[owner];
        delegates[owner] = delegate;

        if (lastDelegate != address(0)) {
            delegatedBalances[lastDelegate] -= balance;
        }
        if (delegate != address(0)) {
            delegatedBalances[delegate] += balance;
        }
    }

    function _appointDelegate(
        address owner,
        address delegate,
        uint256 cooldown
    ) internal virtual {
        require(delegate != address(0), "Delegator: Zero address");
        require(
            delegates[owner] == address(0),
            "Delegator: Must undelegate first"
        );
        require(
            block.timestamp - lastUndelegated[owner] > cooldown,
            "Delegator: delegate cooldown"
        );

        _updateDelegate(owner, delegate);
        emit AppointDelegate(owner, delegate);
    }

    function _undelegate(address owner) internal virtual {
        require(
            delegates[owner] != address(0),
            "Delegator: Delegate already zero"
        );
        lastUndelegated[owner] = block.timestamp;
        _updateDelegate(owner, address(0));
        emit Undelegate(owner);
    }

    function _undelegateAlways(address owner) internal virtual {
        if (delegates[owner] != address(0)) {
            _undelegate(owner);
        } else {
            lastUndelegated[owner] = block.timestamp;
        }
    }

    function votingWeight(address voter) external view returns (uint256) {
        return delegatedBalances[voter];
    }
}
