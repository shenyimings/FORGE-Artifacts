// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./constants/addresses.sol";
import "./constants/roles.sol";
import "./interfaces/IExchange.sol";
import "./AddressAccessor.sol";

contract IncentiveVault is AddressAccessor, Pausable {
    uint256 constant WITHDRAWAL_INTERVAL = 1 days;

    uint16 public apr; // APY * 100 (e.g. 100 = 1%)

    uint256 private _lastWithdrawal;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function recoverLostTokens(address token)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (!paused()) {
            require(token != addressProvider.getAddress(UNDERLYING_ADDRESS));
        }
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(msg.sender, balance);
    }

    function setAPR(uint16 value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        apr = value;
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function withdraw(uint256 amount) external onlyRole(CONTROLLER_ROLE) {
        require(amount > 0);
        address underlying = addressProvider.getAddress(UNDERLYING_ADDRESS);
        require(availableAmount() >= amount, "amount exceeds availability");
        _lastWithdrawal = block.timestamp / WITHDRAWAL_INTERVAL;
        IERC20(underlying).transfer(msg.sender, amount);
    }

    function availableAmount() public view returns (uint256) {
        (address underlying, address exchange, address USDR) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(
                    UNDERLYING_ADDRESS,
                    USDR_EXCHANGE_ADDRESS,
                    USDR_ADDRESS
                )
            ),
            (address, address, address)
        );
        uint256 balance = IERC20(underlying).balanceOf(address(this));
        uint256 amount = (IExchange(exchange).scaleToUnderlying(
            IERC20(USDR).totalSupply()
        ) * apr) / 3_650_000;
        if (_lastWithdrawal != 0) {
            uint256 today = block.timestamp / WITHDRAWAL_INTERVAL;
            amount = amount * (today - _lastWithdrawal);
        }
        return amount > balance ? balance : amount;
    }
}
