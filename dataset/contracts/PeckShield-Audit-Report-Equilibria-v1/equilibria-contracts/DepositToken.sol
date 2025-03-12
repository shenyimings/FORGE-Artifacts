// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./Interfaces/IDepositToken.sol";

contract DepositToken is IDepositToken, ERC20Upgradeable, OwnableUpgradeable {
    address public operator;

    function initialize(
        address _operator,
        address _lptoken
    ) public initializer {
        require(_operator != address(0), "invalid _operator!");

        __Ownable_init();

        __ERC20_init_unchained(
            string(
                abi.encodePacked(ERC20(_lptoken).name(), " Equilibria Deposit")
            ),
            string(abi.encodePacked("eqb", ERC20(_lptoken).symbol()))
        );

        operator = _operator;
    }

    function mint(address _to, uint256 _amount) external override {
        require(msg.sender == operator, "!authorized");

        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external override {
        require(msg.sender == operator, "!authorized");

        _burn(_from, _amount);
    }
}
