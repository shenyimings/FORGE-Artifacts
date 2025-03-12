//SPDX-License-Identifier: MIT
pragma solidity =0.8.18;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/**
 * @title MediaLicensingToken
 * @author gotbit
 */
contract MediaLicensingToken is ERC20, Ownable {
    mapping(address => bool) public restrictedUsers;

    event RestrictUser(address indexed user);
    event UnrestrictUser(address indexed user);

    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply_
    ) ERC20(name, symbol) {
        _mint(msg.sender, totalSupply_);
    }

    /// @notice adds user to restricted list
    /// @dev the user must be not restricted
    function restrictUser(address user) external onlyOwner {
        require(!restrictedUsers[user], 'Already restricted');
        restrictedUsers[user] = true;
        emit RestrictUser(user);
    }

    /// @notice adds user to restricted list
    /// @dev the user must restricted
    function unrestrictUser(address user) external onlyOwner {
        require(restrictedUsers[user], 'Already unrestricted');
        restrictedUsers[user] = false;
        emit UnrestrictUser(user);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 // amount
    ) internal view override {
        require(
            !restrictedUsers[from] && !restrictedUsers[to],
            'Transfer is not allowed'
        );
    }
}
