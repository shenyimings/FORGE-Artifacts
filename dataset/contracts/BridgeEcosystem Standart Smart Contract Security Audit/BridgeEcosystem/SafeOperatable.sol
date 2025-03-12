// SPDX-License-Identifier: MIT

import "Context.sol";

pragma solidity ^0.8.5;

abstract contract SafeOperatable is Context {
    mapping(address => uint256) private _votes;
    mapping(address => Index) private _operators;
    address[] private _operatorsStorage;

    event OperatorChanged(
        address indexed previousOperator,
        address indexed newOperator
    );
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);

    struct Index {
        bool contains;
        uint256 index;
    }

    constructor(address otherOperator, address backupOperator, uint256 initialVotes) {
        _addOperator(_msgSender());
        _addOperator(otherOperator);
        _addOperator(backupOperator);

        _votes[_msgSender()] += initialVotes;
        _votes[otherOperator] += initialVotes;
    }

    modifier onlyOperator() {
        require(
            isOperator(_msgSender()),
            "SafeOperatable: caller is not operator"
        );

        uint256 requiredVotes = (_operatorsStorage.length / 2) + 1;
        uint256 collectedVotes;

        for (uint256 i = 0; i < _operatorsStorage.length; i++) {
            address operator = _operatorsStorage[i];
            if (_votes[operator] > 0 && operator != _msgSender()) {
                _votes[operator]--;
                collectedVotes++;
            }
        }

        if (_votes[_msgSender()] > 0) {
            _votes[_msgSender()]--;
        }
        collectedVotes++;

        require(
            collectedVotes >= requiredVotes,
            "SafeOperatable: Not enough votes"
        );
        _;
    }

    function giveVote(uint256 count) public {
        require(
            isOperator(_msgSender()),
            "SafeOperatable: caller is not operator"
        );

        _votes[_msgSender()] += count;
    }

    function operators() public view virtual returns (address[] memory) {
        return _operatorsStorage;
    }

    function changeOperator(address oldOperator, address newOperator)
        public
        virtual
        onlyOperator
    {
        addOperator(newOperator);
        removeOperator(oldOperator);
        emit OperatorChanged(oldOperator, newOperator);
    }

    function addOperator(address account) public onlyOperator {
        _addOperator(account);
    }

    function removeOperator(address account) public onlyOperator {
        require(
            isOperator(account),
            "SafeOperatable: Account is not operator"
        );
        require(
            _operatorsStorage.length > 3,
            "SafeOperatable: There must be at least 3 operators"
        );

        _operatorsStorage[_operators[account].index] = _operatorsStorage[
            _operatorsStorage.length - 1
        ];
        _operatorsStorage.pop();
        _operators[account].contains = false;
        _votes[account] = 0;
        emit OperatorRemoved(account);
    }

    function isOperator(address account) public view returns (bool) {
        return _operators[account].contains;
    }

    function _addOperator(address account) private {
        require(
            !isOperator(account),
            "SafeOperatable: Account is operator"
        );

        _operatorsStorage.push(account);
        _operators[account].contains = true;
        _operators[account].index = _operatorsStorage.length - 1;
        emit OperatorAdded(account);
    }
}
