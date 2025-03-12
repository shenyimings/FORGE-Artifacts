// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./abstracts/ERC20ETHlessTransfer.sol";
import "./abstracts/ERC20Reservable.sol";
import "./abstracts/ERC20Wrapper.sol";

/**
 * @dev Extension of {Gluwacoin} that allows a certain ERC20 token holders to wrap the token to mint this token.
 * Holder of this token can retrieve the wrapped token by burning this token.
 */
contract ERC20WrapperGluwacoin is
    Initializable,
    ContextUpgradeable,
    ERC20Wrapper,
    ERC20ETHless,
    ERC20Reservable
{
    // note that `decimals` must match that of `token` or less
    function initialize(
        string memory name,
        string memory symbol,
        IERC20 token
    ) public virtual {
        __ERC20WrapperGluwacoin_init(name, symbol, token);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function __ERC20WrapperGluwacoin_init(
        string memory name,
        string memory symbol,
        IERC20 token
    ) internal initializer {
        __Context_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ERC20ETHless_init_unchained();
        __ERC20Reservable_init_unchained();
        __AccessControlEnumerable_init_unchained();
        __ERC20Wrapper_init_unchained(token);
        __ERC20WrapperGluwacoin_init_unchained();
    }

    function __ERC20WrapperGluwacoin_init_unchained() internal initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20Wrapper, ERC20Reservable) {
        ERC20Wrapper._beforeTokenTransfer(from, to, amount);
        ERC20Reservable._beforeTokenTransfer(from, to, amount);
    }

    uint256[50] private __gap;
}
