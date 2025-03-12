// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetFixedSupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MockWETH is Initializable, ERC20PresetFixedSupplyUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {
        initialize("WETH", "WETH", 1e27, _msgSender());
    }

    function deposit() external payable {
        require(msg.value > 0, "MockWETH: zero value");
        _mint(_msgSender(), msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(_msgSender(), amount);
        (bool succeed, ) = _msgSender().call{value: amount}("");
        require(succeed, "Failed to withdraw Ether");
    }
}
