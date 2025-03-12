// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../constants/addresses.sol";
import "../constants/roles.sol";
import "../interfaces/ITreasury.sol";
import "../AddressAccessor.sol";

contract pDAI is AddressAccessor, ERC20Permit, Pausable {
    using SafeERC20 for IERC20;

    constructor() ERC20("pDAI", "pDAI") ERC20Permit("pDAI") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address account, uint256 amount)
        external
        onlyRole(MINTER_ROLE)
        whenNotPaused
    {
        _mint(account, amount);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function redeem(uint256 amount) external {
        redeemFor(msg.sender, amount);
    }

    function redeemFor(address account, uint256 amount) public whenNotPaused {
        _burn(account, amount);
        (address treasury, address underlying) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(TREASURY_ADDRESS, UNDERLYING_ADDRESS)
            ),
            (address, address)
        );
        {
            uint8 toDecimals = IERC20Metadata(underlying).decimals();
            assembly {
                switch lt(18, toDecimals)
                case 0 {
                    if gt(18, toDecimals) {
                        amount := div(amount, exp(10, sub(18, toDecimals)))
                    }
                }
                default {
                    amount := mul(amount, exp(10, sub(toDecimals, 18)))
                }
            }
        }
        ITreasury(treasury).withdraw(underlying, amount, account);
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
