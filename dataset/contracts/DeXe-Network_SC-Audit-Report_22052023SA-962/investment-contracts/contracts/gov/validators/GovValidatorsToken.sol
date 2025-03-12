// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";

import "../../interfaces/gov/validators/IGovValidatorsToken.sol";

contract GovValidatorsToken is IGovValidatorsToken, ERC20Snapshot {
    address public immutable validatorsContract;

    modifier onlyValidatorsContract() {
        _onlyValidatorsContract();
        _;
    }

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        validatorsContract = msg.sender;
    }

    function mint(address account, uint256 amount) external override onlyValidatorsContract {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external override onlyValidatorsContract {
        _burn(account, amount);
    }

    function snapshot() external override onlyValidatorsContract returns (uint256) {
        return _snapshot();
    }

    function _onlyValidatorsContract() internal view {
        require(
            validatorsContract == msg.sender,
            "ValidatorsToken: caller is not the validators contract"
        );
    }

    function _transfer(address, address, uint256) internal pure override {
        revert("ValidatorsToken: non-transferrable");
    }

    function _approve(address, address, uint256) internal pure override {
        revert("ValidatorsToken: non-approvable");
    }
}
