// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";


/**
 * @title Mock ERC-20 Permit
 * @author solace.fi
 * @notice Mock ERC-20 is a mock ERC-20 with the permit() function.
 */
contract MockERC20Permit is ERC20Permit {
    using SafeERC20 for IERC20;

    uint8 internal _decimals;

    /**
     * @notice Constructs the Mock Token contract.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param supply The amount of supply for the token.
     * @param decimals_ The amount of decimals in the token.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply,
        uint8 decimals_
    ) ERC20(name, symbol) ERC20Permit(name) {
        _mint(msg.sender, supply);
        _decimals = decimals_;
    }

    /**
     * @notice Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value `ERC20` uses, unless this function is
     * overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * `balanceOf()` and `transfer`.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Mints 1000 new tokens to msg.sender
     */
    function mint() external {
        _mint(msg.sender, 1000*(10**_decimals));
    }
    
    function mintToken(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
