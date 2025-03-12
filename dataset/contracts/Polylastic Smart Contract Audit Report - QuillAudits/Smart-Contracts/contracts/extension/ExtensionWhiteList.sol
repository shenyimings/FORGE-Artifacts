// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

abstract contract ExtensionWhiteList {
    event WhiteList(address[] account, bool status);
    error NoInWhiteList();

    mapping(address => bool) private _whiteList;

    modifier isWhiteListM(address account) {
        if (!_isWhiteList(msg.sender)) {
            revert NoInWhiteList();
        }
        _;
    }

    function _addAccountInWL(address account) internal {
        _whiteList[account] = true;
    }

    function _removeAccountInWL(address account) internal {
        _whiteList[account] = false;
    }

    function _isWhiteList(address account) internal view returns (bool) {
        return (_whiteList[account]);
    }
}
