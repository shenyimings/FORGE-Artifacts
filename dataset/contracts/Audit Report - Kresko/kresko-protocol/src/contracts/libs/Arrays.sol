// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;

import {Error} from "./Errors.sol";

/**
 * @title Library for operations on arrays
 */
library Arrays {
    /**
     * @dev Removes an element by copying the last element to the element to remove's place and removing
     * the last element.
     * @param _addresses The address array containing the item to be removed.
     * @param _elementToRemove The element to be removed.
     * @param _elementIndex The index of the element to be removed.
     */
    function removeAddress(address[] storage _addresses, address _elementToRemove, uint256 _elementIndex) internal {
        require(_addresses[_elementIndex] == _elementToRemove, Error.ARRAY_OUT_OF_BOUNDS);

        uint256 lastIndex = _addresses.length - 1;
        // If the index to remove is not the last one, overwrite the element at the index
        // with the last element.
        if (_elementIndex != lastIndex) {
            _addresses[_elementIndex] = _addresses[lastIndex];
        }
        // Remove the last element.
        _addresses.pop();
    }
}
