// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

abstract contract ExtensionSelector {
    event Selector(bytes4 selector, bool status);
    error InvalidSelector(bytes4 selector);

    mapping(bytes4 => bool) private _selectors;

    modifier isValidSelector(bytes4 selector) {
        if (!_isValidSelector(selector)) {
            revert InvalidSelector(selector);
        }
        _;
    }

    function _addSelector(bytes4 selector) internal {
        _selectors[selector] = true;
    }

    function _removeSelector(bytes4 selector) internal {
        _selectors[selector] = false;
    }

    function _isValidSelector(bytes4 selector) internal view returns (bool) {
        return (_selectors[selector]);
    }
}
