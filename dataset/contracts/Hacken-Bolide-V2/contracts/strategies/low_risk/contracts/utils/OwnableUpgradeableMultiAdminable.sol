// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract OwnableUpgradeableMultiAdminable is OwnableUpgradeable {
    address[] private admins;

    event AddAdmin(address admin);
    event RemoveAdmin(address admin);

    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "OA1");
        _;
    }

    modifier onlyOwnerAndAdmin() {
        require(msg.sender == owner() || isAdmin(msg.sender), "OA2");
        _;
    }

    /**
     * @notice Add admin
     * @param user Addres of new admin
     */
    function addAdmin(address user) external onlyOwner {
        require(!isAdmin(user), "OA3");

        admins.push(user);

        emit AddAdmin(user);
    }

    /**
     * @notice Remove admin
     * @param user Addres of admin to be removed
     */
    function removeAdmin(address user) external onlyOwner {
        for (uint256 i = admins.length - 1; i >= 0; ) {
            if (admins[i] == user) {
                admins[i] = admins[admins.length - 1];
                admins.pop();

                emit RemoveAdmin(user);

                break;
            }

            unchecked {
                i--;
            }
        }
    }

    function getAdmins() external returns (address[] memory) {
        return admins;
    }

    function isAdmin(address user) private returns (bool) {
        for (uint256 i; i < admins.length; i++) {
            if (admins[i] == user) {
                return true;
            }
        }

        return false;
    }
}
