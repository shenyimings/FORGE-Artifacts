// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./libraries/openzeppelin/ERC20UpgradeSafe.sol";

/**
 * ERC20 token representing a long or short option position. It is intended to be
 * used by `OptionMarket`, which mints/burns these tokens when users buy/sell options
 *
 * Note that `decimals` should match the decimals of the `baseToken` in `OptionMarket`
 */
contract OptionToken is ERC20UpgradeSafe {
    using Address for address;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public market;

    function initialize(
        address _market,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) public initializer {
        __ERC20_init(name, symbol);
        _setupDecimals(decimals);
        market = _market;
    }

    function mint(address account, uint256 amount) external {
        require(msg.sender == market, "!market");
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        require(msg.sender == market, "!market");
        _burn(account, amount);
    }
}
