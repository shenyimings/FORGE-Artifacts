// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.1;

library AddressList {
    /**
     * @dev Inserts token address in addressList except for zero address.
     */
    function insert(address[] storage addressList, address token) internal {
        if (token == address(0)) {
            return;
        }

        for (uint256 i = 0; i < addressList.length; i++) {
            if (addressList[i] == address(0)) {
                addressList[i] = token;
                return;
            }
        }

        addressList.push(token);
    }

    /**
     * @dev Removes token address from addressList except for zero address.
     */
    function remove(address[] storage addressList, address token) internal returns (bool success) {
        if (token == address(0)) {
            return true;
        }

        for (uint256 i = 0; i < addressList.length; i++) {
            if (addressList[i] == token) {
                delete addressList[i];
                return true;
            }
        }
    }

    /**
     * @dev Returns the addresses included in addressList except for zero address.
     */
    function get(address[] storage addressList)
        internal
        view
        returns (address[] memory denseAddressList)
    {
        uint256 numOfElements = 0;
        for (uint256 i = 0; i < addressList.length; i++) {
            if (addressList[i] != address(0)) {
                numOfElements++;
            }
        }

        denseAddressList = new address[](numOfElements);
        uint256 j = 0;
        for (uint256 i = 0; i < addressList.length; i++) {
            if (addressList[i] != address(0)) {
                denseAddressList[j] = addressList[i];
                j++;
            }
        }
    }
}
