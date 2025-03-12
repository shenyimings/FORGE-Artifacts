// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "./TokenUpgrader.sol";
pragma solidity ^0.6.6;

contract SpaceChain is ERC20Burnable {
    mapping(address => TokenUpgrader) public tokenUpgrader;

    constructor() public ERC20("SpaceChainV2", "SPC") {}

    function migrateV1tokens() public {
        require(
            address(tokenUpgrader[_msgSender()]) != address(0x0),
            "Upgrader contract not created"
        );
        TokenUpgrader upgrader = tokenUpgrader[_msgSender()];
        IERC20 tokenv1 = IERC20(0x8069080a922834460C3A092FB2c1510224dc066b);
        uint256 amount = tokenv1.balanceOf(address(upgrader));
        upgrader.burn(amount);
        _mint(_msgSender(), amount);
    }

    function createUpgrader() public {
        require(
            address(tokenUpgrader[_msgSender()]) == address(0x0),
            "Already created upgrader contract"
        );
        tokenUpgrader[_msgSender()] = new TokenUpgrader(_msgSender());
    }
}
