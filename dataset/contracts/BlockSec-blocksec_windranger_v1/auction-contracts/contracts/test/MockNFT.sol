// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/presets/ERC721PresetMinterPauserAutoIdUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MockNFT is Initializable, ERC721PresetMinterPauserAutoIdUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {
        initialize("NFT", "NFT", "0x");
    }

    function mint(address to, uint256 id) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "Doesn't have minter role");
        _safeMint(to, id);
    }

    function addMinter(address minter) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Doesn't have minter role"
        );
        grantRole(MINTER_ROLE, minter);
    }
}
